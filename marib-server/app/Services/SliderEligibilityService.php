<?php

namespace App\Services;

use App\Models\Slider;
use Carbon\Carbon;
use Illuminate\Contracts\Cache\Repository as CacheRepository;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Config;
use Illuminate\Support\Collection;
use App\Services\SliderDefaultService;

class SliderEligibilityService
{
    protected CacheRepository $cache;
    protected SliderMetricService $metrics;
    protected SliderDefaultService $sliderDefaults;

    public function __construct(?CacheRepository $cache = null, ?SliderMetricService $metrics = null, ?SliderDefaultService $sliderDefaults = null)
    
    {
        $this->cache = $cache ?? Cache::driver();
        $this->metrics = $metrics ?? app(SliderMetricService::class);
        $this->sliderDefaults = $sliderDefaults ?? app(SliderDefaultService::class);


    }

    public function eligibleSliders(Collection $sliders, ?int $userId, ?string $sessionId, ?Carbon $moment = null): Collection
    {
        $moment ??= Carbon::now();

        return $sliders
            ->filter(function (Slider $slider) use ($moment, $userId, $sessionId) {
                if (! $slider->isEligible($moment)) {
                    return false;
                }

                return ! $this->hasReachedFrequencyCap($slider, $userId, $sessionId, $moment);
            })
            ->sortByDesc(fn (Slider $slider) => $slider->priority)
            ->values();
    }

    public function selectSlider(Collection $sliders, ?int $userId, ?string $sessionId, ?Carbon $moment = null): ?Slider
    {
        $moment ??= Carbon::now();

        $eligible = $this->eligibleSliders($sliders, $userId, $sessionId, $moment);



        if ($eligible->isEmpty()) {
            return null;
        }


        $weights = $eligible->mapWithKeys(function (Slider $slider) {
            $weight = $slider->share_of_voice > 0
                ? max(0.0, (float) $slider->share_of_voice)
                : max(1, (int) $slider->weight);

            return [$slider->getKey() => $weight];
        });

        $total = $weights->sum();

        $selected = null;


        if ($total > 0) {
            $random = (mt_rand() / mt_getrandmax()) * $total;
            $accumulator = 0.0;

            foreach ($eligible as $slider) {
                $accumulator += $weights[$slider->getKey()] ?? 0.0;

                if ($random <= $accumulator) {
                    $selected = $slider;
                    break;
                }
            }
        }

        $selected ??= $eligible->first();

        if ($selected instanceof Slider) {
            $this->recordImpression($selected, $userId, $sessionId, $moment);
        }

        return $selected;
    }

    public function selectEligibleSliders(Collection $sliders, ?int $userId, ?string $sessionId, ?Carbon $moment = null): Collection
    {
        $moment ??= Carbon::now();

        $eligible = $this->eligibleSliders($sliders, $userId, $sessionId, $moment)
            ->sortByDesc(fn (Slider $slider) => $slider->priority)
            ->values();
            
        foreach ($eligible as $slider) {
            $this->recordImpression($slider, $userId, $sessionId, $moment);
        }

        return $eligible;
    }


    public function recordImpression(Slider $slider, ?int $userId, ?string $sessionId, ?Carbon $moment = null): void
    {
        $moment ??= Carbon::now();

        if ($userId && $slider->per_user_per_day_limit) {
            $dailyKey = $this->dailyCacheKey($slider, $userId, $moment);
            $count = $this->cache->get($dailyKey, 0) + 1;
            $this->cache->put($dailyKey, $count, $moment->copy()->endOfDay());
        }

        if ($sessionId && $slider->per_user_per_session_limit) {
            $sessionKey = $this->sessionCacheKey($slider, $sessionId);
            $count = $this->cache->get($sessionKey, 0) + 1;
            $ttl = $moment->copy()->addMinutes((int) Config::get('session.lifetime', 120));
            $this->cache->put($sessionKey, $count, $ttl);
        }
        $this->metrics->recordImpression($slider, $userId, $sessionId, $moment);


    }

    public function hasReachedFrequencyCap(Slider $slider, ?int $userId, ?string $sessionId, ?Carbon $moment = null): bool
    {
        $moment ??= Carbon::now();

        if ($userId && $slider->per_user_per_day_limit) {
            $dailyKey = $this->dailyCacheKey($slider, $userId, $moment);
            $count = (int) $this->cache->get($dailyKey, 0);

            if ($count >= $slider->per_user_per_day_limit) {
                return true;
            }
        }

        if ($sessionId && $slider->per_user_per_session_limit) {
            $sessionKey = $this->sessionCacheKey($slider, $sessionId);
            $count = (int) $this->cache->get($sessionKey, 0);

            if ($count >= $slider->per_user_per_session_limit) {
                return true;
            }
        }

        return false;
    }

    public function fallbackPayload(?string $interfaceType = null): array
    {

        $defaultImage = $this->sliderDefaults->findActiveForInterface($interfaceType);

        if ($defaultImage) {
            return [
                'fallback' => true,
                'display'  => 'image',
                'image'    => $defaultImage->image_url,
            ];
        }

        return [
            'fallback' => true,
            'display'  => 'shimmer',
            'image'    => asset('images/app_styles/style_1.png'),
        ];
    }

    protected function dailyCacheKey(Slider $slider, int $userId, Carbon $moment): string
    {
        return sprintf('slider:%s:user:%s:%s', $slider->getKey(), $userId, $moment->toDateString());
    }

    protected function sessionCacheKey(Slider $slider, string $sessionId): string
    {
        return sprintf('slider:%s:session:%s', $slider->getKey(), sha1($sessionId));
    }
}