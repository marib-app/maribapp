<?php

namespace App\Services;

use App\Models\DepartmentDelegate;
use Illuminate\Support\Arr;
use App\Models\User;
use App\Models\UserFcmToken;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;


class DelegateAuthorizationService
{

    public function getDelegatesForSection(string $section): array
    {
        if ($section === '') {

            return [];
        }

        return Cache::remember(
            $this->cacheKeyForSection($section),
            now()->addSeconds($this->cacheTtl()),
            static function () use ($section) {
                return DepartmentDelegate::query()
                    ->where('department', $section)
                    ->pluck('user_id')
                    ->map(static fn ($id) => (int) $id)
                    ->unique()
                    ->values()
                    ->all();
            }
        );
    }


    public function getDelegateNotificationTokensForSection(string $section): array
    {
        $delegateIds = $this->getDelegatesForSection($section);

        if ($delegateIds === []) {
            return [];
        }

        return UserFcmToken::query()
            ->whereIn('user_id', $delegateIds)
            ->pluck('fcm_token')
            ->filter()
            ->unique()
            ->values()
            ->all();
    }


    public function getSectionState(string $section): array
    {
        if ($section === '') {
            return [
                'ids'     => [],
                'version' => '0',
            ];
        }

        $records = DepartmentDelegate::query()
            ->select(['user_id', 'updated_at', 'created_at'])
            ->where('department', $section)
            ->get();

        if ($records->isEmpty()) {
            return [
                'ids'     => [],
                'version' => '0',
            ];
        }

        $ids = $records
            ->pluck('user_id')
            ->map(static fn ($id) => (int) $id)
            ->unique()
            ->values()
            ->all();

        $latest = $records
            ->map(static function ($record) {
                return $record->updated_at ?? $record->created_at;
            })
            ->filter(static fn ($value) => $value !== null)
            ->map(static fn ($value) => $value instanceof Carbon ? $value : Carbon::parse($value))
            ->sortDesc()
            ->first();

        return [
            'ids'     => $ids,
            'version' => $latest instanceof Carbon ? (string) $latest->valueOf() : '0',
        ];
    }


    public function storeDelegatesForSection(string $section, array $delegateIds): void
    {
        $ids = collect($delegateIds)
            ->filter(static fn ($id) => is_numeric($id))
            ->map(static fn ($id) => (int) $id)
            ->unique()
            ->values();

        DB::transaction(function () use ($section, $ids) {
            if ($ids->isEmpty()) {
                DepartmentDelegate::query()
                    ->where('department', $section)
                    ->delete();

                return;
            }

            DepartmentDelegate::query()
                ->where('department', $section)
                ->whereNotIn('user_id', $ids)
                ->delete();

            $timestamp = now();

            DepartmentDelegate::query()->upsert(
                $ids->map(static fn ($id) => [
                    'department' => $section,
                    'user_id' => $id,
                    'created_at' => $timestamp,
                    'updated_at' => $timestamp,
                ])->all(),
                ['department', 'user_id'],
                ['updated_at']
            );
        });

        $this->forgetSectionCache($section);
    }

    public function userCanManageSection(User $user, ?string $section): bool

    {

        if ($section === null) {
            return true;
        }

        if (! $this->isSectionRestricted($section)) {
            return true;
        }

        if ($user->hasAnyRole($this->adminRoles())) {
            return true;
        }

        $delegates = $this->getDelegatesForSection($section);

        if ($delegates === []) {

            return false;
        }

        return in_array($user->getKey(), $delegates, true);

    }



    public function getRestrictedDepartments(): array
    {
        return $this->restrictedDepartments();
    }

    public function getSectionAccessForUser(User $user): array
    {
        $restricted = $this->getRestrictedDepartments();

        if ($restricted === []) {
            return [
                'permitted' => [],
                'blocked' => [],
            ];
        }

        $permitted = [];
        $blocked = [];

        foreach ($restricted as $department) {
            if ($this->userCanManageSection($user, $department)) {
                $permitted[] = $department;

                continue;
            }

            $blocked[] = $department;
        }

        return [
            'permitted' => $permitted,
            'blocked' => $blocked,
        ];
    }





    protected function restrictedDepartments(): array
    {
        return array_values(array_filter(
            Arr::wrap(config('delegates.restricted_departments', [])),
            static fn ($section) => is_string($section) && $section !== ''
        ));
    }

    protected function adminRoles(): array
    {
        return array_values(array_filter(
            Arr::wrap(config('delegates.admin_roles', [])),
            static fn ($role) => is_string($role) && $role !== ''
        ));
    }

    protected function cacheKeyForSection(string $section): string
    {
        $prefix = (string) config('delegates.cache_prefix', 'delegates');

        return sprintf('%s:%s', $prefix, $section);
    }

    protected function cacheTtl(): int
    {
        $ttl = (int) config('delegates.cache_ttl', 120);

        return $ttl > 0 ? $ttl : 120;
    }



    public function isSectionRestricted(?string $section): bool
    {
        if ($section === null) {
            return false;
        }

        return in_array($section, $this->restrictedDepartments(), true);

    }



    protected function forgetSectionCache(string $section): void

    {
        Cache::forget($this->cacheKeyForSection($section));
    }
}