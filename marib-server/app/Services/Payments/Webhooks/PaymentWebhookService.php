<?php

namespace App\Services\Payments\Webhooks;

use App\Exceptions\PaymentWebhookException;
use App\Models\PaymentConfiguration;
use App\Models\PaymentTransaction;
use App\Services\Payments\OrderPaymentService;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

class PaymentWebhookService
{
    public function __construct(private readonly OrderPaymentService $orderPaymentService)
    {
    }

    /**
     * @param array<string, mixed> $payload
     */
    public function handle(string $gateway, string $rawPayload, array $payload, ?string $signature): PaymentTransaction
    {
        $configuration = PaymentConfiguration::query()
            ->where('payment_method', $gateway)
            ->first();

        if (! $configuration || ! $configuration->status) {
            throw new PaymentWebhookException('Payment gateway is not enabled.', 503);
        }

        $secret = (string) $configuration->webhook_secret_key;

        if ($secret === '') {
            throw new PaymentWebhookException('Webhook secret key is not configured.', 503);
        }

        $this->assertValidSignature($secret, $rawPayload, $signature);

        $transactionId = Arr::get($payload, 'transaction_id');

        if (! $transactionId) {
            throw new PaymentWebhookException('Missing transaction identifier in payload.', 422);
        }

        $transaction = PaymentTransaction::query()
            ->with(['user', 'payable'])
            ->where('payment_gateway', $gateway)
            ->find($transactionId);

        if (! $transaction) {
            throw new PaymentWebhookException('Payment transaction not found.', 404);
        }

        $status = strtolower((string) Arr::get($payload, 'status'));

        if ($status === '') {
            throw new PaymentWebhookException('Missing status in webhook payload.', 422);
        }

        $eventId = $this->resolveEventId($payload);
        $receivedAt = now()->toIso8601String();

        $metaUpdates = [
            'webhook' => [
                $gateway => [
                    'event_id' => $eventId,
                    'status' => $status,
                    'signature' => $this->normalizeSignature($signature),
                    'received_at' => $receivedAt,
                    'payload' => $payload,
                ],
            ],
        ];

        if ($this->isSuccessfulStatus($status)) {
            return $this->processSuccess($transaction, $payload, $eventId, $metaUpdates);
        }

        if ($this->isFailureStatus($status)) {
            return $this->processFailure($transaction, $metaUpdates);
        }

        $transaction->meta = array_replace_recursive($transaction->meta ?? [], $metaUpdates);
        $transaction->save();

        return $transaction->fresh();
    }

    private function processSuccess(PaymentTransaction $transaction, array $payload, string $eventId, array $metaUpdates): PaymentTransaction
    {
        $user = $transaction->user;

        if (! $user) {
            throw new PaymentWebhookException('Unable to load the transaction user.', 422);
        }

        $idempotencyKey = (string) (Arr::get($payload, 'idempotency_key') ?: ('webhook:' . $eventId));
        $reference = Arr::get($payload, 'reference');

        try {
            $updated = $this->orderPaymentService->confirm($user, $transaction, $idempotencyKey, [
                'reference' => $reference,
                'status' => Arr::get($payload, 'status'),
                'webhook' => [
                    'event_id' => $eventId,
                    'payload' => $payload,
                ],
            ]);
        } catch (\Throwable $throwable) {
            Log::warning('payment_webhook.confirm_failed', [
                'transaction_id' => $transaction->getKey(),
                'event_id' => $eventId,
                'message' => $throwable->getMessage(),
            ]);

            throw new PaymentWebhookException('Failed to confirm the payment transaction.', 422, $throwable);
        }

        $updated->meta = array_replace_recursive($updated->meta ?? [], $metaUpdates);
        $updated->save();

        return $updated->fresh();
    }

    private function processFailure(PaymentTransaction $transaction, array $metaUpdates): PaymentTransaction
    {
        if ($transaction->payment_status !== 'succeed') {
            $transaction->payment_status = 'failed';
        }

        $transaction->meta = array_replace_recursive($transaction->meta ?? [], $metaUpdates);
        $transaction->save();

        return $transaction->fresh();
    }

    private function assertValidSignature(string $secret, string $rawPayload, ?string $signature): void
    {
        if (! $signature) {
            throw new PaymentWebhookException('Missing webhook signature header.', 400);
        }

        $normalizedSignature = $this->normalizeSignature($signature);
        $expected = hash_hmac('sha256', $rawPayload, $secret);

        if (! hash_equals($expected, $normalizedSignature)) {
            throw new PaymentWebhookException('Invalid webhook signature.', 403);
        }
    }

    private function normalizeSignature(?string $signature): ?string
    {
        if ($signature === null) {
            return null;
        }

        if (str_starts_with($signature, 'sha256=')) {
            return substr($signature, 7) ?: null;
        }

        return $signature;
    }

    /**
     * @param array<string, mixed> $payload
     */
    private function resolveEventId(array $payload): string
    {
        $eventId = Arr::get($payload, 'event_id')
            ?? Arr::get($payload, 'id')
            ?? Arr::get($payload, 'idempotency_key');

        if ($eventId) {
            return (string) $eventId;
        }

        return Str::uuid()->toString();
    }

    private function isSuccessfulStatus(string $status): bool
    {
        return in_array($status, ['success', 'succeeded', 'paid', 'completed'], true);
    }

    private function isFailureStatus(string $status): bool
    {
        return in_array($status, ['failed', 'failure', 'cancelled', 'rejected'], true);
    }
}