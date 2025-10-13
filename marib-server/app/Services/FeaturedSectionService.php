<?php

namespace App\Services;

use App\Exceptions\UnknownFeaturedSectionSlugException;
use App\Http\Resources\ItemCollection;
use App\Models\FeatureSection;
use App\Models\Item;
use Carbon\Carbon;
use Illuminate\Contracts\Cache\Repository as CacheRepository;
use Illuminate\Database\Eloquent\Collection as EloquentCollection;
use Illuminate\Support\Facades\Auth;
use Illuminate\Http\Resources\Json\JsonResource;
use App\Services\CachingService;
use App\Services\FeatureSectionCategoryService;
use App\Support\FeaturedSectionQueryHelper;
class FeaturedSectionService
{
    public const MAX_SECTION_LIMIT = 100;

    private ?int $resolvedCacheTtl = null;
    private ?int $resolvedDefaultLimit = null;
    public function __construct(private readonly CacheRepository $cache)
    {
    }

    public function previewSection(
        FeatureSection $section,
        array $options = []
    ): SectionPayloadResult {
        $sectionType = FeatureSectionCategoryService::normalizeSectionType($section->section_type);
        $rootIdentifiers = FeatureSectionCategoryService::rootIdentifiers();
        $configuredRootIdentifier = $rootIdentifiers[$sectionType] ?? null;
        $limit = (int) ($options['limit'] ?? 0);
        if ($limit <= 0) {
            $limit = $this->defaultSectionLimit();
        }

        if ($limit > self::MAX_SECTION_LIMIT) {
            $limit = self::MAX_SECTION_LIMIT;
        }


        $result = $this->buildSectionPayload(
            $section,
            $sectionType,
            $limit,
            $configuredRootIdentifier,

        );

        if ($result->section['section_data'] instanceof JsonResource) {
            $result->section['section_data'] = $result->section['section_data']->resolve();
        }

        return $result;
    }


    public function getSections(
        ?string $sectionType,
        ?string $interfaceType,
        ?string $slug,
        ?int $limit,
        ?string $rootIdentifier,
    ): FeaturedSectionServiceResult


    {
        $sectionTypeInput = $sectionType ?? $interfaceType;
        $hasSectionTypeFilter = $sectionType !== null || $interfaceType !== null;

        $allowedSectionTypes = FeatureSectionCategoryService::allowedSectionTypes(includeLegacy: true);
        $canonicalSectionTypes = FeatureSectionCategoryService::allowedSectionTypes();
        $defaultSectionType = FeatureSectionCategoryService::defaultSectionType() ?? ($canonicalSectionTypes[0] ?? '');



        $normalizedSectionType = $hasSectionTypeFilter
            ? FeatureSectionCategoryService::normalizeSectionType($sectionTypeInput)
            : $defaultSectionType;

        if (
            $normalizedSectionType !== 'all'
            && ! in_array($normalizedSectionType, $allowedSectionTypes, true)
        ) {
            
            $normalizedSectionType = $defaultSectionType;
        }

        $slugInput = $slug;

        $normalizedSlug = $slugInput !== null ? FeatureSection::normalizeSlug($slugInput) : null;

        $featureSectionQuery = FeatureSection::query()
            ->active()
            ->orderBy('sequence', 'asc');

        if ($normalizedSlug !== null) {
            $featureSectionQuery->where('slug', $normalizedSlug);
        }

        if (
            $normalizedSectionType !== null
            && $normalizedSectionType !== 'all'
            && in_array($normalizedSectionType, $canonicalSectionTypes, true)
        ) {

            $variants = FeatureSectionCategoryService::sectionTypeVariants($normalizedSectionType);
            $featureSectionQuery->whereIn('section_type', $variants);
        } else {
            $expanded = FeatureSectionCategoryService::expandSectionTypes($allowedSectionTypes);
            if ($expanded !== []) {
                $featureSectionQuery->whereIn('section_type', $expanded);
            }
        }

        /** @var EloquentCollection<int, FeatureSection> $sections */
        $sections = $featureSectionQuery->get();

        if ($normalizedSlug !== null && $sections->isEmpty()) {
            throw new UnknownFeaturedSectionSlugException($normalizedSlug);
        }

        $limit = (int) ($limit ?? 0);
        $limit = $limit > 0 ? $limit : $this->defaultSectionLimit();


        if ($limit > self::MAX_SECTION_LIMIT) {
            $limit = self::MAX_SECTION_LIMIT;
        }


        $sectionsPayload = [];
        $sectionEtags = [];


        $requestedRootTokens = $this->normalizeRootIdentifierFilter($rootIdentifier);
        $rootIdentifiers = FeatureSectionCategoryService::rootIdentifiers();
        $stringifiedRootFilter = $this->stringifyRootIdentifier($rootIdentifier);


        foreach ($sections as $section) {
            if ($normalizedSlug !== null && ! FeatureSection::slugMatchesFilter($normalizedSlug, $section->filter)) {
                throw new UnknownFeaturedSectionSlugException($normalizedSlug);
            }

            $sectionType = FeatureSectionCategoryService::normalizeSectionType($section->section_type);
            $configuredRootIdentifier = $rootIdentifiers[$sectionType] ?? null;
            $sectionRootTokens = $this->sectionRootIdentifierTokens($sectionType, $configuredRootIdentifier);

            if (! $this->matchesRootIdentifier($requestedRootTokens, $sectionRootTokens)) {
                continue;
            }

            $built = $this->buildSectionPayload(
                $section,
                $sectionType,
                $limit,
                $configuredRootIdentifier,

            );

            $sectionsPayload[] = $built->section;
            $sectionEtags[] = $built->etag;
        }


        $etagSummary = [
            'section_type' => $normalizedSectionType,
            'slug' => $normalizedSlug,
            'limit' => $limit,

            'sections' => $sectionEtags,
            'root_identifier' => $stringifiedRootFilter,


        ];

        if ($sectionsPayload === []) {
            $etagSummary['empty'] = true;

        }
        $combinedEtag = $this->hashForSummary($etagSummary);
        $cacheTtl = $this->cacheTtlSeconds();

        return new FeaturedSectionServiceResult(
            sections: $sectionsPayload,
            etag: $combinedEtag,
            cacheControl: sprintf('public, max-age=%d', $cacheTtl),
            ttl: $cacheTtl,
        );
    }

