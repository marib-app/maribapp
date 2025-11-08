<?php

namespace App\Services;

use App\Models\Category;
use Illuminate\Support\Arr;
use Illuminate\Support\Collection;
use Illuminate\Support\Str;

class InterfaceSectionService
{
    public static function categoriesForSection(?string $sectionType): Collection
    {
        $sectionKey = self::normalizeSectionType($sectionType);
        $rootIdentifiers = self::rootIdentifiers();


        $allowedSectionTypes = self::allowedSectionTypes();

        if (! in_array($sectionKey, $allowedSectionTypes, true)) {
            return collect();
        }


        if (! array_key_exists($sectionKey, $rootIdentifiers)) {
            return collect();
        }

        $categories = Category::select('id', 'name', 'slug', 'parent_category_id', 'sequence')->get();
        $rootIdentifier = $rootIdentifiers[$sectionKey];

        $categoryIds = self::resolveCategoryTree($categories, $rootIdentifier);

        if ($categoryIds === null) {
            
            return $categories;
        }

        if ($categoryIds === []) {

            return collect();
        }


        return $categories
            ->whereIn('id', $categoryIds)
            ->values();
    }

    public static function categoryIdsForSection(?string $sectionType): ?array
    {
        $sectionKey = self::normalizeSectionType($sectionType);
        $rootIdentifiers = self::rootIdentifiers();

        $allowedSectionTypes = self::allowedSectionTypes();

        if (! in_array($sectionKey, $allowedSectionTypes, true)) {
            return [];
        }


        if (! array_key_exists($sectionKey, $rootIdentifiers)) {
            return null;
        }

        $rootIdentifier = $rootIdentifiers[$sectionKey];

        if ($rootIdentifier === null) {
            return null;
        }

        $categories = Category::select('id', 'slug', 'parent_category_id')->get();
        $categoryIds = self::resolveCategoryTree($categories, $rootIdentifier);

        if ($categoryIds === null) {
            return null;

        }

        return $categoryIds;

    }

    public static function rootIdentifiers(): array
    {
        $identifiers = config('interface_sections.root_identifiers', []);

        $overridesRaw = CachingService::getSystemSettings('featured_section_root_identifiers');

        if (is_string($overridesRaw) && $overridesRaw !== '') {
            try {
                $decoded = json_decode($overridesRaw, true, 512, JSON_THROW_ON_ERROR);
            } catch (\JsonException) {
                $decoded = null;
            }

            if (is_array($decoded)) {
                foreach ($decoded as $sectionType => $value) {
                    $identifiers[$sectionType] = $value;
                }
            }
        }
        foreach ($identifiers as $key => $identifier) {
            $identifiers[$key] = self::sanitizeRootIdentifier($identifier);
        }
        return $identifiers;

    }

    public static function allowedSectionTypes(bool $includeLegacy = false): array
    {
        $rootIdentifiers = self::rootIdentifiers();
        $configured = config('interface_sections.allowed_section_types');

        if (is_array($configured) && $configured !== []) {
            $allowed = array_values(array_filter($configured, static function ($sectionType) use ($rootIdentifiers) {
                return array_key_exists($sectionType, $rootIdentifiers);
            }));
        } else {
            $allowed = array_keys($rootIdentifiers);

        }

        if ($includeLegacy) {
            $allowed = array_values(array_unique(array_merge($allowed, self::legacySectionTypes())));
        }

        if (! in_array('all', $allowed, true)) {
            $allowed[] = 'all';
        }

        return $allowed;
    }


    public static function defaultSectionType(): ?string
    {
        $allowed = self::allowedSectionTypes();

        return $allowed[0] ?? null;
    }

    public static function legacySectionTypes(): array
    {
        return array_keys(self::sectionTypeAliases());
    
    }

    public static function sectionTypeAliases(): array
    {
        $configured = config('interface_sections.section_type_aliases', []);

        return array_merge(self::generatedServiceAliases(), $configured);
    
    }
    
    
    public static function sectionTypeVariants(string $sectionType): array
    {
        $canonical = self::normalizeSectionType($sectionType);
        $variants = [$canonical];

        foreach (self::sectionTypeAliases() as $alias => $target) {
            if ($target === $canonical) {
                $variants[] = $alias;
            }
        }

        return array_values(array_unique($variants));
    }

    public static function expandSectionTypes(array $sectionTypes): array
    {
        $expanded = [];

        foreach ($sectionTypes as $sectionType) {
            foreach (self::sectionTypeVariants($sectionType) as $variant) {
                $expanded[] = $variant;
            }
        }

        return array_values(array_unique($expanded));
    }


    public static function canonicalSectionTypeOrNull(?string $sectionType): ?string
    {
        if ($sectionType === null) {
            return null;
        }

        $sectionType = trim($sectionType);

        if ($sectionType === '') {
            return null;
        }

        $rootIdentifiers = self::rootIdentifiers();

        if (array_key_exists($sectionType, $rootIdentifiers)) {
            return $sectionType;
        }

        $lowerSectionType = strtolower($sectionType);

        if (array_key_exists($lowerSectionType, $rootIdentifiers)) {
            return $lowerSectionType;
        }

        if ($lowerSectionType === 'all') {
            return 'all';
        }

        $aliasMap = self::normalizedAliasMap();

        if (array_key_exists($lowerSectionType, $aliasMap)) {
            return $aliasMap[$lowerSectionType];
        }

        return null;
    }



