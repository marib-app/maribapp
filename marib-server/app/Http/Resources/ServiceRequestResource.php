<?php

namespace App\Http\Resources;

use App\Models\Service;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Arr;

class ServiceRequestResource extends JsonResource
{
    public function toArray($request): array
    {
        $service = $this->resolveServicePayload();

        return array_filter([
            'id'                     => $this->integerValue(['id', 'service_request_id']),
            'service_id'             => $this->integerValue('service_id'),
            'status'                 => $this->stringValue('status'),
            'payment_status'         => $this->stringValue('payment_status'),
            'amount'                 => $this->numericValue(['amount', 'price']),
            'currency'               => $this->stringValue('currency'),
            'price_note'             => $this->stringValue('price_note'),
            'payment_transaction_id' => $this->integerValue('payment_transaction_id'),
            'service_uid'            => $this->stringValue('service_uid'),
            'created_at'             => $this->dateTimeValue('created_at'),
            'updated_at'             => $this->dateTimeValue('updated_at'),
            'service'                => $service,
        ], static fn ($value) => $value !== null);
    }

    private function resolveServicePayload(): ?array
    {
        if (! $this->relationLoaded('service')) {
            return null;
        }

        $service = $this->service;

        if (! $service instanceof Service) {
            return null;
        }

        return array_filter([
            'id'         => $service->getKey(),
            'title'      => $service->title,
            'price'      => $service->price !== null ? (float) $service->price : null,
            'currency'   => $service->currency,
            'service_uid'=> $service->service_uid,
            'price_note' => $service->price_note,
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

