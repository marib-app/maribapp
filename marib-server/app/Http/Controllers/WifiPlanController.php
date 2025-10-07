<?php

namespace App\Http\Controllers;
use App\Models\PaymentConfiguration;

use App\Models\PaymentTransaction;
use App\Models\WifiCode;
use App\Models\WifiNetwork;
use App\Models\WifiPlan;
use App\Services\PaymentFulfillmentService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use App\Services\WalletService;
use Illuminate\Support\Facades\Log;
use Throwable;


class WifiPlanController extends Controller
{
    public function index(Request $request, WifiNetwork $network): JsonResponse
    {
        $this->assertOwner($request->user()?->getKey(), $network);

        $plans = $network->plans()
            ->withCodeMetrics()
            ->withRevenueAggregates()
            ->orderByDesc('id')
            ->get();

        return response()->json(['data' => $plans]);
    }

    public function store(Request $request, WifiNetwork $network): JsonResponse
    {
        $this->assertOwner($request->user()?->getKey(), $network);

        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'description' => 'nullable|string',
            'duration_minutes' => 'required|integer|min:1',
            'data_allowance_mb' => 'nullable|integer|min:1',
            'validity_days' => 'nullable|integer|min:1',
            'speed_mbps' => 'nullable|numeric|min:0',
            'price' => 'required|numeric|min:0.01',
            'currency' => 'required|string|size:3',
            'commission_rate_override' => 'nullable|numeric|min:0|max:100',
            'is_active' => 'boolean',
            'meta' => 'array|nullable',
        ]);

        $plan = $network->plans()->create($validated);

        return response()->json(['data' => $plan->fresh()], 201);
    }

    public function update(Request $request, WifiPlan $plan): JsonResponse
    {
        $plan->loadMissing('network');

        $this->assertOwner($request->user()?->getKey(), $plan->network);

        $validated = $request->validate([
            'name' => 'sometimes|string|max:255',
            'description' => 'sometimes|nullable|string',
            'duration_minutes' => 'sometimes|integer|min:1',
            'data_allowance_mb' => 'sometimes|nullable|integer|min:1',
            'validity_days' => 'sometimes|nullable|integer|min:1',
            'speed_mbps' => 'sometimes|nullable|numeric|min:0',
            'price' => 'sometimes|numeric|min:0.01',
            'currency' => 'sometimes|string|size:3',
            'commission_rate_override' => 'sometimes|nullable|numeric|min:0|max:100',
            'is_active' => 'sometimes|boolean',
            'meta' => 'sometimes|array|nullable',
        ]);

        $plan->fill($validated)->save();

        return response()->json(['data' => $plan->refresh()]);
    
    }

    public function purchase(
        Request $request,
        WifiPlan $plan,
        PaymentFulfillmentService $fulfillmentService,
        WalletService $walletService
    ): JsonResponse
    
    {
        $plan->loadMissing('network');

        if (!$plan->is_active || !$plan->network?->is_active) {
            abort(422, __('The selected Wi-Fi plan is not currently available.'));
        }

        $user = $request->user();
        $paymentGateway = (string) $request->input('payment_gateway', 'wallet');

        $transaction = PaymentTransaction::create([
            'user_id' => $user->getKey(),
            'amount' => $plan->price,
            'currency' => $plan->currency,
            'payment_gateway' => $paymentGateway,


            'payment_status' => 'pending',
            'idempotency_key' => (string) Str::uuid(),
            'meta' => [
                'initiated_via' => 'wifi_plan_purchase',
                'requested_via' => 'api',
                'payment_gateway' => $paymentGateway,

            ],
        ]);


        if ($paymentGateway !== 'wallet') {
            return response()->json([
                'data' => [
                    'transaction_id' => $transaction->getKey(),
                    'payment_gateway' => $paymentGateway,
                    'payment_status' => $transaction->payment_status,
                    'amount' => (float) $transaction->amount,
                    'currency' => $transaction->currency,
                    'idempotency_key' => $transaction->idempotency_key,
                    'meta' => $transaction->meta,
                ],
                'message' => __('Payment initiated. Awaiting confirmation from the gateway.'),
            ], 202);
        }

        try {
            $walletTransaction = $walletService->debit($user, $transaction->idempotency_key, (float) $plan->price, [
                'currency' => $plan->currency,
                'payment_transaction' => $transaction,
                'meta' => array_filter([
                    'source' => 'wifi_plan_purchase',
                    'wifi_plan_id' => $plan->getKey(),
                    'wifi_network_id' => $plan->wifi_network_id,
                ]),
            ]);
        } catch (Throwable $throwable) {
            $transaction->forceFill([
                'payment_status' => 'failed',
                'meta' => array_replace_recursive($transaction->meta ?? [], [
                    'wallet' => [
                        'error' => $throwable->getMessage(),
                    ],
                ]),
            ])->save();

            return response()->json([
                'message' => $throwable->getMessage(),
            ], 422);
        }


        $result = $fulfillmentService->fulfill($transaction, WifiPlan::class, $plan->getKey(), $user->getKey(), [
            'payment_gateway' => 'wallet',
            'notify' => false,
            'wallet_transaction' => $walletTransaction,

            'meta' => [
                'requested_via' => 'api',
                'wallet' => [
                    'amount' => (float) $walletTransaction->amount,
                    'currency' => $walletTransaction->currency,
                    'balance_after' => (float) $walletTransaction->balance_after,
                ],

            ],
        ]);

        if ($result['error']) {

            try {
                $refundTransaction = $walletService->credit($user, $transaction->idempotency_key . '-refund', (float) $walletTransaction->amount, [
                    'currency' => $walletTransaction->currency,
                    'payment_transaction' => $transaction,
                    'meta' => array_filter([
                        'source' => 'wifi_plan_purchase_refund',
                        'original_transaction_id' => $walletTransaction->getKey(),
                    ]),
                ]);

                $transaction->forceFill([
                    'payment_status' => 'failed',
                    'meta' => array_replace_recursive($transaction->meta ?? [], [
                        'wallet' => [
                            'refunded' => true,
                            'refund_transaction_id' => $refundTransaction->getKey(),
                        ],
                    ]),
                ])->save();
            } catch (Throwable $refundError) {
                Log::error('Failed to refund wallet after Wi-Fi plan purchase failure.', [
                    'transaction_id' => $transaction->getKey(),
                    'wallet_transaction_id' => $walletTransaction->getKey(),
                    'error' => $refundError->getMessage(),
                ]);

                $transaction->forceFill([
                    'payment_status' => 'failed',
                    'meta' => array_replace_recursive($transaction->meta ?? [], [
                        'wallet' => [
                            'refunded' => false,
                            'refund_error' => $refundError->getMessage(),
                        ],
                    ]),
                ])->save();
            }

            return response()->json([
                'message' => $result['message'],
            ], 422);
        }

        $transaction = $result['transaction'];
        $transaction->refresh();

        $codeId = $transaction->meta['wifi_code_id'] ?? null;
        $code = $codeId ? WifiCode::find($codeId) : null;

        return response()->json([
            'data' => [
                'transaction_id' => $transaction->getKey(),
                'wifi_code' => $code?->toDecryptedArray(),
                'meta' => $transaction->meta,
            ],
        ]);
    }

    public function webhook(Request $request, PaymentFulfillmentService $fulfillmentService): JsonResponse
    {

        $gateway = (string) $request->input('payment_gateway', 'webhook');
        $configuration = PaymentConfiguration::query()
            ->where('payment_method', $gateway)
            ->first();

        if (! $configuration || ! $configuration->status) {
            return response()->json([
                'message' => __('Payment gateway is not enabled for webhook processing.'),
            ], 503);
        }

        $secret = (string) $configuration->webhook_secret_key;

        if ($secret === '') {
            return response()->json([
                'message' => __('Webhook secret key is not configured for the selected payment gateway.'),
            ], 503);
        }

        $signature = $request->header('X-Signature');

        if ($signature === null) {
            return response()->json([
                'message' => __('Missing webhook signature header.'),
            ], 400);
        }

        if (str_starts_with($signature, 'sha256=')) {
            $signature = substr($signature, 7) ?: '';
        }

        $expectedSignature = hash_hmac('sha256', $request->getContent(), $secret);

        if (! hash_equals($expectedSignature, $signature)) {
            return response()->json([
                'message' => __('Invalid webhook signature.'),
            ], 403);
        }

        $transactionId = $request->input('transaction_id');
        $transaction = PaymentTransaction::findOrFail($transactionId);

        $planId = $transaction->payable_id ?? $request->input('plan_id');
        $userId = $transaction->user_id ?? $request->input('user_id');

        $result = $fulfillmentService->fulfill($transaction, WifiPlan::class, $planId, $userId, [
            'payment_gateway' => $request->input('payment_gateway', 'webhook'),
            'notify' => true,
            'meta' => $request->input('meta', []),
        ]);

        return response()->json($result);
    }

    private function assertOwner(?int $userId, WifiNetwork $network): void
    {
        if ($userId === null || $network->user_id !== $userId) {
            abort(403, __('You are not allowed to manage this Wi-Fi network.'));
        }
    }
}