    public static function normalizeSectionType(?string $sectionType): string
    {
        $default = self::defaultSectionType() ?? '';

        if ($sectionType === null) {
            return $default;
        }

        $sectionType = trim($sectionType);

        if ($sectionType === '') {
            return $default;
        }

        $rootIdentifiers = self::rootIdentifiers();

        if (array_key_exists($sectionType, $rootIdentifiers)) {
            return $sectionType;
        }

        $lowerSectionType = strtolower($sectionType);


        if ($lowerSectionType === 'all') {
            return 'all';
        }




        if (array_key_exists($lowerSectionType, $rootIdentifiers)) {
            return $lowerSectionType;
        }

        $aliasMap = self::normalizedAliasMap();

        if (array_key_exists($lowerSectionType, $aliasMap)) {
            return $aliasMap[$lowerSectionType];
        }

        return $lowerSectionType;
    }

    private static function normalizedAliasMap(): array
    {
        $aliases = self::sectionTypeAliases();
        $normalized = [];

        foreach ($aliases as $alias => $canonical) {
            $normalized[strtolower($alias)] = $canonical;
        }

        return $normalized;
    
    
    }

    private static function findRootCategory(Collection $categories, int|string $identifier): ?object
    {
        if (is_numeric($identifier)) {
            return $categories->firstWhere('id', (int) $identifier);
        }

        return $categories->firstWhere('slug', $identifier);
    }

    private static function collectCategoryIds(Collection $categories, int $rootId, bool $includeRoot = true): array
    {
        $ids = $includeRoot ? [$rootId] : [];
        $queue = [$rootId];

        while (! empty($queue)) {
            $current = array_shift($queue);
            $children = $categories->where('parent_category_id', $current);

            foreach ($children as $child) {
                if (! in_array($child->id, $ids, true)) {
                    $ids[] = $child->id;
                    $queue[] = $child->id;
                }
            }
        }

        return $ids;
    }



    private static function resolveCategoryTree(Collection $categories, mixed $rootIdentifier): ?array
    {
        if ($rootIdentifier === null) {
            return null;
        }

        $identifiers = Arr::wrap($rootIdentifier);
        $collected = [];

        foreach ($identifiers as $identifier) {
            $rootCategory = self::findRootCategory($categories, $identifier);

            if (! $rootCategory) {
                continue;
            }

            foreach (self::collectCategoryIds($categories, (int) $rootCategory->id) as $id) {
                $collected[] = (int) $id;
            }
        }

        if ($collected === []) {
            return [];
        }

        return array_values(array_unique($collected));
    }

    private static function generatedServiceAliases(): array
    {
        $aliases = [];
        $rootIdentifiers = self::rootIdentifiers();

        foreach ($rootIdentifiers as $sectionType => $identifier) {
            if (! str_starts_with($sectionType, 'services_')) {
                continue;
            }

            foreach (self::serviceAliasVariants($sectionType, $identifier) as $alias) {
                if (! isset($aliases[$alias])) {
                    $aliases[$alias] = $sectionType;
                }
            }
        }

        return $aliases;
    }

    private static function serviceAliasVariants(string $sectionType, mixed $identifier): array
    {
        $variants = [];

        $variants[] = $sectionType;
        $variants[] = str_replace('_', '-', $sectionType);
        $variants[] = str_replace('_', '', $sectionType);
        $variants[] = Str::camel($sectionType);
        $variants[] = Str::studly($sectionType);
        $variants[] = 'itemsList' . Str::studly($sectionType);
        $variants[] = 'itemslist' . Str::studly($sectionType);

        $base = Str::after($sectionType, 'services_');

        if ($base !== '' && $base !== $sectionType) {
            $variants[] = $base . '_services';
            $variants[] = str_replace('_', '-', $base) . '-services';
            $variants[] = str_replace('_', '', $base) . 'services';
            $variants[] = 'itemsList' . Str::studly($base);
            $variants[] = 'itemslist' . Str::studly($base);
            $variants[] = 'services' . Str::studly($base);
            $variants[] = 'services-' . str_replace('_', '-', $base);
        }

        if (is_numeric($identifier)) {
            $variants[] = (string) $identifier;
        } elseif (is_string($identifier)) {
            $variants[] = $identifier;
        } elseif (is_array($identifier)) {
            foreach ($identifier as $value) {
                if (is_numeric($value) || is_string($value)) {
                    $variants[] = (string) $value;
                }
            }
        }

        return array_values(array_unique(array_filter($variants)));
    }



    private static function sanitizeRootIdentifier(mixed $identifier): mixed
    {
        if ($identifier === null) {
            return null;
        }

        if (is_string($identifier)) {
            $identifier = trim($identifier);

            if ($identifier === '') {
                return null;
            }

            if (is_numeric($identifier)) {
                return (int) $identifier;
            }

            return $identifier;
        }

        if (is_int($identifier)) {
            return $identifier;
        }

        if (is_float($identifier)) {
            return (int) $identifier;
        }

        if (is_array($identifier)) {
            $sanitized = [];

            foreach ($identifier as $value) {
                $value = self::sanitizeRootIdentifier($value);

                if ($value === null) {
                    continue;
                }

                $sanitized[] = $value;
            }

            return $sanitized === [] ? null : $sanitized;
        }

        if (is_numeric($identifier)) {
            return (int) $identifier;
        }

        return null;
    }

}
