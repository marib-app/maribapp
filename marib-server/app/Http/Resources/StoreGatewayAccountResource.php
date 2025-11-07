<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\StoreGatewayAccount */
class StoreGatewayAccountResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'seller_id' => $this->user_id,
            'store_gateway_id' => $this->store_gateway_id,
            'store_id' => $this->store_id,
            'beneficiary_name' => $this->beneficiary_name,
            'account_number' => $this->account_number,
            'is_active' => (bool) $this->is_active,
            'store_gateway' => new StoreGatewayResource($this->whenLoaded('storeGateway')),
            'store' => $this->whenLoaded('store', function () {
                return [
                    'id' => $this->store?->id,
                    'name' => $this->store?->name,
                    'status' => $this->store?->status,
                ];
            }),
            'created_at' => optional($this->created_at)?->toIso8601String(),
            'updated_at' => optional($this->updated_at)?->toIso8601String(),
        ];
    }
}
