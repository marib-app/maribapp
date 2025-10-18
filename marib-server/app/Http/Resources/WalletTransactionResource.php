<?php

namespace App\Http\Resources;

use App\Models\ManualPaymentRequest;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Contracts\Support\Arrayable;
use Illuminate\Support\Arr;



class WalletTransactionResource extends JsonResource
{
    public function toArray($request): array
    {
        $currency = $this->resolveCurrency();
        $decimals = $this->resolveCurrencyPrecision($currency);

        $amount = $this->normalizeMoney($this->amount, $decimals);
        $balanceAfter = $this->normalizeMoney($this->balance_after, $decimals);
        $balanceBefore = $this->calculateBalanceBefore($amount, $balanceAfter, $decimals);

        $meta = $this->resolveMeta();
        $appliedFilters = $this->resolveAppliedFilters($meta);
        $references = $this->resolveReferences($meta);


        return [
            'id' => $this->id,
            'type' => $this->type,
            'category' => $this->resolveCategory(),
            'currency' => $currency,
            'amount' => $amount,
            'balance_before' => $balanceBefore,
            'balance_after' => $balanceAfter,
            'idempotency_key' => $this->idempotency_key,
            'description' => $this->resolveDescription($meta),
            'reason' => data_get($meta, 'reason'),
            'reference_code' => $this->resolveReferenceCode($meta),
            'references' => $references,
            'deeplink' => $this->resolveDeeplink($meta),
            'filters' => $appliedFilters,
            'applied_filters' => $appliedFilters,
            'meta' => $meta,
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




    private function resolveMeta(): array
    {
        $meta = $this->meta;

        if (is_array($meta)) {
            return $meta;
        }

        if ($meta instanceof \JsonSerializable) {
            $meta = $meta->jsonSerialize();
        } elseif ($meta instanceof \Traversable) {
            $meta = iterator_to_array($meta);
        } elseif ($meta instanceof \Arrayable) {
            $meta = $meta->toArray();
        } elseif ($meta instanceof \stdClass) {
            $meta = (array) $meta;
        }

        return is_array($meta) ? $meta : [];
    }

    private function resolveDescription(array $meta): ?string
    {
        $candidates = [
            data_get($meta, 'description'),
            data_get($meta, 'title'),
            data_get($meta, 'message'),
            data_get($meta, 'summary'),
            data_get($meta, 'note'),
            data_get($meta, 'notes'),
            data_get($meta, 'withdrawal_notes'),
        ];

        foreach ($candidates as $candidate) {
            if (is_string($candidate)) {
                $trimmed = trim($candidate);
                if ($trimmed !== '') {
                    return $trimmed;
                }
            }
        }

        return null;
    }

    private function resolveReferenceCode(array $meta): ?string
    {
        $candidates = [
            data_get($meta, 'reference_code'),
            data_get($meta, 'reference'),
            data_get($meta, 'wallet_reference'),
            data_get($meta, 'withdrawal_request_reference'),
            data_get($meta, 'transfer_reference'),
            data_get($meta, 'external_reference'),
            data_get($meta, 'manual_reference'),
            data_get($meta, 'receipt'),
        ];

        foreach ($candidates as $candidate) {
            if (is_string($candidate)) {
                $trimmed = trim($candidate);
                if ($trimmed !== '') {
                    return $trimmed;
                }
            }
        }

        return null;
    }

    private function resolveReferences(array $meta): array
    {
        $references = [];

        $candidates = [
            data_get($meta, 'references'),
            data_get($meta, 'refs'),
        ];

        foreach ($candidates as $candidate) {
            if (is_array($candidate)) {
                foreach ($candidate as $value) {
                    if (is_string($value)) {
                        $trimmed = trim($value);
                        if ($trimmed !== '') {
                            $references[] = $trimmed;
                        }
                    }
                }
            } elseif (is_string($candidate)) {
                $trimmed = trim($candidate);
                if ($trimmed !== '') {
                    $references[] = $trimmed;
                }
            }
        }

        $singleValues = [
            data_get($meta, 'reference'),
            data_get($meta, 'reference_code'),
            data_get($meta, 'wallet_reference'),
            data_get($meta, 'withdrawal_request_reference'),
            data_get($meta, 'transfer_reference'),
            data_get($meta, 'external_reference'),
            data_get($meta, 'manual_reference'),
            data_get($meta, 'receipt'),
        ];

        foreach ($singleValues as $value) {
            if (is_string($value)) {
                $trimmed = trim($value);
                if ($trimmed !== '') {
                    $references[] = $trimmed;
                }
            }
        }

        return array_values(array_unique($references));
    }

    private function resolveDeeplink(array $meta): ?string
    {
        $candidates = [
            data_get($meta, 'deeplink'),
            data_get($meta, 'links.deeplink'),
            data_get($meta, 'links.url'),
            data_get($meta, 'navigation.deeplink'),
            data_get($meta, 'navigation.url'),
            data_get($meta, 'wallet.deeplink'),
        ];

        foreach ($candidates as $candidate) {
            if (is_string($candidate)) {
                $trimmed = trim($candidate);
                if ($trimmed !== '') {
                    return $trimmed;
                }
            }
        }

        return null;
    }

    private function resolveAppliedFilters(array $meta): array
    {
        $filters = data_get($meta, 'filters.applied');

        if ($filters === null) {
            $filters = data_get($meta, 'filters');
        }

        if ($filters instanceof \JsonSerializable) {
            $filters = $filters->jsonSerialize();
        } elseif ($filters instanceof \Traversable) {
            $filters = iterator_to_array($filters);
        }

        if (!is_array($filters)) {
            return [];
        }

        if (Arr::isAssoc($filters)) {
            $filters = array_values(array_filter($filters, static function ($value) {
                return $value !== null && $value !== '';
            }));
        }

        return array_values(array_filter($filters, static function ($value) {
            if (is_string($value)) {
                return trim($value) !== '';
            }

            if (is_array($value)) {
                return !empty(array_filter($value, static function ($nested) {
                    if (is_string($nested)) {
                        return trim($nested) !== '';
                    }

                    return $nested !== null;
                }));
            }

            return $value !== null;
        }));
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
