<?php

namespace App\Http\Controllers;

use App\Models\Package;
use App\Models\PaymentTransaction;
use App\Models\UserFcmToken;
use App\Models\WebhookEvent;
use App\Services\ResponseService;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Illuminate\Database\QueryException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use App\Models\UserPurchasedPackage;
use App\Services\NotificationService;
use App\Services\PaymentFulfillmentService;
use Carbon\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Throwable;
use JsonException;
use RuntimeException;

class WebhookController extends Controller {



    public function __construct(private readonly PaymentFulfillmentService $paymentFulfillmentService)
    {
    }

    public function stripe(Request $request): JsonResponse
    {
        return $this->handleWebhook($request, 'stripe');
    }

    public function razorpay(Request $request): JsonResponse
    {
        return $this->handleWebhook($request, 'razorpay');
    }

    public function paystack(Request $request): JsonResponse
    {
        return $this->handleWebhook($request, 'paystack');
    }

    public function paystackSuccessCallback(){
        ResponseService::successResponse("Payment done successfully.");
    }

    public function phonePe(Request $request): JsonResponse
    {

        return $this->handleWebhook($request, 'phonepe');
    }

    protected function handleWebhook(Request $request, string $provider): JsonResponse
    {
        $config = $this->resolveProviderConfig($provider);

        if (empty($config['secret'])) {
            return response()->json([
                'message' => 'Webhook provider misconfigured.',
            ], 500);
        }

        $payload = $request->getContent();

        if ($payload === '' || $payload === null) {
            return response()->json([
                'message' => 'Missing webhook payload.',
            ], 400);
        }

        $timestamp = $request->header($config['timestamp_header']);
        $signature = $request->header($config['signature_header']);

        if (empty($timestamp) || empty($signature)) {
            return response()->json([
                'message' => 'Webhook signature missing.',
            ], 401);
        }

        if (!$this->isTimestampValid($timestamp, $config['tolerance'])) {
            return response()->json([
                'message' => 'Webhook signature expired.',
            ], 408);
        }

        $expectedSignature = hash_hmac(
            $config['hash_algorithm'],
            $timestamp . '.' . $payload,
            $config['secret']
        );

        if (!hash_equals($expectedSignature, (string) $signature)) {
            return response()->json([
                'message' => 'Invalid webhook signature.',
            ], 401);
        }

        try {
            $data = json_decode($payload, true, 512, JSON_THROW_ON_ERROR);
        } catch (JsonException $exception) {
            Log::warning('WebhookController: Failed to decode payload', [
                'provider' => $provider,
                'error' => $exception->getMessage(),
            ]);

            return response()->json([
                'message' => 'Malformed webhook payload.',
            ], 422);
        }

        $eventId = (string) data_get($data, 'event_id');

        if ($eventId === '') {
            return response()->json([
                'message' => 'Webhook event id is required.',
            ], 422);
        }

        if (WebhookEvent::query()->where('provider', $provider)->where('event_id', $eventId)->exists()) {
            return response()->json([
                'message' => 'Event already processed.',
            ]);
        }

        $transactionId = data_get($data, 'payment_transaction_id');
        $userId = data_get($data, 'user_id');
        $payableType = (string) data_get($data, 'payable_type', Package::class);
        $payableId = data_get($data, 'payable_id');
        $options = data_get($data, 'options', []);
        $meta = data_get($data, 'meta', []);

        if (!is_array($options)) {
            $options = [];
        }

        if (!is_array($meta)) {
            $meta = [];
        }

        if (!is_numeric($transactionId) || !is_numeric($userId)) {
            return response()->json([
                'message' => 'Invalid webhook payload.',
            ], 422);
        }

        if (!empty($meta)) {
            $options['meta'] = array_merge($options['meta'] ?? [], $meta);
        }

        $options['payment_gateway'] = $options['payment_gateway'] ?? $provider;

        try {
            $result = DB::transaction(function () use (
                $provider,
                $eventId,
                $data,
                $transactionId,
                $payableType,
                $payableId,
                $userId,
                $options
            ) {
                $transaction = PaymentTransaction::findOrFail($transactionId);

                $response = $this->paymentFulfillmentService->fulfill(
                    $transaction,
                    $payableType,
                    $payableId,
                    (int) $userId,
                    $options
                );

                if (($response['error'] ?? false) === true) {
                    throw new RuntimeException($response['message'] ?? 'Unable to process webhook.');
                }

                WebhookEvent::create([
                    'provider' => $provider,
                    'event_id' => $eventId,
                    'payload' => $data,
                    'processed_at' => Carbon::now(),
                ]);

                return $response;
            });
        } catch (ModelNotFoundException) {
            return response()->json([
                'message' => 'Payment transaction not found.',
            ], 404);
        } catch (RuntimeException $exception) {
            Log::warning('WebhookController: Payment fulfillment failed', [
                'provider' => $provider,
                'event_id' => $eventId,
                'message' => $exception->getMessage(),
            ]);

            return response()->json([
                'message' => 'Payment fulfillment failed.',
            ], 409);
        } catch (QueryException $exception) {
            if ($exception->getCode() === '23000') {
                return response()->json([
                    'message' => 'Event already processed.',
                ]);
            }

            Log::error('WebhookController: QueryException', [
                'provider' => $provider,
                'event_id' => $eventId,
                'error' => $exception->getMessage(),
            ]);

            return response()->json([
                'message' => 'Internal server error.',
            ], 500);
        } catch (Throwable $throwable) {
            Log::error('WebhookController: Unexpected error', [
                'provider' => $provider,
                'event_id' => $eventId,
                'error' => $throwable->getMessage(),
            ]);

            return response()->json([
                'message' => 'Internal server error.',
            ], 500);
        }


        return response()->json([
            'message' => 'Webhook processed successfully.',
            'transaction_id' => data_get($result, 'transaction.id'),
        ]);
    }

