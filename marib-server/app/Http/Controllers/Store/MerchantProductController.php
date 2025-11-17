<?php

namespace App\Http\Controllers\Store;

use App\Http\Controllers\Controller;
use App\Http\Controllers\ItemPurchaseManagementController;
use App\Models\Category;
use App\Models\Item;
use App\Models\ItemStock;
use App\Models\Store;
use App\Services\FileService;
use App\Services\HelperService;
use App\Support\ColorFieldParser;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Arr;
use Illuminate\Support\Collection;
use Illuminate\Support\Str;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
use Illuminate\View\View;

class MerchantProductController extends Controller
{
    private const ALLOWED_CURRENCIES = ['YER', 'SAR', 'USD'];

    public function index(Request $request): View
    {
        $store = $this->resolveCurrentStore($request);

        $filters = [
            'search' => trim((string) $request->query('search', '')),
            'status' => $request->query('status'),
        ];

        $itemsQuery = $store->items()
            ->select(['id', 'name', 'status', 'price', 'currency', 'updated_at'])
            ->with(['stocks' => static function ($query) {
                $query->orderBy('variant_key')->orderBy('id');
            }])
            ->withSum('stocks as total_stock', 'stock')
            ->latest('updated_at');

        if ($filters['search'] !== '') {
            $itemsQuery->where(static function ($query) use ($filters) {
                $query->where('name', 'like', '%' . $filters['search'] . '%');

                if (is_numeric($filters['search'])) {
                    $query->orWhere('id', (int) $filters['search']);
                }
            });
        }

        if (! empty($filters['status'])) {
            $itemsQuery->where('status', $filters['status']);
        }

        $items = $itemsQuery->paginate(12)->withQueryString();

        $store->loadCount([
            'items as merchant_products_total_count',
            'items as merchant_products_active_count' => static function ($query) {
                $query->where('status', 'approved');
            },
            'items as merchant_products_pending_count' => static function ($query) {
                $query->where('status', 'review');
            },
        ]);

        $stats = [
            'total' => (int) ($store->merchant_products_total_count ?? 0),
            'active' => (int) ($store->merchant_products_active_count ?? 0),
            'pending' => (int) ($store->merchant_products_pending_count ?? 0),
        ];

        $storeCategoryIds = Arr::wrap(data_get($store->meta, 'categories', []));

        return view('store.products.index', [
            'store' => $store,
            'items' => $items,
            'stats' => $stats,
            'categories' => $this->buildCategoryOptions($storeCategoryIds),
            'statuses' => $this->statusOptions(),
            'filters' => $filters,
            'missingLocation' => $this->storeMissingLocation($store),
            'defaultCurrency' => strtoupper((string) config('app.currency', 'SAR')),
            'currencyOptions' => $this->currencyOptions(),
            'sizeCatalog' => $this->defaultSizeCatalog(),
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        $store = $this->resolveCurrentStore($request);

        if ($this->storeMissingLocation($store)) {
            return redirect()
                ->route('merchant.products.index', ['tab' => 'create'])
                ->withErrors(['store' => __('merchant_products.messages.location_required')]);
        }

        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'category_id' => ['required', Rule::exists('categories', 'id')->where('status', 1)],
            'price' => ['required', 'numeric', 'min:0'],
            'currency' => ['required', Rule::in(self::ALLOWED_CURRENCIES)],
            'description' => ['required', 'string'],
            'stock' => ['required', 'integer', 'min:0'],
            'primary_image' => ['required', 'image', 'max:5120'],
            'video_link' => ['nullable', 'url'],
            'discount_type' => ['nullable', Rule::in(['none', 'percentage', 'fixed'])],
            'discount_value' => ['nullable', 'numeric', 'min:0', 'required_if:discount_type,percentage,fixed'],
            'discount_start' => ['nullable', 'date'],
            'discount_end' => ['nullable', 'date', 'after_or_equal:discount_start'],
            'delivery_size' => ['nullable', 'numeric', 'min:0'],
            'colors' => ['nullable', 'array'],
            'colors.*.code' => ['nullable', 'string', 'max:16'],
            'colors.*.label' => ['nullable', 'string', 'max:120'],
            'colors.*.quantity' => ['nullable', 'integer', 'min:0'],
            'sizes' => ['nullable', 'array'],
            'sizes.*.value' => ['nullable', 'string', 'max:120'],
            'custom_options' => ['nullable', 'array'],
            'custom_options.*' => ['nullable', 'string', 'max:255'],
        ], [], [
            'name' => __('merchant_products.form.name'),
            'category_id' => __('merchant_products.form.category'),
            'price' => __('merchant_products.form.price'),
            'currency' => __('merchant_products.form.currency'),
            'description' => __('merchant_products.form.description'),
            'stock' => __('merchant_products.form.stock'),
            'primary_image' => __('merchant_products.form.image'),
            'video_link' => __('merchant_products.form.video_link'),
            'delivery_size' => __('merchant_products.form.delivery_size'),
        ]);

        $discountType = $validated['discount_type'] ?? null;
        if ($discountType === 'none') {
            $discountType = null;
        }

        DB::transaction(function () use ($validated, $store, $request, $discountType) {
            $imagePath = FileService::compressAndUpload(
                $request->file('primary_image'),
                'store-products/' . $store->id
            );

            $user = $request->user();

            $contactChannel = $store->contact_phone
                ?? $store->contact_whatsapp
                ?? $store->contact_email
                ?? $user?->email
                ?? '';

            $slugSource = $request->input('slug')
                ?: ($validated['name'] ?? '')
                ?: HelperService::generateRandomSlug();
            $preparedSlug = Str::slug($slugSource);
            if ($preparedSlug === '') {
                $preparedSlug = Str::lower(Str::random(12));
            }
            $uniqueSlug = HelperService::generateUniqueSlug(new Item(), $preparedSlug);

            $item = Item::create([
                'name' => $validated['name'],
                'description' => $validated['description'],
                'price' => $validated['price'],
                'image' => $imagePath,
                'thumbnail_url' => $imagePath,
                'detail_image_url' => $imagePath,
                'latitude' => $store->location_latitude,
                'longitude' => $store->location_longitude,
                'address' => $store->location_address,
                'contact' => $contactChannel,
                'show_only_to_premium' => false,
                'status' => 'approved',
                'video_link' => $validated['video_link'] ?? null,
                'slug' => $uniqueSlug,
                'city' => $store->location_city ?? '—',
                'state' => $store->location_state ?? '—',
                'country' => $store->location_country ?? '—',
                'user_id' => $user?->id,
                'store_id' => $store->id,
                'category_id' => $validated['category_id'],
                'all_category_ids' => $this->buildCategoryTrail($validated['category_id']),
                'currency' => $validated['currency'],
                'interface_type' => 'store_products',
                'discount_type' => $discountType,
                'discount_value' => $discountType ? ($validated['discount_value'] ?? null) : null,
                'discount_start' => $discountType ? ($validated['discount_start'] ?? null) : null,
                'discount_end' => $discountType ? ($validated['discount_end'] ?? null) : null,
                'delivery_size' => $validated['delivery_size'] ?? null,
            ]);

            ItemStock::create([
                'item_id' => $item->id,
                'variant_key' => '',
                'stock' => $validated['stock'],
                'reserved_stock' => 0,
            ]);

            $this->syncProductAttributes($item, $request);
        });

        return redirect()
            ->route('merchant.products.index', ['tab' => 'catalog'])
            ->with('success', __('merchant_products.messages.created'));
    }