    private function buildSectionPayload(
        FeatureSection $section,
        string $canonicalSectionType,
        int $limit,
        mixed $configuredRootIdentifier,

    ): SectionPayloadResult {

        $itemsQuery = Item::query()
            ->select('items.*')
            ->with([
                'user:id,name,email,mobile,profile,is_verified,show_personal_details,country_code',
                'category:id,name,image',
                'gallery_images:id,image,item_id,thumbnail_url,detail_image_url',
                'featured_items',
                'favourites',
                'item_custom_field_values.custom_field',
            ])
            ->withCount('favourites')
            ->withAvg('review as ratings_avg', 'ratings')
            ->withCount('review as ratings_count')
            ->has('user')
            ->approved()
            ->getNonExpiredItems();



        $queryState = FeaturedSectionQueryHelper::configureQuery(
            $itemsQuery,
            $section,
            $canonicalSectionType
        );

        $filter = $queryState->filter;
        $priceColumn = $queryState->priceColumn;
        $priceColumnName = $queryState->priceColumnQualified;
        $minPrice = $queryState->minPrice;
        $maxPrice = $queryState->maxPrice;

        if (Auth::check()) {
            $itemsQuery->with([
                'item_offers' => static function ($query) {
                    $query->where('buyer_id', Auth::id());
                },
                'user_reports' => static function ($query) {
                    $query->where('user_id', Auth::id());
                },
            ]);
        }

        $items = $itemsQuery->limit($limit)->get();

        $sectionSummary = [
            'section_id' => $section->id,
            'section_updated_at' => optional($section->updated_at)->toDateTimeString(),
            'filter' => $filter,
            'items' => $items->map(fn(Item $item) => [
                'id' => $item->id,
                'updated_at' => optional($item->updated_at)->toDateTimeString(),
                'clicks' => $item->clicks,
                'price' => $item->getAttribute($priceColumn),
                'ratings_avg' => $item->ratings_avg,
                'ratings_count' => $item->ratings_count,
            ])->toArray(),
        ];

        $sectionEtag = $this->hashForSummary($sectionSummary);
        $cacheKey = $this->cacheKey($canonicalSectionType, $section->slug);
        $this->cache->put($cacheKey, [
            'etag' => $sectionEtag,
            'summary' => $sectionSummary,
        ], Carbon::now()->addSeconds($this->cacheTtlSeconds()));

        $sectionPayload = $section->toArray();
        $sectionPayload['section_type'] = $canonicalSectionType;
        $sectionPayload['root_identifier'] = $this->stringifyRootIdentifier(
            $configuredRootIdentifier
        ) ?? $canonicalSectionType;

        $sectionPayload['root_identifier'] = $this->stringifyRootIdentifier(
            FeatureSectionCategoryService::rootIdentifiers()[$canonicalSectionType] ?? null
        ) ?? $canonicalSectionType;
        $sectionPayload['min_price'] = $minPrice;
        $sectionPayload['max_price'] = $maxPrice;
        $sectionPayload['total_data'] = $items->count();
        $sectionPayload['section_data'] = $items->count() > 0
            ? new ItemCollection($items)
            : [];



        return new SectionPayloadResult($sectionPayload, $sectionEtag);
    }




    private function hashForSummary(array $summary): string
    {
        return sha1(json_encode($summary, JSON_THROW_ON_ERROR));
    }

    private function cacheKey(string $sectionType, string $slug): string
    {
        return sprintf('featured-section:%s:%s', $sectionType, $slug);
    }



