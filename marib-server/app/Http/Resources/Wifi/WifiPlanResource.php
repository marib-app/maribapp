<?php

namespace App\Http\Resources\Wifi;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\Wifi\WifiPlan */
class WifiPlanResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {

        $canManage = $request->user()?->can('update', $this->resource) ?? false;


        return [
            'id' => $this->id,
            'network_id' => $this->wifi_network_id,
            'name' => $this->name,
            'slug' => $this->slug,
            'status' => $this->status?->value,
            'price' => $this->price !== null ? (float) $this->price : null,
            'currency' => $this->currency,
            'duration_days' => $this->duration_days,
            'data_cap_gb' => $this->data_cap_gb !== null ? (float) $this->data_cap_gb : null,
            'is_unlimited' => (bool) $this->is_unlimited,
            'sort_order' => $this->sort_order,
            'description' => $this->description,
            'notes' => $this->when($canManage, $this->notes),
            'benefits' => $this->benefits,
            'meta' => $this->meta,
            'created_at' => $this->when($this->created_at, fn () => $this->created_at->toIso8601String()),
            'updated_at' => $this->when($this->updated_at, fn () => $this->updated_at->toIso8601String()),
            'network' => WifiNetworkResource::make($this->whenLoaded('network')),
            'code_batches' => WifiCodeBatchResource::collection($this->whenLoaded('codeBatches')),
        ];
    }
}