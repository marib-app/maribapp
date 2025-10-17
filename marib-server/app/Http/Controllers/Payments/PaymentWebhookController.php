<?php

namespace App\Http\Controllers\Payments;

use App\Exceptions\PaymentWebhookException;
use App\Http\Controllers\Controller;
use App\Services\Payments\Webhooks\PaymentWebhookService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

class PaymentWebhookController extends Controller
{
    public function __construct(private readonly PaymentWebhookService $paymentWebhookService)
    {
    }

    public function wallet(Request $request): JsonResponse
    {
        return $this->process('wallet', $request);
    }

    public function bankAlsharq(Request $request): JsonResponse
    {
        return $this->process('east_yemen_bank', $request);
    }

    private function process(string $gateway, Request $request): JsonResponse
    {
        $rawBody = $request->getContent();
        $payload = $request->all();
        $signature = $request->header('X-Signature');

        try {
            $transaction = $this->paymentWebhookService->handle($gateway, $rawBody, $payload, $signature);

            return response()->json([
                'processed' => true,
                'transaction_id' => $transaction->getKey(),
                'status' => $transaction->payment_status,
            ]);
        } catch (PaymentWebhookException $exception) {
            return response()->json([
                'processed' => false,
                'message' => $exception->getMessage(),
            ], $exception->status);
        } catch (\Throwable $throwable) {
            Log::error('payment_webhook.unhandled_error', [
                'gateway' => $gateway,
                'message' => $throwable->getMessage(),
                'trace' => $throwable->getTraceAsString(),
            ]);

            return response()->json([
                'processed' => false,
                'message' => 'Unable to process webhook payload.',
            ], 500);
        }
    }
}