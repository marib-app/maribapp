<?php

namespace App\Services;

use App\Models\OrderItem;
use Carbon\Carbon;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Throwable;

class OrderDepositRefundService
{
    public function __construct(private WalletService $walletService)
    {
    }

    /**
     * @param array{update_item?: bool} $options
     */
    public function compensateOrderItem(OrderItem $orderItem, string $reason, array $options = []): ?float
    {
        $order = $orderItem->order()->with('user')->first();

        if (! $order || ! $order->user) {
            return null;
        }

        $pricingSnapshot = is_array($orderItem->pricing_snapshot) ? $orderItem->pricing_snapshot : [];
        $policy = Arr::get($pricingSnapshot, 'deposit');

        if (! is_array($policy) || $policy === []) {
            return null;
        }

        $itemRequired = (float) ($policy['required_amount'] ?? $orderItem->deposit_remaining_balance ?? 0.0);
        $itemRequired = round(max($itemRequired, 0.0), 2);

        if ($itemRequired <= 0.0) {
            return null;
        }

        $shouldUpdateItem = ($options['update_item'] ?? true) === true;

        return DB::transaction(function () use ($order, $orderItem, $reason, $policy, $itemRequired, $shouldUpdateItem) {
            $order->refresh();
            $payload = is_array($order->payment_payload) ? $order->payment_payload : [];
            $depositPayload = Arr::get($payload, 'deposit', []);

            if (! is_array($depositPayload)) {
                $depositPayload = [];
            }

            $refunds = isset($depositPayload['refunds']) && is_array($depositPayload['refunds'])
                ? $depositPayload['refunds']
                : [];

            foreach ($refunds as $refund) {
                if ((int) ($refund['order_item_id'] ?? 0) === $orderItem->getKey()) {
                    return null;
                }
            }

            $previousRequired = (float) ($depositPayload['required_amount']
                ?? (($order->deposit_amount_paid ?? 0.0) + ($order->deposit_remaining_balance ?? 0.0)));
            $previousPaid = (float) ($depositPayload['paid_amount'] ?? ($order->deposit_amount_paid ?? 0.0));

            $previousRequired = round(max($previousRequired, 0.0), 2);
            $previousPaid = round(max(min($previousPaid, $previousRequired), 0.0), 2);

            $itemRequiredValue = min($itemRequired, $previousRequired);
            $newRequired = max(round($previousRequired - $itemRequiredValue, 2), 0.0);
            $refundAmount = max(round($previousPaid - $newRequired, 2), 0.0);
            $paidAfter = max(round($previousPaid - $refundAmount, 2), 0.0);
            $remainingAfter = max(round($newRequired - $paidAfter, 2), 0.0);

            $depositPayload['required_amount'] = $newRequired;
            $depositPayload['paid_amount'] = $paidAfter;
            $depositPayload['remaining_amount'] = $remainingAfter;
            $depositPayload['status'] = $remainingAfter <= 0.0 ? 'settled' : 'pending';

            $currency = $depositPayload['currency'] ?? ($order->currency ?? config('app.currency', 'SAR'));
            $currency = is_string($currency) && $currency !== '' ? strtoupper($currency) : strtoupper(config('app.currency', 'SAR'));
            $depositPayload['currency'] = $currency;

            $idempotencyKey = sprintf('order:%d:item:%d:%s:deposit_refund', $order->getKey(), $orderItem->getKey(), $reason);

            $walletTransaction = null;

            if ($refundAmount > 0.0) {
                try {
                    $walletTransaction = $this->walletService->credit($order->user, $idempotencyKey, $refundAmount, [
                        'currency' => $currency,
                        'meta' => [
                            'reason' => 'deposit_refund',
                            'order_id' => $order->getKey(),
                            'order_item_id' => $orderItem->getKey(),
                            'trigger' => $reason,
                            'policy' => $policy['policy'] ?? null,
                            'item_name' => $orderItem->item_name,
                        ],
                    ]);
                } catch (Throwable $throwable) {
                    Log::error('Failed to credit deposit refund to wallet.', [
                        'order_id' => $order->getKey(),
                        'order_item_id' => $orderItem->getKey(),
                        'amount' => $refundAmount,
                        'reason' => $reason,
                        'error' => $throwable->getMessage(),
                    ]);

                    throw $throwable;
                }
            }

            $refundRecord = [
                'order_item_id' => $orderItem->getKey(),
                'amount' => round($refundAmount, 2),
                'currency' => $currency,
                'reason' => $reason,
                'recorded_at' => Carbon::now()->toIso8601String(),
                'idempotency_key' => $idempotencyKey,
                'wallet_transaction_id' => $walletTransaction?->getKey(),
                'policy' => $policy['policy'] ?? null,
                'subtotal' => $policy['subtotal'] ?? null,
                'required_amount_before' => $itemRequiredValue,
            ];

            if ($orderItem->item_name !== null) {
                $refundRecord['item_name'] = $orderItem->item_name;
            }

            $refunds[] = $refundRecord;
            $depositPayload['refunds'] = array_values($refunds);

            Arr::set($payload, 'deposit', $depositPayload);

            $order->forceFill([
                'deposit_amount_paid' => $paidAfter,
                'deposit_remaining_balance' => $remainingAfter,
                'payment_payload' => $payload,
            ])->save();

            if ($shouldUpdateItem && $orderItem->exists) {
                $orderItem->forceFill([
                    'deposit_remaining_balance' => 0.0,
                ])->saveQuietly();
            }

            return $refundAmount;
        });
    }
}