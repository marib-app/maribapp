<?php

namespace App\Services\Pricing;

use App\Models\Pricing\PricingPolicy;
use Illuminate\Support\Facades\Cache;

class ActivePricingPolicyCache
{
    private const CACHE_PREFIX = 'pricing_policy_active:';
    private const CACHE_TTL_MINUTES = 15;

    public static function get(?string $department, ?int $vendorId = null): ?PricingPolicy
    {
        if ($vendorId !== null) {
            $vendorPolicy = Cache::remember(
                self::cacheKey($department, $vendorId),
                now()->addMinutes(self::CACHE_TTL_MINUTES),
                fn () => self::queryActivePolicyForVendor($vendorId, $department)
            );

            if ($vendorPolicy instanceof PricingPolicy) {
                return $vendorPolicy;
            }

            Cache::forget(self::cacheKey($department, $vendorId));
        }

        return self::getForDepartment($department);
    }

    public static function forget(?string $department = null, ?int $vendorId = null): void
    {
        Cache::forget(self::cacheKey($department, $vendorId));
    }

    private static function cacheKey(?string $department, ?int $vendorId = null): string
    {
        if ($vendorId !== null) {
            return self::CACHE_PREFIX . 'vendor:' . $vendorId . ':' . ($department ?? 'global');
        }

        return self::CACHE_PREFIX . ($department ?? 'global');
    }

    private static function getForDepartment(?string $department): ?PricingPolicy
    
    {
        if ($department === null) {
            return Cache::remember(
                self::cacheKey(null),
                now()->addMinutes(self::CACHE_TTL_MINUTES),
                fn () => self::queryActivePolicy(null)
            );
        }

        $policy = Cache::remember(
            self::cacheKey($department),
            now()->addMinutes(self::CACHE_TTL_MINUTES),
            fn () => self::queryActivePolicy($department)
        );

        if ($policy === null) {
            Cache::forget(self::cacheKey($department));

            return self::get(null);
        }

        return $policy;
    }



    private static function queryActivePolicy(?string $department): ?PricingPolicy
    {
        return PricingPolicy::query()
            ->active()
            ->forDepartment($department)
            ->with([
                'weightTiers' => function ($tierQuery) {
                    $tierQuery->active()
                        ->orderBy('sort_order')


                        ->orderBy('min_weight')
                        ->orderBy('id')
                        ->with([
                            'distanceRules' => function ($ruleQuery) {
                                $ruleQuery->active()

                                    ->orderBy('sort_order')


                                    ->orderBy('min_distance')
                                    ->orderBy('id');
                            },
                        ]);
                },
            ])
            ->first();
    }



    private static function queryActivePolicyForVendor(int $vendorId, ?string $department): ?PricingPolicy
    {
        $query = PricingPolicy::query()
            ->active()
            ->where('vendor_id', $vendorId)
            ->with([
                'weightTiers' => function ($tierQuery) {
                    $tierQuery->active()
                        ->orderBy('sort_order')
                        ->orderBy('min_weight')
                        ->orderBy('id')
                        ->with([
                            'distanceRules' => function ($ruleQuery) {
                                $ruleQuery->active()
                                    ->orderBy('sort_order')
                                    ->orderBy('min_distance')
                                    ->orderBy('id');
                            },
                        ]);
                },
            ]);

        if ($department === null) {
            $query->whereNull('department');
        } else {
            $query->where(function ($departmentQuery) use ($department) {
                $departmentQuery->where('department', $department)
                    ->orWhereNull('department');
            });
        }

        if ($department !== null) {
            $query->orderByRaw('CASE WHEN department = ? THEN 0 ELSE 1 END', [$department]);
        }

        return $query
            ->orderByDesc('is_default')
            ->orderBy('id')
            ->first();
    }

}