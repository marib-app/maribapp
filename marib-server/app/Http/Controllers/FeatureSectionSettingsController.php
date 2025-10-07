<?php

namespace App\Http\Controllers;

use App\Models\FeatureSection;
use App\Models\Setting;
use App\Services\CachingService;
use App\Services\FeatureSectionCategoryService;
use App\Services\FeaturedSectionService;
use Illuminate\Contracts\View\View;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\Cache;
use JsonException;

class FeatureSectionSettingsController extends Controller
{
    public function edit(): View
    {
        $defaultTtl = (int) config('feature-section.cache_ttl_seconds', 300);
        $defaultLimit = (int) config('feature-section.section_item_limit', 12);

        $ttlSetting = $this->positiveIntOrNull(CachingService::getSystemSettings('featured_section_cache_ttl'));
        $limitSetting = $this->positiveIntOrNull(CachingService::getSystemSettings('featured_section_default_limit'));

        $effectiveIdentifiers = FeatureSectionCategoryService::rootIdentifiers();
        $overrideIdentifiers = $this->loadRootIdentifierOverrides();

        $formIdentifiers = [];

        foreach ($effectiveIdentifiers as $sectionType => $identifier) {
            $value = $overrideIdentifiers[$sectionType] ?? $identifier;
            $formIdentifiers[$sectionType] = $this->formatIdentifierForInput($value);
        }

        ksort($formIdentifiers);

        return view('feature-section.settings', [
            'cacheTtl' => $ttlSetting ?? $defaultTtl,
            'defaultLimit' => $limitSetting ?? $defaultLimit,
            'defaultTtl' => $defaultTtl,
            'defaultSectionLimit' => $defaultLimit,
            'identifierValues' => $formIdentifiers,
            'identifierOverrides' => $overrideIdentifiers,
        ]);
    }

    public function update(Request $request): RedirectResponse
    {
        $maxLimit = FeaturedSectionService::MAX_SECTION_LIMIT;

        $validated = $request->validate([
            'cache_ttl_seconds' => ['required', 'integer', 'min:1', 'max:86400'],
            'section_item_limit' => ['required', 'integer', 'min:1', 'max:' . $maxLimit],
            'root_identifiers' => ['required', 'array'],
            'root_identifiers.*' => ['nullable', 'string', 'max:255'],
        ]);

        $ttl = (int) Arr::get($validated, 'cache_ttl_seconds', 300);
        $limit = (int) Arr::get($validated, 'section_item_limit', 12);
        $limit = max(1, min($maxLimit, $limit));

        $identifierInputs = Arr::get($validated, 'root_identifiers', []);
        $normalizedIdentifiers = [];

        foreach ($identifierInputs as $sectionType => $value) {
            $normalized = $this->normalizeIdentifierInput($value);
            $normalizedIdentifiers[$sectionType] = $normalized;
        }

        $encodedIdentifiers = $this->encodeIdentifierOverrides($normalizedIdentifiers);

        $this->persistSetting('featured_section_cache_ttl', (string) $ttl, 'string');
        $this->persistSetting('featured_section_default_limit', (string) $limit, 'string');

        $identifierType = $encodedIdentifiers === '' ? 'string' : 'json';
        $this->persistSetting('featured_section_root_identifiers', $encodedIdentifiers, $identifierType);

        config(['feature-section.cache_ttl_seconds' => $ttl]);
        config(['feature-section.section_item_limit' => $limit]);

        CachingService::removeCache(config('constants.CACHE.SETTINGS'));

        return redirect()
            ->route('feature-section.settings.edit')
            ->with('success', __('تم تحديث إعدادات الأقسام المميزة بنجاح.'));
    }

    public function flushCache(): RedirectResponse
    {
        $sections = FeatureSection::query()
            ->select(['slug', 'section_type'])
            ->get();

        $flushed = [];

        foreach ($sections as $section) {
            $normalizedType = FeatureSectionCategoryService::normalizeSectionType($section->section_type);
            $variants = FeatureSectionCategoryService::sectionTypeVariants($normalizedType);

            if (! in_array($normalizedType, $variants, true)) {
                $variants[] = $normalizedType;
            }

            foreach (array_unique($variants) as $variant) {
                $cacheKey = sprintf('featured-section:%s:%s', $variant, FeatureSection::normalizeSlug($section->slug));

                if (Cache::forget($cacheKey)) {
                    $flushed[] = $cacheKey;
                }
            }
        }

        $message = __('تم تفريغ :count مفتاح كاش من الأقسام المميزة.', ['count' => count($flushed)]);

        return redirect()
            ->route('feature-section.settings.edit')
            ->with('success', $message)
            ->with('flushed_keys', $flushed);
    }

    private function positiveIntOrNull(mixed $value): ?int
    {
        if ($value === null) {
            return null;
        }

        if (is_string($value)) {
            $value = trim($value);

            if ($value === '') {
                return null;
            }
        }

        if (! is_numeric($value)) {
            return null;
        }

        $intValue = (int) $value;

        return $intValue > 0 ? $intValue : null;
    }

    private function loadRootIdentifierOverrides(): array
    {
        $raw = CachingService::getSystemSettings('featured_section_root_identifiers');

        if (! is_string($raw) || $raw === '') {
            return [];
        }

        try {
            $decoded = json_decode($raw, true, 512, JSON_THROW_ON_ERROR);
        } catch (JsonException) {
            return [];
        }

        if (! is_array($decoded)) {
            return [];
        }

        return $decoded;
    }

    private function formatIdentifierForInput(mixed $value): string
    {
        if ($value === null) {
            return '';
        }

        if (is_array($value)) {
            return implode(', ', array_map(static function ($item) {
                if (is_string($item)) {
                    return $item;
                }

                if (is_numeric($item)) {
                    return (string) $item;
                }

                return (string) json_encode($item, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
            }, $value));
        }

        if (is_string($value)) {
            return $value;
        }

        if (is_numeric($value)) {
            return (string) ((int) $value);
        }

        return (string) $value;
    }

    private function normalizeIdentifierInput(?string $value): mixed
    {
        if ($value === null) {
            return null;
        }

        $trimmed = trim($value);

        if ($trimmed === '' || strtolower($trimmed) === 'null') {
            return null;
        }

        if (str_contains($trimmed, ',')) {
            $parts = array_map(static fn ($part) => trim($part), explode(',', $trimmed));

            $normalized = [];

            foreach ($parts as $part) {
                if ($part === '') {
                    continue;
                }

                if (is_numeric($part)) {
                    $intValue = (int) $part;

                    if ($intValue > 0) {
                        $normalized[] = $intValue;
                    }

                    continue;
                }

                $normalized[] = $part;
            }

            return array_values(array_unique($normalized, SORT_REGULAR));
        }

        if (is_numeric($trimmed)) {
            $intValue = (int) $trimmed;

            return $intValue > 0 ? $intValue : null;
        }

        return $trimmed;
    }

    private function encodeIdentifierOverrides(array $identifiers): string
    {
        $normalized = [];

        foreach ($identifiers as $key => $value) {
            if ($value === null || $value === '' || $value === []) {
                continue;
            }

            $normalized[$key] = $value;
        }

        if ($normalized === []) {
            return '';
        }

        ksort($normalized);

        return json_encode($normalized, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    }

    private function persistSetting(string $key, string $value, string $type): void
    {
        Setting::query()->updateOrCreate(
            ['name' => $key],
            ['value' => $value, 'type' => $type]
        );
    }
}