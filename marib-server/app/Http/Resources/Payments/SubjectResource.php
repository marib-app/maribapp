<?php

namespace App\Http\Resources\Payments;

use App\Models\ServiceRequest;
use Illuminate\Http\Resources\Json\JsonResource;

class SubjectResource extends JsonResource
{
    public function toArray($request): array
    {
        $data = $this->resolveData($this->resource);

        return array_filter([
            'type' => $data['type'] ?? null,
            'id' => $data['id'] ?? null,
            'number' => $data['number'] ?? null,
            'status' => $data['status'] ?? null,
        ], static fn ($value) => $value !== null);
    }

    /**
     * @param mixed $resource
     * @return array<string, mixed>
     */
    private function resolveData(mixed $resource): array
    {
        if ($resource instanceof ServiceRequest) {
            return [
                'type' => 'service_request',
                'id' => $resource->getKey(),
                'number' => $resource->request_number,
                'status' => $resource->payment_status ?? $resource->status,
            ];
        }

        if (is_array($resource)) {
            return $resource;
        }

        if (is_object($resource) && method_exists($resource, 'toArray')) {
            return (array) $resource->toArray();
        }

        return [];
    }
}