    private function cacheTtlSeconds(): int
    {
        if ($this->resolvedCacheTtl !== null) {
            return $this->resolvedCacheTtl;
        }

        $fallback = (int) config('feature-section.cache_ttl_seconds', 300);
        $configured = CachingService::getSystemSettings('featured_section_cache_ttl');
        $ttl = $this->positiveIntOrNull($configured);

        if ($ttl === null) {
            $ttl = $fallback;
        }

        $ttl = max(1, $ttl);

        $this->resolvedCacheTtl = $ttl;

        return $this->resolvedCacheTtl;
    }

    private function defaultSectionLimit(): int
    {
        if ($this->resolvedDefaultLimit !== null) {
            return $this->resolvedDefaultLimit;
        }

        $fallback = (int) config('feature-section.section_item_limit', 12);
        $configured = CachingService::getSystemSettings('featured_section_default_limit');
        $limit = $this->positiveIntOrNull($configured);

        if ($limit === null) {
            $limit = $fallback;
        }

        $limit = max(1, min(self::MAX_SECTION_LIMIT, $limit));

        $this->resolvedDefaultLimit = $limit;

        return $this->resolvedDefaultLimit;
    }



    /**
     * @return array<int, string>
     */
    private function normalizeRootIdentifierFilter(?string $value): array
    {
        $tokens = $this->tokenizeRootIdentifierValue($value);
        $canonicalTokens = [];

        foreach ($tokens as $token) {
            $canonical = FeatureSectionCategoryService::canonicalSectionTypeOrNull($token);

            if ($canonical !== null) {
                $canonicalTokens[] = $canonical;

            }
        }

        return $this->normalizeTokens(array_merge($tokens, $canonicalTokens));
    }

    /**
     * @return array<int, string>
     */
    private function sectionRootIdentifierTokens(string $canonicalSectionType, mixed $configuredRootIdentifier): array
    {
        $tokens = $this->tokenizeRootIdentifierValue($configuredRootIdentifier);
        $tokens[] = $canonicalSectionType;

        $canonicalAlias = FeatureSectionCategoryService::canonicalSectionTypeOrNull($canonicalSectionType);

        if ($canonicalAlias !== null) {
            $tokens[] = $canonicalAlias;
        }

        return $this->normalizeTokens($tokens);
    }

    /**
     * @return array<int, string>
     */
    private function tokenizeRootIdentifierValue(mixed $value): array
    {
        if ($value === null) {
            return [];
        }

        if (is_string($value)) {
            $value = trim($value);

            if ($value === '') {
                return [];
            }

            $parts = preg_split('/[\s,]+/', $value) ?: [$value];
            $tokens = [];

            foreach ($parts as $part) {
                $part = trim($part);

                if ($part === '') {
                    continue;
                }

                $tokens[] = $part;
            }

            return $tokens;
        }

        if (is_int($value) || is_float($value) || is_numeric($value)) {
            return [(string) (int) $value];
        }

        if (is_array($value)) {
            $tokens = [];

            foreach ($value as $part) {
                foreach ($this->tokenizeRootIdentifierValue($part) as $token) {
                    $tokens[] = $token;
                }
            }

            return $tokens;
        }

        if (is_object($value) && method_exists($value, '__toString')) {
            return $this->tokenizeRootIdentifierValue((string) $value);
        }

        return [];
    }

    /**
     * @param array<int, string> $tokens
     * @return array<int, string>
     */
    private function normalizeTokens(array $tokens): array
    {
        $normalized = [];

        foreach ($tokens as $token) {
            $token = trim((string) $token);

            if ($token === '') {
                continue;
            }

            $normalized[strtolower($token)] = true;
        }

        return array_keys($normalized);
    }

    /**
     * @param array<int, string> $filterTokens
     * @param array<int, string> $sectionTokens
     */
    private function matchesRootIdentifier(array $filterTokens, array $sectionTokens): bool
    {
        if ($filterTokens === []) {
            return true;
        }

        return array_intersect($filterTokens, $sectionTokens) !== [];
    }

    private function stringifyRootIdentifier(mixed $value): ?string
    {
        if ($value === null) {
            return null;
        }

        if (is_string($value)) {
            $trimmed = trim($value);

            return $trimmed === '' ? null : $trimmed;
        }

        if (is_numeric($value)) {
            return (string) $value;
        }

        if (is_array($value)) {
            $parts = [];

            foreach ($value as $part) {
                if (is_numeric($part) || is_string($part)) {
                    $parts[] = trim((string) $part);
                }
            }

            $parts = array_filter($parts, static function ($part) {
                return $part !== '';
            });

            if ($parts === []) {
                return null;
            }

            return implode(',', $parts);
        }

        return trim((string) $value) ?: null;
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

}

class SectionPayloadResult
{
    public function __construct(
        public array $section,
        public string $etag,
    ) {
    }
}

class FeaturedSectionServiceResult
{
    /**
     * @param array<int, array<string, mixed>> $sections
     */
    public function __construct(
        public array $sections,
        public string $etag,
        public string $cacheControl,
        public int $ttl,
    ) {
    }
}
