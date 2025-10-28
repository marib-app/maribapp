<?php

namespace App\Http\Resources;

use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Arr;

class OrderResource extends JsonResource
{
    public function toArray($request): array
    {
        $total = $this->numericValue([
            'total',
            'total_amount',
            'grand_total',
        ]);

        return array_filter([
            'id'              => $this->integerValue(['id', 'order_id']),
            'order_number'    => $this->stringValue('order_number'),
            'status'          => $this->stringValue('status'),
            'payment_status'  => $this->stringValue('payment_status'),
            'currency'        => $this->stringValue('currency'),
            'total'           => $total,
            'department'      => $this->stringValue('department'),
            'created_at'      => $this->dateTimeValue('created_at'),
            'updated_at'      => $this->dateTimeValue('updated_at'),
            'payment_method'  => $this->stringValue('payment_method'),
            'payment_gateway' => $this->stringValue('payment_gateway'),
        ], static fn ($value) => $value !== null);
    }

    private function stringValue(string|array $keys): ?string
    {
        $value = Arr::get($this->resource, $keys);

        if (! is_string($value)) {
            return null;
        }

        $trimmed = trim($value);

        return $trimmed === '' ? null : $trimmed;
    }

    private function integerValue(string|array $keys): ?int
    {
        $value = Arr::get($this->resource, $keys);

        if (! is_numeric($value)) {
            return null;
        }

        return (int) $value;
    }

    private function numericValue(string|array $keys): ?float
    {
        $value = Arr::get($this->resource, $keys);

        if (! is_numeric($value)) {
            return null;
        }

        return (float) $value;
    }

    private function dateTimeValue(string $key): ?string
    {
        $value = Arr::get($this->resource, $key);

        if ($value instanceof \DateTimeInterface) {
            return $value->format(\DateTimeInterface::ATOM);
        }

        if (is_string($value)) {
            $trimmed = trim($value);

            return $trimmed === '' ? null : $trimmed;
        }

        return null;
    }
}

