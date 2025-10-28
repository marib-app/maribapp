<?php

namespace App\Http\Resources;

use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Arr;

class AttachmentResource extends JsonResource
{
    public function toArray($request): array
    {
        $size = $this->numericValue('size');

        return array_filter([
            'type'        => $this->stringValue('type'),
            'name'        => $this->stringValue('name'),
            'path'        => $this->stringValue('path'),
            'disk'        => $this->stringValue('disk'),
            'mime_type'   => $this->stringValue('mime_type'),
            'size'        => $size,
            'uploaded_at' => $this->stringValue('uploaded_at'),
            'url'         => $this->stringValue('url'),
        ], static fn ($value) => $value !== null);
    }

    private function stringValue(string $key): ?string
    {
        $value = Arr::get($this->resource, $key);

        if (! is_string($value)) {
            return null;
        }

        $trimmed = trim($value);

        return $trimmed === '' ? null : $trimmed;
    }

    private function numericValue(string $key): ?float
    {
        $value = Arr::get($this->resource, $key);

        if (! is_numeric($value)) {
            return null;
        }

        return (float) $value;
    }
}

