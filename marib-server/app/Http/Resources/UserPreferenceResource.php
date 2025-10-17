<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\UserPreference */
class UserPreferenceResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'favorite_governorate_code' => $this->favoriteGovernorate?->code,
            'favorite_governorate_name' => $this->favoriteGovernorate?->name,
            'currency_watchlist' => collect($this->currency_watchlist ?? [])->map(static fn ($id) => (int) $id)->values()->all(),
            'metal_watchlist' => collect($this->metal_watchlist ?? [])->map(static fn ($id) => (int) $id)->values()->all(),
            'notification_frequency' => $this->notification_frequency,

            'currency_notification_regions' => collect($this->currency_notification_regions ?? [])
                ->mapWithKeys(static function ($code, $currencyId) {
                    $id = (int) $currencyId;
                    $normalizedCode = is_string($code) ? trim($code) : '';

                    if ($id <= 0 || $normalizedCode === '') {
                        return [];
                    }

                    return [$id => $normalizedCode];
                })
                ->all(),

        ];
    }
}