<?php

namespace App\Http\Resources\Wifi;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\Storage;

/** @mixin \App\Models\Wifi\WifiNetwork */
class WifiNetworkResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $canManage = $request->user()?->can('update', $this->resource) ?? false;

        $iconUrl = $this->icon_path ? Storage::url($this->icon_path) : null;
        $loginScreenshotUrl = $this->login_screenshot_path
            ? Storage::url($this->login_screenshot_path)
            : null;

        return [
            'id' => $this->id,
            'owner_id' => $this->when($canManage, $this->user_id),
            'wallet_account_id' => $this->when($canManage, $this->wallet_account_id),
            'name' => $this->name,
            'slug' => $this->slug,
            'status' => $this->status?->value,
            'reference_code' => $this->when($canManage, $this->reference_code),
            'location' => [
                'latitude' => $this->latitude,
                'longitude' => $this->longitude,
            ],
            'coverage_radius_km' => $this->coverage_radius_km,
            'address' => $this->address,
            'icon_url' => $iconUrl,
            'login_screenshot_url' => $loginScreenshotUrl,
            'icon_path' => $this->when($canManage, $this->icon_path),
            'login_screenshot_path' => $this->when($canManage, $this->login_screenshot_path),
            'description' => $this->description,
            'notes' => $this->when($canManage, $this->notes),
            'plan_count' => $this->plan_count ?? $this->plans_count ?? null,
            'currencies' => $this->currencies,
            'contacts' => $this->contacts,
            'meta' => $this->meta,
            'settings' => $this->when($canManage, $this->settings),
            'statistics' => $this->when(isset($this->statistics), $this->statistics),
            'created_at' => $this->when($this->created_at, fn () => $this->created_at->toIso8601String()),
            'updated_at' => $this->when($this->updated_at, fn () => $this->updated_at->toIso8601String()),
            'plans' => WifiPlanResource::collection($this->whenLoaded('plans')),
        ];
    }
}
