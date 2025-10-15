<?php

namespace App\Http\Resources;

use App\Models\ManualPaymentRequest;
use Illuminate\Http\Resources\Json\JsonResource;

class WalletTransactionResource extends JsonResource
{
    public function toArray($request): array
    {
        $currency = $this->resolveCurrency();
        $decimals = $this->resolveCurrencyPrecision($currency);

        $amount = $this->normalizeMoney($this->amount, $decimals);
        $balanceAfter = $this->normalizeMoney($this->balance_after, $decimals);
        $balanceBefore = $this->calculateBalanceBefore($amount, $balanceAfter, $decimals);

        return [
            'id' => $this->id,
            'type' => $this->type,
            'currency' => $currency,
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

    private function resolveCurrencyPrecision(string $currency): int
    {
        $precision = config('wallet.currency_precision.' . strtoupper($currency));

        if (is_numeric($precision)) {
            $precision = (int) $precision;

            if ($precision >= 0 && $precision <= 6) {
                return $precision;
            }
        }

        return 2;
    }

    private function normalizeMoney($value, int $decimals): float
    {
        $numericValue = is_numeric($value) ? (float) $value : 0.0;

        return (float) number_format($numericValue, $decimals, '.', '');
    }

    private function calculateBalanceBefore(float $amount, float $balanceAfter, int $decimals): float
    {
        $balance = $this->type === 'credit'
            ? $balanceAfter - $amount
            : $balanceAfter + $amount;

        return (float) number_format($balance, $decimals, '.', '');
    }
}
