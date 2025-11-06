<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\Storage;

/** @mixin \App\Models\StoreGateway */
class StoreGatewayResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'logo_path' => $this->logo_path,
            'logo_url' => $this->logo_path ? url(Storage::url($this->logo_path)) : null,
            'is_active' => (bool) $this->is_active,
            'accounts' => StoreGatewayAccountResource::collection($this->whenLoaded('accounts')),
        ];
    }
}