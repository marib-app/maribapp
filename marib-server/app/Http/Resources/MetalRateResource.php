<?php

namespace App\Http\Resources;


use App\Services\MetalIconStorageService;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\MetalRate */
class MetalRateResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'metal_type' => $this->metal_type,
            'karat' => $this->karat !== null ? (float) $this->karat : null,
            'display_name' => $this->display_name,
            'buy_price' => (float) $this->buy_price,
            'sell_price' => (float) $this->sell_price,
            'source' => $this->source,
            'icon_url' => app(MetalIconStorageService::class)->getUrl($this->icon_path),
            'icon_alt' => $this->icon_alt,

            'quoted_at' => $this->quoted_at?->toIso8601String(),
            'updated_at' => $this->updated_at?->toIso8601String(),
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}