<?php

namespace App\Http\Controllers\Api;

use App\Enums\StoreStatus as StoreStatusEnum;
use App\Http\Controllers\Controller;
use App\Models\Item;
use App\Models\Store;
use App\Models\StoreGatewayAccount;
use App\Models\StorePolicy;
use App\Models\StoreSetting;
use App\Models\StoreWorkingHour;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Storage;

use App\Services\Store\StoreStatusService;

class StorefrontController extends Controller
{
    public function __construct(
        private readonly StoreStatusService $storeStatusService,
    ) {
    }

    private const WEEKDAY_LABELS = [
        0 => 'الأحد',
        1 => 'الإثنين',
        2 => 'الثلاثاء',
        3 => 'الأربعاء',
        4 => 'الخميس',
        5 => 'الجمعة',
        6 => 'السبت',
    ];

    public function index(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'q' => ['nullable', 'string', 'max:191'],
            'page' => ['nullable', 'integer', 'min:1'],
            'per_page' => ['nullable', 'integer', 'min:5', 'max:50'],
        ]);

        $perPage = $validated['per_page'] ?? 12;
        $term = $validated['q'] ?? null;

        $stores = Store::query()
            ->where('status', StoreStatusEnum::APPROVED->value)
            ->when($term, static function ($query) use ($term) {
                $like = '%' . $term . '%';
                $query->where(static function ($inner) use ($like) {
                    $inner
                        ->where('name', 'like', $like)
                        ->orWhere('slug', 'like', $like)
                        ->orWhere('description', 'like', $like);
                });
            })
            ->with([
                'settings',
                'workingHours' => static fn ($query) => $query->orderBy('weekday'),
            ])
            ->latest('approved_at')
            ->paginate($perPage);

        $mapped = $stores->getCollection()->map(
            fn (Store $store) => $this->formatStoreSummary($store)
        );

        return $this->paginateResponse($stores, $mapped->values()->all());
    }

    public function show(Request $request, string $store): JsonResponse
    {
        $storeModel = $this->findStore($store);
        $storeModel->loadMissing([
            'settings',
            'workingHours' => static fn ($query) => $query->orderBy('weekday'),
            'policies' => static fn ($query) => $query->orderBy('display_order'),
        ]);

        return response()->json([
            'data' => $this->formatStoreSummary($storeModel, includeDetails: true),
        ]);
    }

    public function products(Request $request, string $store): JsonResponse
    {
        $storeModel = $this->findStore($store);

        $validated = $request->validate([
            'q' => ['nullable', 'string', 'max:191'],
            'page' => ['nullable', 'integer', 'min:1'],
            'per_page' => ['nullable', 'integer', 'min:5', 'max:50'],
        ]);

        $perPage = $validated['per_page'] ?? 12;
        $term = $validated['q'] ?? null;

        $items = Item::query()
            ->where('store_id', $storeModel->id)
            ->approved()
            ->withSum('stocks as total_stock', 'stock')
            ->withSum('stocks as total_reserved_stock', 'reserved_stock')
            ->when($term, static function ($query) use ($term) {
                $like = '%' . $term . '%';
                $query->where(static function ($inner) use ($like) {
                    $inner
                        ->where('name', 'like', $like)
                        ->orWhere('slug', 'like', $like)
                        ->orWhere('description', 'like', $like);
                });
            })
            ->latest('created_at')
            ->paginate($perPage);

        $mapped = $items->getCollection()->map(
            fn (Item $item) => $this->formatStoreItem($item)
        );

        return $this->paginateResponse($items, $mapped->values()->all(), [
            'store' => [
                'id' => $storeModel->id,
                'name' => $storeModel->name,
                'slug' => $storeModel->slug,
            ],
        ]);
    }

    public function manualBankAccounts(Request $request, string $store): JsonResponse
    {
        $storeModel = $this->findStore($store);

        $accounts = StoreGatewayAccount::query()
            ->where('store_id', $storeModel->id)
            ->where('is_active', true)
            ->whereHas('storeGateway', static fn ($query) => $query->where('is_active', true))
            ->with('storeGateway')
            ->orderBy('id')
            ->get();

        $data = $accounts->map(static function (StoreGatewayAccount $account) {
            $gateway = $account->storeGateway;

            return [
                'id' => $account->id,
                'beneficiary_name' => $account->beneficiary_name,
                'account_number' => $account->account_number,
                'gateway' => [
                    'id' => $gateway?->id,
                    'name' => $gateway?->name,
                    'logo_url' => $gateway?->logo_url,
                ],
            ];
        })->values()->all();

        return response()->json([
            'data' => $data,
        ]);
    }

    private function paginateResponse(
        LengthAwarePaginator $paginator,
        array $data,
        array $extra = []
    ): JsonResponse {
        return response()->json(array_merge([
            'data' => $data,
            'meta' => [
                'current_page' => $paginator->currentPage(),
                'per_page' => $paginator->perPage(),
                'total' => $paginator->total(),
                'last_page' => $paginator->lastPage(),
                'has_more' => $paginator->hasMorePages(),
            ],
        ], $extra));
    }

    private function formatStoreSummary(Store $store, bool $includeDetails = false): array
    {
        $settings = $store->settings;
        $statusPayload = $this->storeStatusService->resolve($store);

        $data = [
            'id' => $store->id,
            'name' => $store->name,
            'slug' => $store->slug,
            'description' => $includeDetails ? $store->description : null,
            'logo_url' => $this->resolveMediaUrl($store->logo_path),
            'banner_url' => $this->resolveMediaUrl($store->banner_path),
            'status' => $statusPayload,
            'contact' => $includeDetails ? $this->formatContactInfo($store, $settings) : null,
            'location' => $includeDetails ? $this->formatLocation($store) : null,
        ];

        if ($includeDetails) {
            $data['policies'] = $this->formatPolicies($store->policies ?? collect());
            $data['working_hours'] = $this->formatWorkingHours($store->workingHours ?? collect());
            $data['settings'] = [
                'allow_delivery' => $statusPayload['allow_delivery'],
                'allow_pickup' => $statusPayload['allow_pickup'],
                'allow_manual_payments' => $statusPayload['allow_manual_payments'],
                'allow_wallet' => $statusPayload['allow_wallet'],
                'allow_cod' => $statusPayload['allow_cod'],
                'min_order_amount' => $statusPayload['min_order_amount'],
                'checkout_notice' => $statusPayload['checkout_notice'],
            ];
        }

        return $data;
    }

    private function formatStoreItem(Item $item): array
    {
        return [
            'id' => $item->id,
            'name' => $item->name,
            'slug' => $item->slug,
            'description' => $item->description,
            'image' => $this->resolveMediaUrl($item->image),
            'price' => $item->price !== null ? (float) $item->price : null,
            'final_price' => (float) $item->final_price,
            'currency' => $item->currency ?? config('app.currency_code', 'YER'),
            'discount' => $item->discount_snapshot,
            'in_stock' => $this->hasAvailableStock($item),
            'created_at' => optional($item->created_at)->toIso8601String(),
        ];
    }

    private function hasAvailableStock(Item $item): bool
    {
        $total = (float) ($item->total_stock ?? 0);
        $reserved = (float) ($item->total_reserved_stock ?? 0);

        if ($total > 0) {
            return ($total - $reserved) > 0;
        }

        // If no stock records exist, treat as available.
        return true;
    }

    private function formatPolicies(Collection $policies): array
    {
        return $policies
            ->filter(static fn (StorePolicy $policy) => (bool) ($policy->is_active ?? true))
            ->map(static function (StorePolicy $policy) {
                return [
                    'type' => $policy->policy_type,
                    'title' => $policy->title,
                    'content' => $policy->content,
                    'is_required' => (bool) ($policy->is_required ?? false),
                ];
            })
            ->values()
            ->all();
    }

    private function formatWorkingHours(Collection $workingHours): array
    {
        $grouped = $workingHours
            ->map(static fn (StoreWorkingHour $hour) => [
                'weekday' => $hour->weekday,
                'label' => self::WEEKDAY_LABELS[$hour->weekday] ?? $hour->weekday,
                'is_open' => (bool) $hour->is_open,
                'opens_at' => $hour->opens_at,
                'closes_at' => $hour->closes_at,
            ])
            ->keyBy('weekday');

        $result = [];
        for ($day = 0; $day < 7; $day++) {
            $entry = $grouped->get($day, [
                'weekday' => $day,
                'label' => self::WEEKDAY_LABELS[$day] ?? $day,
                'is_open' => false,
                'opens_at' => null,
                'closes_at' => null,
            ]);

            $result[] = $entry;
        }

        return $result;
    }

    private function formatContactInfo(Store $store, ?StoreSetting $settings): array
    {
        return [
            'email' => $store->contact_email,
            'phone' => $store->contact_phone,
            'whatsapp' => $store->contact_whatsapp,
            'checkout_notice' => $settings?->checkout_notice,
        ];
    }

    private function formatLocation(Store $store): ?array
    {
        if (! $store->location_address && ! $store->location_city && ! $store->location_latitude) {
            return null;
        }

        return [
            'address' => $store->location_address,
            'city' => $store->location_city,
            'state' => $store->location_state,
            'country' => $store->location_country,
            'latitude' => $store->location_latitude,
            'longitude' => $store->location_longitude,
        ];
    }

    private function resolveMediaUrl(?string $path): ?string
    {
        if ($path === null || trim($path) === '') {
            return null;
        }

        if (preg_match('#^(?:https?:)?//#i', $path) === 1 || str_starts_with($path, 'data:')) {
            return $path;
        }

        try {
            return Storage::url($path);
        } catch (\Throwable) {
            return url($path);
        }
    }

    private function findStore(string $key): Store
    {
        $query = Store::query()
            ->where('status', StoreStatusEnum::APPROVED->value);

        if (is_numeric($key)) {
            $query->where('id', (int) $key);
        } else {
            $query->where('slug', $key);
        }

        return $query->firstOrFail();
    }
}
