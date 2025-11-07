<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\Store */
class StoreResource extends JsonResource
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
            'name' => $this->name,
            'description' => $this->description,
            'slug' => $this->slug,
            'status' => $this->status,
            'status_changed_at' => optional($this->status_changed_at)?->toIso8601String(),
            'rejection_reason' => $this->rejection_reason,
            'financial_policy_type' => $this->financial_policy_type,
            'financial_policy_payload' => $this->financial_policy_payload,
            'contact_email' => $this->contact_email,
            'contact_phone' => $this->contact_phone,
            'contact_whatsapp' => $this->contact_whatsapp,
            'location' => [
                'address' => $this->location_address,
                'latitude' => $this->location_latitude,
                'longitude' => $this->location_longitude,
                'city' => $this->location_city,
                'state' => $this->location_state,
                'country' => $this->location_country,
                'notes' => $this->location_notes,
            ],
            'logo_path' => $this->logo_path,
            'logo_url' => $this->logo_path ? url(\Storage::url($this->logo_path)) : null,
            'banner_path' => $this->banner_path,
            'banner_url' => $this->banner_path ? url(\Storage::url($this->banner_path)) : null,
            'meta' => $this->meta ?? [],
            'settings' => new StoreSettingResource($this->whenLoaded('settings')),
            'working_hours' => StoreWorkingHourResource::collection($this->whenLoaded('workingHours')),
            'policies' => StorePolicyResource::collection($this->whenLoaded('policies')),
            'staff' => StoreStaffResource::collection($this->whenLoaded('staff')),
        ];
    }
}