    protected function resolveProviderConfig(string $provider): array
    {
        $defaults = [
            'signature_header' => 'X-Webhook-Signature',
            'timestamp_header' => 'X-Webhook-Timestamp',
            'hash_algorithm' => 'sha256',
            'tolerance' => 300,
            'secret' => null,
        ];

        $globalDefaults = config('webhooks.default', []);
        $providerConfig = config("webhooks.providers.$provider", []);

        return array_replace_recursive($defaults, $globalDefaults, $providerConfig);
    }

    protected function isTimestampValid(mixed $timestamp, int $tolerance): bool
    {
        if (!is_numeric($timestamp)) {
            return false;
        }

        $timestamp = (int) $timestamp;

        return abs(now()->timestamp - $timestamp) <= $tolerance;
        
    }

    public function phonePeSuccessCallback(){
        ResponseService::successResponse("Payment done successfully.");
    }

    /**
     * Success Business Login
     * @param $payment_transaction_id
     * @param $user_id
     * @param $package_id
     * @return array
     */
    private function assignPackage($payment_transaction_id, $user_id, $package_id) {
        try {
            $paymentTransactionData = PaymentTransaction::find($payment_transaction_id);
            if (!$paymentTransactionData) {
                Log::error('Payment Transaction id not found');
                return [
                    'error'   => true,
                    'message' => 'Payment Transaction id not found'
                ];
            }
            if (strtolower($paymentTransactionData->payment_status) === 'succeed') {
                Log::info('Transaction already succeed');
                return [
                    'error'   => false,
                    'message' => 'Transaction already succeed'
                ];
            }

            $result = $this->paymentFulfillmentService->fulfill(
                $paymentTransactionData,
                Package::class,
                $package_id,
                $user_id,
                [
                    'notification' => [
                        'title' => 'Package Purchased',
                        'body'  => 'Amount :- ' . $paymentTransactionData->amount,
                        'type'  => 'payment',
                        'data'  => [
                            'transaction_id' => $paymentTransactionData->id,
                        ],
                    ],
                ]
            );

            if ($result['error']) {
                Log::error('Webhook assignPackage fulfillment error', ['message' => $result['message']]);
            }
            return $result;

        } catch (Throwable $th) { 
            Log::error($th->getMessage() . "WebhookController -> assignPackage");
            return [
                'error'   => true,
                'message' => 'Error Occurred'
            ];
        }
    }

    /**
     * Failed Business Logic
     * @param $payment_transaction_id
     * @param $user_id
     * @return array
     */
    private function failedTransaction($payment_transaction_id, $user_id) {
        try {
            $paymentTransactionData = PaymentTransaction::find($payment_transaction_id);
            if (!$paymentTransactionData) {
                return [
                    'error'   => true,
                    'message' => 'Payment Transaction id not found'
                ];
            }

            $paymentTransactionData->update(['payment_status' => "failed"]);

            $body = 'Amount :- ' . $paymentTransactionData->amount;
            $userTokens = UserFcmToken::where('user_id', $user_id)->pluck('fcm_token')->toArray();
            $notificationResponse = NotificationService::sendFcmNotification($userTokens, 'Package Payment Failed', $body, 'payment');

            if (is_array($notificationResponse) && ($notificationResponse['error'] ?? false)) {
                Log::error('WebhookController: Failed to send payment failure notification', $notificationResponse);
            }


            return [
                'error'   => false,
                'message' => 'Transaction Verified Successfully'
            ];
        } catch (Throwable $th) {
            DB::rollBack();
            Log::error($th->getMessage() . "WebhookController -> failedTransaction");
            return [
                'error'   => true,
                'message' => $th->getMessage(),
                'code'    => $th->getCode(),
            
            ];
        }
    }
}

