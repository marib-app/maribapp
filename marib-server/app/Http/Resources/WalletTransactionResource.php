<?php

namespace App\Http\Resources;

use App\Models\ManualPaymentRequest;
use Illuminate\Http\Resources\Json\JsonResource;

class WalletTransactionResource extends JsonResource
{
    public function toArray($request): array
    {
        $amount = isset($this->amount) ? (float) $this->amount : 0.0;
        $balanceAfter = isset($this->balance_after) ? (float) $this->balance_after : 0.0;
        $balanceBefore = $this->type === 'credit'
            ? round($balanceAfter - $amount, 2)
            : round($balanceAfter + $amount, 2);

        return [
            'id' => $this->id,
            'type' => $this->type,
            'category' => $this->resolveCategory(),
            'amount' => $amount,
            'balance_before' => $balanceBefore,
            'balance_after' => $balanceAfter,
            'currency' => $this->resolveCurrency(),
            'reason' => data_get($this->meta, 'reason'),
            'meta' => $this->meta ?? [],
            'manual_payment_request_id' => $this->manual_payment_request_id,
            'payment_transaction_id' => $this->payment_transaction_id,
            'created_at' => optional($this->created_at)->toIso8601String(),
            'updated_at' => optional($this->updated_at)->toIso8601String(),
        ];
    }

    private function resolveCategory(): string
    {
        $reason = data_get($this->meta, 'reason');

        if ($reason === ManualPaymentRequest::PAYABLE_TYPE_WALLET_TOP_UP || $this->manual_payment_request_id) {
            return 'deposit';
        }

        if ($reason === 'wallet_transfer' || data_get($this->meta, 'context') === 'wallet_transfer') {
            return 'transfer';
        }

        if (in_array($reason, ['refund', 'wallet_refund'], true)) {
            return 'refund';
        }

        if ($this->type === 'debit') {
            return 'purchase';
        }

        if ($this->type === 'credit') {
            return 'deposit';
        }

        return (string) $this->type;
    }
    private function resolveCurrency(): string
    {
        $currency = $this->currency;

        if (!is_string($currency) || trim($currency) === '') {
            $currency = $this->account?->currency;
        }

        if (!is_string($currency) || trim($currency) === '') {
            $currency = config('app.currency', 'SAR');
        }

        $currency = strtoupper(trim((string) $currency));

        return $currency !== '' ? $currency : 'SAR';
    }
}