<?php

namespace App\Services;

use App\Models\Category;
use App\Models\CustomField;
use App\Models\CustomFieldCategory;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use InvalidArgumentException;

class CategoryCloneService
{
    /**
     * Mapping between section keys and their root category slug.
     */
    protected array $sectionRootSlugs = [
        'shein' => 'shein_products',
        'computer' => 'computer_section',
    ];


        public function cloneCategoryTree(int $sourceCategoryId, ?int $targetParentCategoryId, bool $synchronizeExisting = false): array
    {
        $sourceCategory = Category::with(['translations', 'custom_fields.custom_fields', 'subcategories'])->findOrFail($sourceCategoryId);
        $targetParent = $targetParentCategoryId ? Category::findOrFail($targetParentCategoryId) : null;

        $stats = $this->initializeStats();

        DB::transaction(function () use ($sourceCategory, $targetParent, $synchronizeExisting, &$stats) {
            $cloned = $this->cloneCategoryNode($sourceCategory, $targetParent, $synchronizeExisting, null, $stats);
            $stats['cloned_category_id'] = $cloned->id;
        });

        return $stats;
    }



    /**
     * Clone categories and custom fields from the public ads section to the given section.
     */
    public function clonePublicAdsToSection(string $section): array
    {
        $sectionKey = strtolower(trim($section));

        if (! array_key_exists($sectionKey, $this->sectionRootSlugs)) {
            throw new InvalidArgumentException("Unknown section [{$sectionKey}]");
        }

        $sourceRoot = Category::where('slug', 'public_ads')->with(['translations', 'custom_fields.custom_fields', 'subcategories'])->firstOrFail();
        $targetRoot = Category::where('slug', $this->sectionRootSlugs[$sectionKey])->with(['translations', 'custom_fields.custom_fields', 'subcategories'])->firstOrFail();

        $stats = $this->initializeStats();


        DB::transaction(function () use ($sourceRoot, $targetRoot, $sectionKey, &$stats) {
            $this->syncCustomFields($sourceRoot, $targetRoot, $stats);
            $this->syncTranslations($sourceRoot, $targetRoot);

            $sourceRoot->loadMissing('subcategories');


            $slugTransformer = function (string $slug, Category $sourceCategory, ?Category $targetParent = null) use ($sectionKey) {
                return $this->buildSectionSlug($sectionKey, $slug);
            };





            foreach ($sourceRoot->subcategories as $subcategory) {
                $this->cloneCategoryNode($subcategory, $targetRoot, true, $slugTransformer, $stats);
            }
        });

        return $stats;
    }

    protected function cloneCategoryNode(Category $sourceCategory, ?Category $targetParent, bool $synchronizeExisting, ?callable $slugTransformer, array &$stats): Category
    
    {
        $sourceCategory->loadMissing(['translations', 'custom_fields.custom_fields', 'subcategories']);

        $baseSlug = $sourceCategory->slug ?: Str::slug($sourceCategory->name);
        if (! $baseSlug) {
            $baseSlug = 'category-' . $sourceCategory->id;
        }

        if ($slugTransformer) {
            $transformed = $slugTransformer($baseSlug, $sourceCategory, $targetParent);
            if (! empty($transformed)) {
                $baseSlug = $transformed;
            }
        }

        $baseSlug = Str::slug($baseSlug);
        if (! $baseSlug) {
            $baseSlug = 'category-' . Str::random(6);
        }

        $targetCategory = null;

        if ($synchronizeExisting) {
            $query = Category::query();

            if ($targetParent) {
                $query->where('parent_category_id', $targetParent->id);
            } else {
                $query->whereNull('parent_category_id');
            }


            $existingCategory = $query
                ->where(function ($query) use ($baseSlug, $sourceCategory) {
                    $query->where('slug', $baseSlug)
                        ->orWhere('slug', 'like', $baseSlug . '-%')
                        ->orWhere('name', $sourceCategory->name);
                })
                ->first();

            if ($existingCategory) {
                $targetCategory = $existingCategory;
                $stats['skipped_categories']++;
            }
        }



        if (! $targetCategory) {


            $targetCategory = $sourceCategory->replicate(['parent_category_id', 'slug']);
            $targetCategory->parent_category_id = $targetParent?->id;
            $targetCategory->slug = HelperService::generateUniqueSlug(new Category(), $baseSlug);
            $targetCategory->save();
            $stats['created_categories']++;
        }

        $this->syncTranslations($sourceCategory, $targetCategory);
        $this->syncCustomFields($sourceCategory, $targetCategory, $stats);

        foreach ($sourceCategory->subcategories as $child) {
            $this->cloneCategoryNode($child, $targetCategory, $synchronizeExisting, $slugTransformer, $stats);
        }

        return $targetCategory;
    }

    protected function initializeStats(): array
    {
        return [
            'created_categories' => 0,
            'skipped_categories' => 0,
            'created_fields' => 0,
            'reused_fields' => 0,
            'attached_fields' => 0,
            'cloned_category_id' => null,
        ];

        
    }

    protected function syncTranslations(Category $sourceCategory, Category $targetCategory): void
    {
        $sourceCategory->loadMissing('translations');

        foreach ($sourceCategory->translations as $translation) {
            $targetCategory->translations()->updateOrCreate(
                [
                    'language_id' => $translation->language_id,
                ],
                [
                    'name' => $translation->name,
                ]
            );
        }
    }

    protected function syncCustomFields(Category $sourceCategory, Category $targetCategory, array &$stats): void
    {
        $sourceCategory->loadMissing('custom_fields.custom_fields');

        foreach ($sourceCategory->custom_fields as $pivot) {
            $sourceField = $pivot->custom_fields;

            if (! $sourceField) {
                continue;
            }

            $targetField = CustomField::where('name', $sourceField->name)->first();

            if ($targetField) {
                $stats['reused_fields']++;
            } else {
                $targetField = $sourceField->replicate();
                $targetField->save();
                $stats['created_fields']++;
            }

            $pivotModel = CustomFieldCategory::firstOrCreate([
                'category_id' => $targetCategory->id,
                'custom_field_id' => $targetField->id,
            ]);

            if ($pivotModel->wasRecentlyCreated) {
                $stats['attached_fields']++;
            }
        }
    }

    protected function buildSectionSlug(string $sectionKey, string $sourceSlug): string
    {
        $normalized = Str::slug($sourceSlug);

        if (Str::startsWith($normalized, $sectionKey . '-')) {
            return $normalized;
        }

        return $sectionKey . '-' . $normalized;
    }
}