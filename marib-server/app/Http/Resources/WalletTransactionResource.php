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
            'currency' => strtoupper(config('app.currency', 'SAR')),
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
            return 'top-up';
        }

        if (in_array($reason, ['refund', 'wallet_refund'], true)) {
            return 'refund';
        }

        if ($this->type === 'debit') {
            return 'payment';
        }

        return (string) $this->type;
    }
}