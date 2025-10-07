<?php

namespace Database\Seeders;

use App\Models\FeatureSection;
use App\Services\FeatureSectionCategoryService;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;

class FeatureSectionActivationSeeder extends Seeder
{
    private const DEFAULT_FILTER_SEQUENCE = [
        'latest',
        'most_viewed',
    ];

    private const DEFAULT_TITLES = [
        'latest' => 'Latest Items',
        'most_viewed' => 'Most Viewed Items',
    ];

    public function run(): void
    {
        DB::transaction(function (): void {
            $this->sanitizeExistingSections();
            $this->ensureRequiredSections();
            $this->resequenceSections();
        });

        Cache::flush();
    }

    private function sanitizeExistingSections(): void
    {
        $allowedSectionTypes = FeatureSectionCategoryService::allowedSectionTypes(includeLegacy: true);
        $canonicalSectionTypes = FeatureSectionCategoryService::allowedSectionTypes();
        $now = now();
        $supportedFilters = $this->supportedFilters();

        $sections = FeatureSection::select('id', 'slug', 'title', 'section_type', 'filter', 'value')
            ->orderBy('id')
            ->get();

        if ($sections->isEmpty()) {
            return;
        }

        $seen = [];

        $updates = [];

        $deletions = [];

        foreach ($sections as $section) {
            $filter = strtolower((string) $section->filter);

            if ($filter === '' || ! in_array($filter, $supportedFilters, true)) {
                $deletions[] = $section->id;
                continue;
            }

            $normalizedSectionType = FeatureSectionCategoryService::normalizeSectionType($section->section_type);

            if (! in_array($normalizedSectionType, $allowedSectionTypes, true)) {
                $deletions[] = $section->id;
                continue;
            }

            if (! in_array($normalizedSectionType, $canonicalSectionTypes, true)) {
                // Skip legacy-only section types after normalization.
                $deletions[] = $section->id;
                continue;
            }




            $canonicalSlug = FeatureSection::canonicalSlugForFilter($filter)
                ?? FeatureSection::normalizeSlug($filter);

            if ($canonicalSlug === '') {
                $canonicalSlug = FeatureSection::normalizeSlug($section->title);
            }

            if ($canonicalSlug === '') {
                $canonicalSlug = 'feature_section_' . $section->id;
            }

            if (! FeatureSection::slugMatchesFilter($canonicalSlug, $filter)) {
                $canonicalSlug = FeatureSection::normalizeSlug($filter);
            }

            $uniqueKey = $normalizedSectionType . '|' . $canonicalSlug;

            if (isset($seen[$uniqueKey])) {
                $deletions[] = $section->id;
                continue;
            }

            $seen[$uniqueKey] = true;

            $updates[] = [
                'id' => $section->id,
                'slug' => $canonicalSlug,
                'section_type' => $normalizedSectionType,
                'filter' => $filter,
                'value' => $section->value,

                'is_active' => true,
                'updated_at' => $now,
            ];
        }

        if ($deletions !== []) {
            FeatureSection::whereIn('id', $deletions)->delete();
        }
        if ($updates !== []) {
            FeatureSection::upsert(
                $updates,
                ['id'],
                ['slug', 'section_type', 'filter', 'value', 'is_active', 'updated_at']
            );
        }
    }

    private function ensureRequiredSections(): void
    {
        $allowedSectionTypes = FeatureSectionCategoryService::allowedSectionTypes();
        $sequenceFilters = $this->requiredFilters();

        foreach ($allowedSectionTypes as $sectionType) {
            $existing = FeatureSection::select('id', 'filter')
                ->where('section_type', $sectionType)
                ->get()
                ->keyBy('filter');

            foreach ($sequenceFilters as $index => $filter) {
                if ($existing->has($filter)) {
                    continue;
                }

                $slug = FeatureSection::canonicalSlugForFilter($filter)
                    ?? FeatureSection::normalizeSlug($filter);

                $title = self::DEFAULT_TITLES[$filter] ?? ucwords(str_replace('_', ' ', $filter));

                FeatureSection::create([
                    'title' => $title,
                    'slug' => $slug,
                    'sequence' => $index + 1,
                    'filter' => $filter,
                    'value' => null,
                    'style' => 'style_1',
                    'section_type' => $sectionType,

                    'description' => null,
                    'is_active' => true,
                ]);
            }
        }
    }

    private function resequenceSections(): void
    {
        $allowedSectionTypes = FeatureSectionCategoryService::allowedSectionTypes();
        $orderMap = [];
        $sequenceFilters = $this->requiredFilters();

        foreach ($sequenceFilters as $position => $filter) {
            $orderMap[$filter] = $position;
        }

        $now = now();

        $sections = FeatureSection::select('id', 'section_type', 'filter')
            ->whereIn('section_type', $allowedSectionTypes)
            ->orderBy('section_type')
            ->orderBy('id')
            ->get()
            ->groupBy('section_type');

        foreach ($sections as $sectionType => $group) {
            $sequence = 1;

            $ordered = $group->sortBy(static function (FeatureSection $section) use ($orderMap) {
                return $orderMap[$section->filter] ?? (count($orderMap) + $section->id);
            });

            $updates = [];

            foreach ($ordered as $section) {
                $updates[] = [
                    'id' => $section->id,
                    'sequence' => $sequence++,
                    'is_active' => true,
                    'updated_at' => $now,
                ];
            }

            if ($updates !== []) {
                FeatureSection::upsert($updates, ['id'], ['sequence', 'is_active', 'updated_at']);
            }
        }
    }

    private function supportedFilters(): array
    {
        return FeatureSection::supportedFilters();
    }

    private function requiredFilters(): array
    {
        $supported = $this->supportedFilters();
        $configured = $this->configuredDefaultFilters();

        $filtered = array_values(array_filter(
            array_unique($configured),
            static fn ($filter) => in_array($filter, $supported, true)
        ));

        if ($filtered !== []) {
            return $filtered;
        }

        return array_values(array_filter(
            self::DEFAULT_FILTER_SEQUENCE,
            static fn ($filter) => in_array($filter, $supported, true)
        ));
    }

    /**
     * @return list<string>
     */
    private function configuredDefaultFilters(): array
    {
        $configured = config('feature-section.default_filters');

        if (! is_array($configured)) {
            return self::DEFAULT_FILTER_SEQUENCE;
        }

        $normalized = [];

        foreach ($configured as $filter) {
            $candidate = FeatureSection::normalizeSlug((string) $filter);

            if ($candidate !== '') {
                $normalized[] = $candidate;
            }
        }

        if ($normalized === []) {
            return self::DEFAULT_FILTER_SEQUENCE;
        }

        return $normalized;
    }
}
