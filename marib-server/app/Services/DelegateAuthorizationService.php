<?php

namespace App\Services;

use App\Models\Setting;
use App\Models\User;

class DelegateAuthorizationService
{
    public const ADMIN_ROLES = ['Super Admin', 'Admin'];

    public function getDelegatesForSection(string $section): array
    {
        $value = CachingService::getSystemSettings($this->getDelegatesSettingKey($section));

        if (empty($value)) {
            return [];
        }

        if (is_string($value)) {
            $decoded = json_decode($value, true);
        } elseif (is_array($value)) {
            $decoded = $value;
        } else {
            $decoded = [];
        }

        if (!is_array($decoded)) {
            return [];
        }

        return collect($decoded)
            ->filter(static fn($id) => is_numeric($id))
            ->map(static fn($id) => (int) $id)
            ->unique()
            ->values()
            ->toArray();
    }

    public function storeDelegatesForSection(string $section, array $delegateIds): void
    {
        Setting::updateOrCreate(
            ['name' => $this->getDelegatesSettingKey($section)],
            [
                'value' => json_encode(array_values($delegateIds)),
                'type'  => 'json',
            ]
        );

        CachingService::removeCache(config('constants.CACHE.SETTINGS'));
    }

    public function userCanManageSection(User $user, string $section): bool
    {
        if ($user->hasAnyRole(self::ADMIN_ROLES)) {
            return true;
        }

        $delegates = $this->getDelegatesForSection($section);

        if (empty($delegates)) {
            return false;
        }

        return in_array($user->id, $delegates, true);
    }

    protected function getDelegatesSettingKey(string $section): string
    {
        return sprintf('delegates_%s', $section);
    }
}