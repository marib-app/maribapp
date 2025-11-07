<?php

namespace App\Http\Resources;

use Illuminate\Http\Resources\Json\JsonResource;

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
            'status'          => $this->stringValue(['status', 'order_status']),
            'payment_status'  => $this->stringValue(['payment_status', 'order_payment_status']),
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
        $value = $this->valueForKeys($keys);

        if (! is_string($value)) {
            return null;
        }

        $trimmed = trim($value);

        return $trimmed === '' ? null : $trimmed;
    }

    private function integerValue(string|array $keys): ?int
    {
        $value = $this->valueForKeys($keys);

        if (! is_numeric($value)) {
            return null;
        }

        return (int) $value;
    }

    private function numericValue(string|array $keys): ?float
    {
        $value = $this->valueForKeys($keys);

        if (! is_numeric($value)) {
            return null;
        }

        return (float) $value;
    }

    private function dateTimeValue(string $key): ?string
    {
        $value = $this->valueForKeys($key);

        if ($value instanceof \DateTimeInterface) {
            return $value->format(\DateTimeInterface::ATOM);
        }

        if (is_string($value)) {
            $trimmed = trim($value);

            return $trimmed === '' ? null : $trimmed;
        }

        return null;
}

    private function valueForKeys(string|array $keys): mixed
    {
        $keysList = is_array($keys) ? $keys : [$keys];

        foreach ($keysList as $key) {
            $lookupKey = null;

            if (is_string($key) && $key !== '') {
                $lookupKey = $key;
            } elseif (is_array($key)) {
                $segments = array_values(array_filter(
                    $key,
                    static fn ($segment) => is_string($segment) && $segment !== ''
                ));

                if ($segments !== []) {
                    $lookupKey = implode('.', $segments);
                }
            }

            if ($lookupKey === null) {
                continue;
            }

            $value = data_get($this->resource, $lookupKey);

            if ($value !== null) {
                return $value;
            }
        }

        return null;
    }
}

