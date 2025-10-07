<?php

namespace App\Services;

use App\Models\Category;
use App\Models\Item;
use App\Models\Setting;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Arr;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Config;
use Illuminate\Support\Facades\Storage;
use InvalidArgumentException;

class DepartmentAdvertiserService
{
    public const KEY_COMPUTER = 'department_advertiser_computer';
    public const KEY_SHEIN = 'department_advertiser_shein';

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

        if ($item->interface_type) {
            $interfaceMap = Config::get('cart.interface_map', []);
            $department = $interfaceMap[$item->interface_type] ?? null;

            if ($department) {
                return $department;
            }
        }

        $categoryId = $item->category_id ? (int) $item->category_id : null;

        if ($categoryId) {
            $department = $this->departmentFromCategory($categoryId);
            if ($department) {
                return $department;
            }
        }

        if (! empty($item->all_category_ids)) {
            $ids = array_filter(array_map('intval', explode(',', (string) $item->all_category_ids)));

            foreach ($ids as $id) {
                $department = $this->departmentFromCategory($id);
                if ($department) {
                    return $department;
                }
            }
        }

        return null;
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
                ->select(['id', 'parent_category_id'])
                ->get()
                ->keyBy('id');
        }

        return $this->categoryHierarchy;
    }
}