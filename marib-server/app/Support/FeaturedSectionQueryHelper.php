<?php

namespace App\Support;

use App\Models\FeatureSection;
use App\Services\FeatureSectionCategoryService;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Facades\Schema;

class FeaturedSectionQueryHelper
{
    private static ?string $resolvedPriceColumn = null;

    public static function configureQuery(
        Builder $query,
        FeatureSection $section,
        string $canonicalSectionType
    ): FeaturedSectionQueryState {
        $canonicalSectionTypes = FeatureSectionCategoryService::allowedSectionTypes();
        $categoryFilterIds = FeatureSectionCategoryService::categoryIdsForSection($canonicalSectionType);

        if ($categoryFilterIds !== null) {
            if ($categoryFilterIds === []) {
                $query->whereRaw('0 = 1');
            } else {
                $query->whereIn('category_id', $categoryFilterIds);
            }
        }

        if (in_array($canonicalSectionType, $canonicalSectionTypes, true)) {
            $interfaceVariants = FeatureSectionCategoryService::sectionTypeVariants($canonicalSectionType);

            if ($interfaceVariants !== []) {
                $query->whereIn('interface_type', $interfaceVariants);
            }
        }

        $filter = $section->filter;
        $supportedFilters = FeatureSection::supportedFilters();
        $filter = in_array($filter, $supportedFilters, true) ? $filter : 'latest';

        $priceColumn = self::priceColumn();
        $priceColumnQualified = sprintf('items.%s', $priceColumn);
        $minPrice = self::normalizePrice($section->min_price);
        $maxPrice = self::normalizePrice($section->max_price);

        if ($filter === 'featured') {
            $query->whereHas('featured_items');
        }

        switch ($filter) {
            case 'most_viewed':
                $query->orderByDesc('clicks');
                break;

            case 'price_range':
                $query->whereNotNull($priceColumnQualified);

                if ($minPrice !== null) {
                    $query->where($priceColumnQualified, '>=', $minPrice);
                }

                if ($maxPrice !== null) {
                    $query->where($priceColumnQualified, '<=', $maxPrice);
                }

                $query->orderBy($priceColumnQualified, 'asc');
                break;

            default:
                $query->orderBy('created_at', 'desc');
                break;
        }

        return new FeaturedSectionQueryState(
            filter: $filter,
            priceColumn: $priceColumn,
            priceColumnQualified: $priceColumnQualified,
            minPrice: $minPrice,
            maxPrice: $maxPrice,
        );
    }

    public static function normalizePrice(mixed $value): ?float
    {
        if ($value === null) {
            return null;
        }

        if (is_string($value)) {
            $value = trim($value);

            if ($value === '') {
                return null;
            }

            $value = str_replace(',', '', $value);
        }

        if (is_numeric($value)) {
            return (float) $value;
        }

        return null;
    }

    public static function priceColumn(): string
    {
        if (self::$resolvedPriceColumn !== null) {
            return self::$resolvedPriceColumn;
        }

        self::$resolvedPriceColumn = Schema::hasColumn('items', 'price_effective') ? 'price_effective' : 'price';

        return self::$resolvedPriceColumn;
    }
}