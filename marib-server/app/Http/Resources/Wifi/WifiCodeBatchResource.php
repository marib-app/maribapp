<?php

namespace App\Http\Resources\Wifi;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\Wifi\WifiCodeBatch */
class WifiCodeBatchResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $canManage = $request->user()?->can('update', $this->resource) ?? false;

        return [
            'id' => $this->id,
            'plan_id' => $this->wifi_plan_id,
            'label' => $this->label,
            'source_filename' => $this->when($canManage, $this->source_filename),
            'checksum' => $this->when($canManage, $this->checksum),
            'status' => $this->status?->value,
            'total_codes' => $this->total_codes,
            'available_codes' => $this->available_codes,
            'validated_at' => $this->when($this->validated_at, fn () => $this->validated_at?->toIso8601String()),
            'activated_at' => $this->when($this->activated_at, fn () => $this->activated_at?->toIso8601String()),
            'notes' => $this->when($canManage, $this->notes),
            'meta' => $this->meta,
            'created_at' => $this->when($this->created_at, fn () => $this->created_at->toIso8601String()),
            'updated_at' => $this->when($this->updated_at, fn () => $this->updated_at->toIso8601String()),
            'plan' => WifiPlanResource::make($this->whenLoaded('plan')),
            'uploader_id' => $this->when($canManage, $this->uploaded_by),
        ];
    }
}