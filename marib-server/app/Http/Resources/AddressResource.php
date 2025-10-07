<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\Address */
class AddressResource extends JsonResource
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
            'label' => $this->label,
            'phone' => $this->phone,
            'latitude' => (float) $this->latitude,
            'longitude' => (float) $this->longitude,
            'distance_km' => $this->distanceInKm(),


            'area_id' => $this->area_id,
            'street' => $this->street,
            'building' => $this->building,
            'note' => $this->note,
            'is_default' => (bool) $this->is_default,
            'created_at' => optional($this->created_at)->toISOString(),
            'updated_at' => optional($this->updated_at)->toISOString(),
        ];
    }
}   