    public function updateStock(Request $request, Item $item): RedirectResponse
    {
        $store = $this->resolveCurrentStore($request);
        $this->ensureStoreOwnsItem($store, $item);

        $data = $request->validate([
            'stock_value' => ['required', 'integer', 'min:0'],
        ], [], [
            'stock_value' => __('merchant_products.form.stock'),
        ]);

        $stock = $item->stocks()->firstOrCreate(
            ['variant_key' => ''],
            ['stock' => 0, 'reserved_stock' => 0]
        );

        $stock->update(['stock' => $data['stock_value']]);

        return redirect()
            ->route('merchant.products.index', ['tab' => 'inventory'])
            ->with('success', __('merchant_products.messages.stock_updated'));
    }

    public function updateStatus(Request $request, Item $item): RedirectResponse
    {
        $store = $this->resolveCurrentStore($request);
        $this->ensureStoreOwnsItem($store, $item);

        $statusOptions = array_keys($this->statusOptions());

        $data = $request->validate([
            'status' => ['required', Rule::in($statusOptions)],
        ], [], [
            'status' => __('merchant_products.status_form.label'),
        ]);

        $item->update(['status' => $data['status']]);

        return redirect()
            ->route('merchant.products.index', ['tab' => 'catalog'])
            ->with('success', __('merchant_products.messages.status_updated'));
    }

