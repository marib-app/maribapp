<?php

namespace App\Http\Resources;

use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Str;

class WalletWithdrawalRequestResource extends JsonResource
{
    protected array $methods;

    public function __construct($resource, array $methods = [])
    {
        parent::__construct($resource);

        $this->methods = $methods;
    }

    public function toArray($request): array
    {
        $methodKey = (string) ($this->preferred_method ?? '');
        $method = $this->methods[$methodKey] ?? [
            'key' => $methodKey,
            'name' => $methodKey !== ''
                ? __(Str::headline(str_replace('_', ' ', $methodKey)))
                : null,
        ];

        if (! array_key_exists('description', $method)) {
            $method['description'] = null;
        }

        $transaction = $this->transaction;
        $rawCurrency = $this->account?->currency
            ?? $transaction?->currency
            ?? config('app.currency', 'SAR');
        $currency = strtoupper((string) $rawCurrency);

        if ($currency === '') {
            $currency = strtoupper((string) config('app.currency', 'SAR'));
        }

        return [
            'id' => $this->id,
            'status' => $this->status,
            'status_label' => method_exists($this->resource, 'statusLabel')
                ? $this->statusLabel()
                : $this->status,
            'amount' => isset($this->amount) ? (float) $this->amount : 0.0,
            'currency' => $currency,
            'method' => array_filter($method, static fn ($value) => $value !== null && $value !== ''),
            'notes' => $this->notes,
            'meta' => $this->meta ?? [],
            'balance_after' => $transaction?->balance_after !== null
                ? (float) $transaction->balance_after
                : null,
            'wallet_transaction_id' => $this->wallet_transaction_id,
            'wallet_reference' => $this->wallet_reference,
            'created_at' => optional($this->created_at)->toIso8601String(),
            'updated_at' => optional($this->updated_at)->toIso8601String(),
        ];
    }
}