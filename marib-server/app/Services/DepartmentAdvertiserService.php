<?php

namespace App\Services;

use App\Models\Category;
use App\Models\Item;
use App\Models\Setting;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Arr;
use App\Services\InterfaceSectionService;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Config;
use Illuminate\Support\Facades\Storage;
use InvalidArgumentException;

class DepartmentAdvertiserService
{
    public const KEY_COMPUTER = 'department_advertiser_computer';
    public const KEY_SHEIN = 'department_advertiser_shein';

    private const EXCLUDED_INTERFACE_TYPES = ['public_ads', 'real_estate_services'];
    private const EXCLUDED_SECTION_SLUGS = ['public_ads', 'real_estate_services'];

    /**
     * @var array<string, string>
     */
    private const DEPARTMENT_KEYS = [
        DepartmentReportService::DEPARTMENT_COMPUTER => self::KEY_COMPUTER,
        DepartmentReportService::DEPARTMENT_SHEIN => self::KEY_SHEIN,
    ];

    /**
     * @var array<string, array<string, mixed>>
     */
    private array $advertiserCache = [];

    private ?Collection $categoryHierarchy = null;
    private ?array $excludedSectionRootIds = null;

    /**
     * Retrieve the advertiser configuration for a department.
     */
    public function getAdvertiser(string $department): array
    {
        if (isset($this->advertiserCache[$department])) {
            return $this->advertiserCache[$department];
        }

        $raw = $this->getRawAdvertiser($department);

        if ($raw === []) {
            return $this->advertiserCache[$department] = [];
        }

        $imagePath = Arr::get($raw, 'image');

        return $this->advertiserCache[$department] = [
            'name' => (string) Arr::get($raw, 'name', ''),
            'image' => $imagePath ? Storage::url($imagePath) : null,
            'contact_number' => Arr::get($raw, 'contact_number'),
            'message_number' => Arr::get($raw, 'message_number'),
            'location' => Arr::get($raw, 'location'),
        ];
    }

    /**
     * Update the advertiser information for a department.
     */
    public function updateAdvertiser(string $department, array $data, ?UploadedFile $image = null): array
    {
        $key = $this->resolveKey($department);

        if ($key === null) {
            throw new InvalidArgumentException('Unsupported department supplied.');
        }

        $raw = $this->getRawAdvertiser($department);
        $existingImage = Arr::get($raw, 'image');

        if ($image !== null) {
            $newPath = FileService::upload($image, 'department-advertisers');

            if (! empty($existingImage)) {
                FileService::delete($existingImage);
            }

            $raw['image'] = $newPath;
        }

        $raw['name'] = Arr::get($data, 'name');
        $raw['contact_number'] = Arr::get($data, 'contact_number');
        $raw['message_number'] = Arr::get($data, 'message_number');
        $raw['location'] = Arr::get($data, 'location');

        Setting::query()->updateOrCreate(
            ['name' => $key],
            [
                'value' => json_encode($raw, JSON_UNESCAPED_UNICODE),
                'type' => 'json',
            ]
        );

        CachingService::removeCache(config('constants.CACHE.SETTINGS'));

        unset($this->advertiserCache[$department]);

        return $this->getAdvertiser($department);
    }

    /**
     * Resolve the department identifier for a given item instance.
     */
    public function resolveDepartmentForItem($item): ?string
    {
        if (! $item instanceof Item) {
            return null;
        }

        if ($this->isExcludedSectionItem($item)) {
            return null;
        }
        if ($item->interface_type) {
            $normalizedInterface = $this->normalizeInterfaceType($item->interface_type);

            if ($normalizedInterface && $this->isExcludedInterfaceType($normalizedInterface)) {
                return null;
            }

            $interfaceMap = Config::get('cart.interface_map', []);
            $department = $interfaceMap[$normalizedInterface ?? $item->interface_type] ?? null;


            if ($department) {
                return $department;
            }
        }

        foreach ($this->collectItemCategoryIds($item) as $id) {
            $department = $this->departmentFromCategory($id);
            if ($department) {
                return $department;
            }
        }

        return null;
    }

    public function isExcludedSectionItem(Item $item): bool
    {
        $interfaceType = $this->normalizeInterfaceType($item->interface_type ?? null);
        if ($interfaceType && $this->isExcludedInterfaceType($interfaceType)) {
            return true;
        }

        foreach ($this->collectItemCategoryIds($item) as $id) {
            if ($this->belongsToExcludedSection($id)) {
                return true;
            }
        }

        return false;
    }

    private function resolveKey(string $department): ?string
    {
        return self::DEPARTMENT_KEYS[$department] ?? null;
    }

