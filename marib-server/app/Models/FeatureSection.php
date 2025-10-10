<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Str;

class FeatureSection extends Model {
    use HasFactory;


    public const FILTER_DEFINITIONS = [
        'latest' => [
            'label'   => 'Newest',
            'slug'    => 'latest',
            'aliases' => ['latest', 'latest_ads', 'latest_items', 'newest', 'newest_ads', 'newest_items', 'new_to_old', 'new-to-old'],
        ],
        'most_viewed' => [
            'label'   => 'Most Viewed',
            'slug'    => 'most_viewed',
            'aliases' => [
                'mostviewed',
                'most_viewed_ads',
                'most_viewed_items',
                'top_viewed',
                'top_viewed_ads',
                'top_viewed_items',
            ],
        
        ],


    ];

    protected $fillable = [
        'title',
        'slug',
        'sequence',
        'filter',
        'value',
        'style',
        'section_type',
        'min_price',
        'max_price',
        'description',
        'is_active'
    ];

    protected $casts = [
        'is_active' => 'boolean',
    ];


    public static function allowedSlugsForFilter(?string $filter): array
    {
        if ($filter === null) {
            return [];
        }

        $configured = self::filterDefinition($filter);

        $aliases = [];

        if ($configured !== null) {
            $aliases = array_merge(
                [$configured['slug'] ?? $filter],
                $configured['aliases'] ?? []
            );
        }


        $normalized = array_map([
            self::class,
            'normalizeSlug',
        ], $aliases);

        if ($filter !== null) {
            $normalized[] = self::normalizeSlug($filter);
        }

        $normalized = array_values(array_filter(array_unique($normalized)));

        return $normalized;
    }

    public static function canonicalSlugForFilter(?string $filter): ?string
    {

        $definition = self::filterDefinition($filter);

        if ($definition !== null && isset($definition['slug'])) {
            $canonical = self::normalizeSlug($definition['slug']);

            if ($canonical !== '') {
                return $canonical;
            }
        }

        $allowed = self::allowedSlugsForFilter($filter);

        return $allowed[0] ?? null;
    }

    public static function normalizeSlug(?string $value): string
    {
        $value = (string) $value;

        if ($value === '') {
            return '';
        }

        $value = preg_replace('/([a-z\d])([A-Z])/', '$1_$2', $value) ?? $value;
        $value = preg_replace('/([A-Z\d])([A-Z][a-z])/', '$1_$2', $value) ?? $value;

        $normalized = Str::slug($value, '_');
        return $normalized === '' ? '' : $normalized;
    }

    public static function slugMatchesFilter(string $slug, ?string $filter): bool
    {
        if ($filter === null || $filter === '') {
            return true;
        }

        $normalizedSlug = self::normalizeSlug($slug);
        $allowedSlugs = self::allowedSlugsForFilter($filter);

        foreach ($allowedSlugs as $allowed) {
            if ($normalizedSlug === $allowed) {
                return true;
            }
        }

        return false;
    }



    public static function supportedFilters(): array
    {
        return array_keys(self::FILTER_DEFINITIONS);
    }

    public static function filterDefinitions(): array
    {
        return self::FILTER_DEFINITIONS;
    }

    public static function filterLabels(): array
    {
        $labels = [];

        foreach (self::FILTER_DEFINITIONS as $filter => $definition) {
            $label = $definition['label'] ?? $filter;
            $labels[$filter] = __($label);
        }

        return $labels;
    }

    public static function filterAliases(?string $filter): array
    {
        $definition = self::filterDefinition($filter);

        if ($definition === null) {
            return [];
        }

        $aliases = $definition['aliases'] ?? [];

        $normalized = array_map([
            self::class,
            'normalizeSlug',
        ], $aliases);

        return array_values(array_filter(array_unique($normalized)));
    }

    private static function filterDefinition(?string $filter): ?array
    {
        if ($filter === null) {
            return null;
        }

        return self::FILTER_DEFINITIONS[$filter] ?? null;
    }




    public function category() {
        return $this->belongsTo(Category::class, 'category_id', 'id');
    }

    public function scopeSearch($query, $search) {
        $search = "%" . $search . "%";
        $query = $query->where(function ($q) use ($search) {
            $q->orWhere('title', 'LIKE', $search)
                ->orWhere('sequence', 'LIKE', $search)
                ->orWhere('filter', 'LIKE', $search)
                ->orWhere('value', 'LIKE', $search)
                ->orWhere('style', 'LIKE', $search)
                ->orWhere('min_price', 'LIKE', $search)
                ->orWhere('max_price', 'LIKE', $search)
                ->orWhere('created_at', 'LIKE', $search)
                ->orWhere('updated_at', 'LIKE', $search)
                ->orWhere('description', 'LIKE', $search);
        });
        return $query;
    }

    public function scopeActive($query) {
        return $query->where('is_active', true);
    }

}
