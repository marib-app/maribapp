<?php

namespace App\Services;

use App\Models\Language;
use App\Models\Setting;
use Illuminate\Support\Facades\Cache;

class CachingService {

    /**
     * @param $key
     * @param callable $callback - Callback function must return a value
     * @param int $time Seconds to cache the value for (defaults to 3600).
     * @return mixed
     */
    public static function cacheRemember($key, callable $callback, int $time = 3600) {
        $store = self::resolveCacheStore();


        return Cache::store($store)->remember($key, now()->addSeconds($time), $callback);
    }

    public static function removeCache($key) {
        $keys = is_array($key) ? $key : [$key];

        $keys[] = config('constants.CACHE.SETTINGS');

        $cacheStore = Cache::store(self::resolveCacheStore());



        foreach (array_unique($keys) as $cacheKey) {
            $cacheStore->forget($cacheKey);
        }
    
    }

    /**
     * @param array|string $key
     * @return mixed|string
     */
    public static function getSystemSettings(array|string $key = '*') {
        $settings = self::cacheRemember(config('constants.CACHE.SETTINGS'), static function () {
            return Setting::all()->pluck('value', 'name');
        });

        if (($key != '*')) {
            /* There is a minor possibility of getting a specific key from the $systemSettings
             * So I have not fetched Specific key from DB. Otherwise, Specific key will be fetched here
             * And it will be appended to the cached array here
             */
            $specificSettings = [];

            // If array is given in Key param
            if (is_array($key)) {
                foreach ($key as $row) {
                    if ($settings && is_array($settings) && array_key_exists($row, $settings)) {
                        $specificSettings[$row] = $settings[$row] ?? '';
                    }
                }
                return $specificSettings;
            }

            // If String is given in Key param
            if ($settings && is_object($settings) && $settings->has($key)) {
                return $settings[$key] ?? '';
            }

            return "";
        }
        return $settings;
    }

    public static function getLanguages() {
        return self::cacheRemember(config('constants.CACHE.LANGUAGE'), static function () {
            return Language::all();
        });
    }

    public static function getDefaultLanguage() {
        return Language::where('code', 'ar')->first();
    }



    private static function resolveCacheStore(): string {
        $stores = config('cache.stores', []);
        $defaultStore = config('cache.default', 'file');

        if (!array_key_exists($defaultStore, $stores)) {
            $defaultStore = 'file';
        }

        if ($defaultStore === 'redis') {
            return self::redisIsAvailable() ? 'redis' : 'file';
        }

        if (self::redisIsAvailable()) {
            return 'redis';
        }

        return $defaultStore;
    }

    private static function redisIsAvailable(): bool {
        $stores = config('cache.stores', []);

        if (!array_key_exists('redis', $stores)) {
            return false;
        }

        if (($stores['redis']['driver'] ?? null) !== 'redis') {
            return false;
        }

        $client = config('database.redis.client', 'phpredis');

        return match ($client) {
            'phpredis' => class_exists(\Redis::class),
            'predis' => class_exists(\Predis\Client::class),
            default => false,
        };
    }

}