    public function destroy(Request $request, Item $item): RedirectResponse
    {
        $store = $this->resolveCurrentStore($request);
        $this->ensureStoreOwnsItem($store, $item);

        $item->delete();

        return redirect()
            ->route('merchant.products.index', ['tab' => 'catalog'])
            ->with('success', __('merchant_products.messages.deleted'));
    }

    private function resolveCurrentStore(Request $request): Store
    {
        $store = $request->attributes->get('currentStore');

        abort_if(! $store instanceof Store, 404);

        return $store;
    }

    private function ensureStoreOwnsItem(Store $store, Item $item): void
    {
        abort_if($item->store_id !== $store->id, 404);
    }

    private function storeMissingLocation(Store $store): bool
    {
        return empty($store->location_address)
            || $store->location_latitude === null
            || $store->location_longitude === null;
    }

    /**
     * @return array<int, array{id:int,label:string}>
     */
    private function buildCategoryOptions(array $allowedCategoryIds = []): array
    {
        $query = Category::query()
            ->select(['id', 'name', 'parent_category_id', 'status'])
            ->where('status', 1);

        if ($allowedCategoryIds !== []) {
            $query->whereIn('id', $allowedCategoryIds);
        }

        $categories = $query
            ->orderBy('parent_category_id')
            ->orderBy('name')
            ->get();

        if ($categories->isEmpty() && $allowedCategoryIds !== []) {
            return $this->buildCategoryOptions([]);
        }

        if ($allowedCategoryIds !== []) {
            return $categories
                ->map(static fn ($category) => [
                    'id' => $category->id,
                    'label' => $category->name,
                ])
                ->values()
                ->all();
        }

        $grouped = $categories->groupBy('parent_category_id');

        $options = [];

        $walk = function (?int $parentId, string $prefix) use (&$walk, $grouped, &$options): void {
            foreach ($grouped->get($parentId, collect()) as $category) {
                $options[] = [
                    'id' => $category->id,
                    'label' => $prefix . $category->name,
                ];

                $walk($category->id, $prefix . '— ');
            }
        };

        $walk(null, '');

        return $options;
    }

    private function buildCategoryTrail(int $categoryId): string
    {
        $ids = [];
        $currentId = $categoryId;
        $guard = 0;

        while ($currentId !== null && $guard < 20) {
            $ids[] = $currentId;
            $currentId = Category::query()
                ->where('id', $currentId)
                ->value('parent_category_id');
            $guard++;
        }

        return implode(',', $ids);
    }

    /**
     * @return array<string, string>
     */
    private function statusOptions(): array
    {
        return [
            'review' => __('merchant_products.status.review'),
            'approved' => __('merchant_products.status.approved'),
            'rejected' => __('merchant_products.status.rejected'),
            'sold out' => __('merchant_products.status.sold_out'),
            'featured' => __('merchant_products.status.featured'),
        ];
    }

