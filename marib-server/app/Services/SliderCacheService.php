<?php

namespace App\Services;

use Closure;
use Illuminate\Support\Facades\Cache;

class SliderCacheService
{
    private const CACHE_TAG = 'slider:eligible';
    private const CACHE_KEY_PREFIX = 'slider:eligible';

    /**
     * @param array<int, string> $interfaceTypes
     * @return mixed
     */
    public static function rememberEligible(
        array $interfaceTypes,
        ?string $userIdentifier,
        ?string $sessionIdentifier,
        int $ttlSeconds,
        Closure $callback
    ) {

        $cacheKey = self::buildCacheKey($interfaceTypes, $userIdentifier, $sessionIdentifier);
        $expiry = now()->addSeconds(max($ttlSeconds, 1));

        return Cache::store('redis')
            ->tags([self::CACHE_TAG])
            ->remember($cacheKey, $expiry, $callback);
    }

    public static function flushEligible(): void
    {
        Cache::store('redis')->tags([self::CACHE_TAG])->flush();
    }

    /**
     * @param array<int, string> $interfaceTypes
     */
    public static function buildCacheKey(
        array $interfaceTypes,
        ?string $userIdentifier,
        ?string $sessionIdentifier
    ): string {

        
        $normalizedInterfaces = array_map(
            static fn (string $interfaceType) => self::normalizePart($interfaceType, 'all'),
            $interfaceTypes
        );

        if ($normalizedInterfaces === []) {
            $normalizedInterfaces = ['all'];
        }

        $interfacesKey = implode('.', $normalizedInterfaces);
        $userKey = self::normalizePart($userIdentifier, 'guest');
        $sessionKey = self::normalizePart($sessionIdentifier, 'none');

        return sprintf(
            '%s:interfaces:%s:user:%s:session:%s',
            self::CACHE_KEY_PREFIX,
            $interfacesKey,
            $userKey,
            $sessionKey
        );
    }

    private static function normalizePart(?string $value, string $fallback): string
    {
        $value = $value ?? $fallback;
        $value = trim($value);

        if ($value === '') {
            $value = $fallback;
        }

        $normalized = preg_replace('/[^A-Za-z0-9:_-]/', '_', $value);

        if ($normalized === '' || $normalized === null) {
            return $fallback;
        }

        return $normalized;
    }
}