    private function getRawAdvertiser(string $department): array
    {
        $key = $this->resolveKey($department);

        if ($key === null) {
            return [];
        }

        $value = CachingService::getSystemSettings($key);

        if (! is_string($value) || $value === '') {
            $setting = Setting::query()->where('name', $key)->value('value');
            $value = is_string($setting) ? $setting : '';
        }

        if ($value === '') {
            return [];
        }

        $decoded = json_decode($value, true);

        return is_array($decoded) ? $decoded : [];
    }

    private function departmentFromCategory(int $categoryId): ?string
    {

        if ($this->belongsToExcludedSection($categoryId)) {
            return null;
        }

        $categories = $this->getCategoryHierarchy();
        $currentId = $categoryId;
        $visited = [];

        $departmentRoots = [];

        foreach (Config::get('cart.department_roots', []) as $department => $rootId) {
            $departmentRoots[$department] = (int) $rootId;
        }

        while ($currentId && ! in_array($currentId, $visited, true)) {
            $visited[] = $currentId;

            foreach ($departmentRoots as $department => $rootId) {
                if ($currentId === $rootId) {
                    return $department;
                }
            }

            $category = $categories->get($currentId);

            if (! $category) {
                break;
            }

            $currentId = $category->parent_category_id ? (int) $category->parent_category_id : null;
        }

        return null;
    }

    private function getCategoryHierarchy(): Collection
    {
        if ($this->categoryHierarchy === null) {
            $this->categoryHierarchy = Category::query()
                ->select(['id', 'parent_category_id', 'slug'])
                ->get()
                ->keyBy('id');
        }

        return $this->categoryHierarchy;


    }

    private function normalizeInterfaceType(?string $interfaceType): ?string
    {
        if ($interfaceType === null) {
            return null;
        }

        $interfaceType = trim($interfaceType);

        if ($interfaceType === '') {
            return null;
        }

        $canonical = InterfaceSectionService::canonicalSectionTypeOrNull($interfaceType);

        if ($canonical !== null) {
            return $canonical;
        }

        return strtolower($interfaceType);
    }

    private function isExcludedInterfaceType(string $interfaceType): bool
    {
        return in_array($interfaceType, self::EXCLUDED_INTERFACE_TYPES, true);
    }

    /**
     * @return int[]
     */
    private function collectItemCategoryIds(Item $item): array
    {
        $ids = [];

        $append = static function ($value) use (&$ids, &$append): void {
            if ($value === null) {
                return;
            }

            if ($value instanceof Category) {
                $append($value->getKey());

                return;
            }

            if ($value instanceof Collection) {
                foreach ($value as $entry) {
                    $append($entry);
                }

                return;
            }

            if (is_array($value)) {
                foreach ($value as $entry) {
                    $append($entry);
                }

                return;
            }

            if (is_numeric($value)) {
                $intValue = (int) $value;

                if ($intValue > 0) {
                    $ids[] = $intValue;
                }

                return;
            }

            if (is_string($value) && $value !== '') {
                preg_match_all('/\d+/', $value, $matches);

                foreach ($matches[0] ?? [] as $match) {
                    $append((int) $match);
                }
            }
        };

        $append($item->category_id ?? null);

        if ($item->relationLoaded('category')) {
            $append($item->getRelation('category'));
        } else {
            $append($item->getAttribute('category'));
        }

        $append($item->all_category_ids ?? null);

        $ids = array_filter($ids, static fn ($value) => is_int($value) && $value > 0);

        return array_values(array_unique($ids));
    }

    private function belongsToExcludedSection(int $categoryId): bool
    {
        $rootIds = $this->getExcludedSectionRootIds();

        if ($rootIds === []) {
            return false;
        }

        $categories = $this->getCategoryHierarchy();
        $currentId = $categoryId;
        $visited = [];

        while ($currentId && ! in_array($currentId, $visited, true)) {
            $visited[] = $currentId;

            if (in_array($currentId, $rootIds, true)) {
                return true;
            }

            $category = $categories->get($currentId);

            if (! $category) {
                break;
            }

            $currentId = $category->parent_category_id ? (int) $category->parent_category_id : null;
        }

        return false;
    }

    /**
     * @return int[]
     */
    private function getExcludedSectionRootIds(): array
    {
        if ($this->excludedSectionRootIds !== null) {
            return $this->excludedSectionRootIds;
        }

        $configuredRoots = Config::get('cart.department_roots', []);
        $roots = [];

        foreach ($configuredRoots as $sectionType => $rootId) {
            if (! is_string($sectionType)) {
                continue;
            }

            $normalized = $this->normalizeInterfaceType($sectionType);

            if (! $normalized || ! $this->isExcludedInterfaceType($normalized)) {
                continue;
            }

            if (is_numeric($rootId)) {
                $intRootId = (int) $rootId;

                if ($intRootId > 0) {
                    $roots[] = $intRootId;
                }
            }
        }

        $this->excludedSectionRootIds = array_values(array_unique($roots));

        return $this->excludedSectionRootIds;



    }
}