    /**
     * @return array<string, string>
     */
    private function currencyOptions(): array
    {
        return [
            'YER' => 'YER (ر.ي)',
            'SAR' => 'SAR (ر.س)',
            'USD' => 'USD ($)',
        ];
    }

    private function syncProductAttributes(Item $item, Request $request): void
    {
        $attributesPayload = $this->buildAttributePayload($request);
        $deliverySize = $request->input('delivery_size');

        if ($attributesPayload === [] && empty($deliverySize)) {
            return;
        }

        $subRequest = Request::create('', 'POST', [
            'attributes' => $attributesPayload,
            'delivery_size' => $deliverySize,
        ]);

        $subRequest->setUserResolver(fn () => $request->user());

        app(ItemPurchaseManagementController::class)->updateAttributes($subRequest, $item);
    }

    private function buildAttributePayload(Request $request): array
    {
        $payload = [];

        $colors = $this->normalizeColorRows($request);
        if ($colors->isNotEmpty()) {
            $payload[] = [
                'type' => 'color',
                'name' => __('merchant_products.attributes.color'),
                'required_for_checkout' => true,
                'affects_stock' => true,
                'values' => $colors->all(),
            ];
        }

        $sizes = $this->normalizeSimpleValues($request->input('sizes', []));
        if ($sizes->isNotEmpty()) {
            $payload[] = [
                'type' => 'size',
                'name' => __('merchant_products.attributes.size'),
                'required_for_checkout' => false,
                'affects_stock' => false,
                'values' => $sizes->all(),
            ];
        }

        $customOptions = $this->normalizeSimpleValues($request->input('custom_options', []));
        if ($customOptions->isNotEmpty()) {
            $payload[] = [
                'type' => 'custom',
                'name' => __('merchant_products.attributes.options'),
                'required_for_checkout' => false,
                'affects_stock' => false,
                'values' => $customOptions->all(),
            ];
        }

        return $payload;
    }

    private function normalizeColorRows(Request $request): Collection
    {
        $rows = $request->input('colors', []);
        if (! is_array($rows)) {
            return collect();
        }

        return collect($rows)
            ->map(function ($row) {
                if (! is_array($row)) {
                    return null;
                }

                $code = isset($row['code']) ? ColorFieldParser::normalizeCode($row['code']) : null;
                if ($code === null) {
                    return null;
                }

                $entry = ['code' => strtoupper($code)];

                $label = isset($row['label']) ? trim((string) $row['label']) : '';
                if ($label !== '') {
                    $entry['label'] = $label;
                }

                $quantity = $row['quantity'] ?? null;
                if ($quantity !== null && $quantity !== '') {
                    $intQty = (int) max(0, (int) $quantity);
                    $entry['quantity'] = $intQty;
                }

                return $entry;
            })
            ->filter()
            ->values();
    }

    private function normalizeSimpleValues(mixed $input): Collection
    {
        if (! is_array($input)) {
            return collect();
        }

        return collect($input)
            ->map(static function ($value) {
                if (is_array($value) && array_key_exists('value', $value)) {
                    $value = $value['value'];
                }

                $string = trim((string) $value);

                return $string === '' ? null : $string;
            })
            ->filter()
            ->unique()
            ->values();
    }

    /**
     * @return list<string>
     */
    private function defaultSizeCatalog(): array
    {
        return [
            'XS',
            'S',
            'M',
            'L',
            'XL',
            'XXL',
            '3XL',
            '4XL',
            '5XL',
            '6XL',
            '28',
            '30',
            '32',
            '34',
            '36',
            '38',
            '40',
            '42',
            '44',
            '46',
            '48',
            '50',
            '52',
            '54',
            '56',
            'Free Size',
        ];
    }
}
