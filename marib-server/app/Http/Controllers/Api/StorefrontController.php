<?php

namespace App\Http\Controllers\Api;

use App\Enums\StoreStatus as StoreStatusEnum;
use App\Http\Controllers\Controller;
use App\Models\Item;
use App\Models\Store;
use App\Models\StoreFollower;
use App\Models\StoreGatewayAccount;
use App\Models\StorePolicy;
use App\Models\StoreReview;
use App\Models\StoreSetting;
use App\Models\StoreWorkingHour;
use App\Models\User;
use App\Models\UserFcmToken;
use App\Services\NotificationService;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\PersonalAccessToken;
use Throwable;

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
        $currentUser = $this->resolveCurrentUser($request);
        $viewerId = $this->resolveViewerId($request, $currentUser);
        $validated = $request->validate([
            'q' => ['nullable', 'string', 'max:191'],
            'page' => ['nullable', 'integer', 'min:1'],
            // Allow larger page sizes; we will override small values to return all stores.
            'per_page' => ['nullable', 'integer', 'min:1', 'max:1000'],
        ]);

        $requestedPerPage = $validated['per_page'] ?? null;
        $term = $validated['q'] ?? null;

        $query = Store::query()
            ->where('status', StoreStatusEnum::APPROVED->value)
            ->withCount('followers')
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
            ->latest('approved_at');

        // Always return all approved stores (capped) to avoid client-side defaults like 10.
        $totalStores = (int) (clone $query)->count();
        $effectivePerPage = $totalStores;
        if ($requestedPerPage !== null && $requestedPerPage > 0) {
            // If the client requests fewer than available, still return all to avoid the 10-store cap.
            $effectivePerPage = max($requestedPerPage, $totalStores);
        }
        $effectivePerPage = max(1, min($effectivePerPage, 1000));

        $stores = $query->paginate($effectivePerPage);

        $mapped = $stores->getCollection()->map(
            fn (Store $store) => $this->formatStoreSummary(
                $store,
                currentUser: $currentUser,
                viewerId: $viewerId,
            )
        );

        return $this->paginateResponse($stores, $mapped->values()->all());
    }

    public function show(Request $request, string $store): JsonResponse
    {
        $currentUser = $this->resolveCurrentUser($request);
        $storeModel = $this->resolveStoreOrResponse($store);
        if ($storeModel === null) {
            return response()->json(['message' => 'Store not found'], 404);
        }
        $storeModel->loadMissing([
            'settings',
            'workingHours' => static fn ($query) => $query->orderBy('weekday'),
            'policies' => static fn ($query) => $query->orderBy('display_order'),
        ]);
        $storeModel->loadCount('followers');

        return response()->json([
            'data' => $this->formatStoreSummary(
                $storeModel,
                includeDetails: true,
                currentUser: $currentUser,
                viewerId: $this->resolveViewerId($request, $currentUser),
            ),
        ]);
    }

    public function products(Request $request, string $store): JsonResponse
    {
        $storeModel = $this->resolveStoreOrResponse($store);
        if ($storeModel === null) {
            return response()->json(['message' => 'Store not found'], 404);
        }

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
        $storeModel = $this->resolveStoreOrResponse($store);
        if ($storeModel === null) {
            return response()->json(['message' => 'Store not found'], 404);
        }

        return response()->json([
            'data' => $this->formatStoreManualBanks($storeModel),
        ]);
    }

    public function follow(Request $request, string $store): JsonResponse
    {
        $storeModel = $this->resolveStoreOrResponse($store, includeInactive: true);
        if ($storeModel === null) {
            return response()->json(['message' => 'Store not found'], 404);
        }
        $user = $request->user();

        if (!$user) {
            return response()->json(['message' => 'Unauthenticated'], 401);
        }

        $exists = StoreFollower::query()
            ->where('store_id', $storeModel->getKey())
            ->where('user_id', $user->getKey())
            ->exists();

        if (!$exists) {
            DB::transaction(static function () use ($storeModel, $user): void {
                StoreFollower::create([
                    'store_id' => $storeModel->getKey(),
                    'user_id' => $user->getKey(),
                ]);
            });
            $this->notifyStoreOwnerOfFollowerSafe($storeModel, $user);
        }

        $followersCount = $storeModel->followers()->count();
        $isFollowing = StoreFollower::query()
            ->where('store_id', $storeModel->getKey())
            ->where('user_id', $user->getKey())
            ->exists();
        $this->notifyFollowerConfirmationSafe($user, $storeModel);

        return response()->json([
            'data' => [
                'is_following' => $isFollowing,
                'followers_count' => $followersCount,
            ],
        ]);
    }

    public function followStatus(Request $request, string $store): JsonResponse
    {
        $storeModel = $this->resolveStoreOrResponse($store, includeInactive: true);
        if ($storeModel === null) {
            return response()->json(['message' => 'Store not found'], 404);
        }

        $currentUser = $this->resolveCurrentUser($request);
        $viewerId = $this->resolveViewerId($request, $currentUser);
        if ($viewerId === null) {
            return response()->json(['message' => 'Unauthenticated'], 401);
        }

        $isFollowing = StoreFollower::query()
            ->where('store_id', $storeModel->getKey())
            ->where('user_id', $viewerId)
            ->exists();

        $followersCount = $storeModel->followers()->count();

        return response()->json([
            'data' => [
                'is_following' => $isFollowing,
                'followers_count' => $followersCount,
            ],
        ]);
    }

    public function unfollow(Request $request, string $store): JsonResponse
    {
        $storeModel = $this->resolveStoreOrResponse($store, includeInactive: true);
        if ($storeModel === null) {
            return response()->json(['message' => 'Store not found'], 404);
        }
        $user = $request->user();

        if (!$user) {
            return response()->json(['message' => 'Unauthenticated'], 401);
        }

        StoreFollower::query()
            ->where('store_id', $storeModel->getKey())
            ->where('user_id', $user->getKey())
            ->delete();

        $followersCount = $storeModel->followers()->count();
        $isFollowing = StoreFollower::query()
            ->where('store_id', $storeModel->getKey())
            ->where('user_id', $user->getKey())
            ->exists();

        $this->notifyUnfollowConfirmationSafe($user, $storeModel);

        return response()->json([
            'data' => [
                'is_following' => $isFollowing,
                'followers_count' => $followersCount,
            ],
        ]);
    }

    public function reviews(Request $request, string $store): JsonResponse
    {
        $storeModel = $this->resolveStoreOrResponse($store, includeInactive: true);
        if ($storeModel === null) {
            return response()->json(['message' => 'Store not found'], 404);
        }

        $validated = $request->validate([
            'page' => ['nullable', 'integer', 'min:1'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:50'],
        ]);

        $currentUser = $this->resolveCurrentUser($request);
        $viewerId = $this->resolveViewerId($request, $currentUser);
        $perPage = $validated['per_page'] ?? 10;

        $reviews = StoreReview::query()
            ->where('store_id', $storeModel->getKey())
            ->with(['user:id,name,profile'])
            ->latest('created_at')
            ->paginate($perPage);

        $formatted = $reviews->getCollection()
            ->map(fn (StoreReview $review) => $this->formatStoreReview($review))
            ->values()
            ->all();

        $summary = $this->buildStoreReviewSummary($storeModel->getKey());
        $summary['can_review'] = $viewerId !== null
            ? !$this->userHasStoreReview($storeModel->getKey(), $viewerId)
            : false;
        $summary['my_review'] = $viewerId !== null
            ? $this->formatStoreReviewIfExists($this->getUserStoreReview($storeModel->getKey(), $viewerId))
            : null;

        return $this->paginateResponse($reviews, $formatted, [
            'store' => [
                'id' => $storeModel->getKey(),
                'name' => $storeModel->name,
                'slug' => $storeModel->slug,
            ],
            'summary' => $summary,
        ]);
    }

    public function addReview(Request $request, string $store): JsonResponse
    {
        $storeModel = $this->resolveStoreOrResponse($store, includeInactive: true);
        if ($storeModel === null) {
            return response()->json(['message' => 'Store not found'], 404);
        }

        /** @var User|null $user */
        $user = $request->user();
        if (!$user) {
            return response()->json(['message' => 'Unauthenticated'], 401);
        }

        $validated = $request->validate([
            'rating' => ['required', 'integer', 'min:1', 'max:5'],
            'comment' => ['nullable', 'string', 'max:2000'],
            'attachments' => ['nullable', 'array'],
            'attachments.*' => ['nullable', 'string', 'max:2048'],
        ]);

        if ($this->userHasStoreReview($storeModel->getKey(), $user->getKey())) {
            return response()->json([
                'message' => __('You already reviewed this store.'),
            ], 422);
        }

        $attachments = $this->normalizeAttachments($validated['attachments'] ?? null);

        $review = StoreReview::create([
            'store_id' => $storeModel->getKey(),
            'user_id' => $user->getKey(),
            'rating' => (int) $validated['rating'],
            'comment' => $validated['comment'] ?? null,
            'attachments' => $attachments,
        ]);

        $summary = $this->buildStoreReviewSummary($storeModel->getKey());
        $summary['can_review'] = false;
        $summary['my_review'] = $this->formatStoreReview($review->loadMissing('user:id,name,profile'));

        $this->notifyStoreOwnerAboutStoreReviewSafe($storeModel, $review, $user);

        return response()->json([
            'data' => [
                'review' => $this->formatStoreReview($review),
                'summary' => $summary,
            ],
        ], 201);
    }

    public function updateReview(Request $request, string $store): JsonResponse
    {
        $storeModel = $this->resolveStoreOrResponse($store, includeInactive: true);
        if ($storeModel === null) {
            return response()->json(['message' => 'Store not found'], 404);
        }

        /** @var User|null $user */
        $user = $request->user();
        if (!$user) {
            return response()->json(['message' => 'Unauthenticated'], 401);
        }

        $validated = $request->validate([
            'rating' => ['required', 'integer', 'min:1', 'max:5'],
            'comment' => ['nullable', 'string', 'max:2000'],
            'attachments' => ['nullable', 'array'],
            'attachments.*' => ['nullable', 'string', 'max:2048'],
        ]);

        $review = $this->getUserStoreReview($storeModel->getKey(), $user->getKey());
        if (!$review) {
            return response()->json(['message' => 'Review not found'], 404);
        }

        $attachments = $this->normalizeAttachments($validated['attachments'] ?? null);

        $review->fill([
            'rating' => (int) $validated['rating'],
            'comment' => $validated['comment'] ?? null,
            'attachments' => $attachments,
        ])->save();

        $summary = $this->buildStoreReviewSummary($storeModel->getKey());
        $summary['can_review'] = false;
        $summary['my_review'] = $this->formatStoreReview($review->loadMissing('user:id,name,profile'));

        return response()->json([
            'data' => [
                'review' => $this->formatStoreReview($review),
                'summary' => $summary,
            ],
        ]);
    }

    public function deleteReview(Request $request, string $store): JsonResponse
    {
        $storeModel = $this->resolveStoreOrResponse($store, includeInactive: true);
        if ($storeModel === null) {
            return response()->json(['message' => 'Store not found'], 404);
        }

        /** @var User|null $user */
        $user = $request->user();
        if (!$user) {
            return response()->json(['message' => 'Unauthenticated'], 401);
        }

        $review = $this->getUserStoreReview($storeModel->getKey(), $user->getKey());
        if (!$review) {
            return response()->json(['message' => 'Review not found'], 404);
        }

        $review->delete();

        $summary = $this->buildStoreReviewSummary($storeModel->getKey());
        $summary['can_review'] = true;
        $summary['my_review'] = null;

        return response()->json([
            'data' => [
                'summary' => $summary,
            ],
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

    private function formatStoreSummary(Store $store, bool $includeDetails = false, ?User $currentUser = null, ?int $viewerId = null): array
    {
        $settings = $store->settings;
        $statusPayload = $this->storeStatusService->resolve($store);
        $currentUser = $currentUser ?? auth('sanctum')->user() ?? Auth::user();
        $followersCount = $store->followers_count ?? $store->followers()->count();
        $ratingsAverage = StoreReview::query()
            ->where('store_id', $store->getKey())
            ->avg('rating');
        $ratingsCount = StoreReview::query()
            ->where('store_id', $store->getKey())
            ->count();
        // Prefer the authenticated user if available; fall back to viewerId header/query.
        $effectiveViewerId = $currentUser?->getKey() ?? $viewerId;
        $isFollowed = $effectiveViewerId
            ? StoreFollower::query()
                ->where('store_id', $store->getKey())
                ->where('user_id', $effectiveViewerId)
                ->exists()
            : false;

        $data = [
            'id' => $store->id,
            'name' => $store->name,
            'slug' => $store->slug,
            'description' => $includeDetails ? $store->description : null,
            'logo_url' => $this->resolveMediaUrl($store->logo_path),
            'banner_url' => $this->resolveMediaUrl($store->banner_path)
                ?? $this->resolveMediaUrl($store->logo_path),
            'status' => $statusPayload,
            'followers_count' => $followersCount,
            'is_followed' => $isFollowed,
            'ratings_average' => $ratingsAverage !== null ? round((float) $ratingsAverage, 2) : null,
            'ratings_count' => (int) $ratingsCount,
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
            $data['manual_banks'] = $this->formatStoreManualBanks($store);
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
            ->where('status', StoreStatusEnum::APPROVED->value)
            ->withCount('followers')
            ->where(function ($q) use ($key) {
                if (is_numeric($key)) {
                    $id = (int) $key;
                    $q->where('id', $id)
                        ->orWhere('user_id', $id)
                        ->orWhere('slug', $key);
                } else {
                    $q->where('slug', $key);
                }
            });

        return $query->firstOrFail();
    }

    private function resolveStoreOrResponse(string $key, bool $includeInactive = false): ?Store
    {
        try {
            return $includeInactive ? $this->findStoreAnyStatus($key) : $this->findStore($key);
        } catch (ModelNotFoundException) {
            return null;
        }
    }

    private function findStoreAnyStatus(string $key): Store
    {
        $query = Store::query()
            ->withCount('followers')
            ->where(function ($q) use ($key) {
                if (is_numeric($key)) {
                    $id = (int) $key;
                    $q->where('id', $id)
                        ->orWhere('user_id', $id)
                        ->orWhere('slug', $key);
                } else {
                    $q->where('slug', $key);
                }
            });

        return $query->firstOrFail();
    }

    private function resolveCurrentUser(Request $request): ?User
    {
        $user = $request->user();
        if ($user instanceof User) {
            return $user;
        }

        $sanctum = Auth::guard('sanctum');
        if (method_exists($sanctum, 'setRequest')) {
            $sanctum->setRequest($request);
        }

        $user = $sanctum->user();
        if ($user instanceof User) {
            return $user;
        }

        $bearer = $request->bearerToken();
        if (is_string($bearer) && $bearer !== '') {
            $token = PersonalAccessToken::findToken($bearer);
            if ($token && $token->tokenable instanceof User) {
                return $token->tokenable;
            }
        }

        return null;
    }

    private function resolveViewerId(Request $request, ?User $currentUser = null): ?int
    {
        if ($currentUser instanceof User) {
            return $currentUser->getKey();
        }

        $headerId = $request->header('X-User-Id');
        if (is_string($headerId)) {
            $headerId = trim($headerId);
        }
        if (is_numeric($headerId)) {
            $id = (int) $headerId;
            return $id > 0 ? $id : null;
        }

        $queryId = $request->input('viewer_id');
        if (is_string($queryId)) {
            $queryId = trim($queryId);
        }
        if (is_numeric($queryId)) {
            $id = (int) $queryId;
            return $id > 0 ? $id : null;
        }

        $userIdInput = $request->input('user_id');
        if (is_string($userIdInput)) {
            $userIdInput = trim($userIdInput);
        }
        if (is_numeric($userIdInput)) {
            $id = (int) $userIdInput;
            return $id > 0 ? $id : null;
        }

        return null;
    }

    private function notifyStoreOwnerOfFollower(Store $store, User $follower): void
    {
        $ownerId = $store->user_id;
        if ($ownerId === null || $ownerId === $follower->getKey()) {
            return;
        }

        $tokens = UserFcmToken::query()
            ->where('user_id', $ownerId)
            ->pluck('fcm_token')
            ->filter()
            ->values()
            ->all();

        if ($tokens === []) {
            return;
        }

        $title = __('متابع جديد لمتجرك');
        $body = __(':user قام بمتابعة متجرك :store', [
            'user' => $follower->name ?? __('مستخدم'),
            'store' => $store->name,
        ]);

        NotificationService::sendFcmNotification(
            $tokens,
            $title,
            $body,
            'store_follow',
            [
                'store_id' => $store->getKey(),
                'follower_id' => $follower->getKey(),
                'store_name' => $store->name,
            ]
        );
    }

    private function notifyUnfollowConfirmationSafe(User $follower, Store $store): void
    {
        $tokens = UserFcmToken::query()
            ->where('user_id', $follower->getKey())
            ->pluck('fcm_token')
            ->filter()
            ->values()
            ->all();

        if ($tokens === []) {
            return;
        }

        $title = __('طھظ…طھ ط¥ظ„ط؛ط§ط، طظ…طھط§ط¨ط¹ط© ط§ظ„ظ…طھط¬ط±');
        $body = __('ظ„ظ‚ط¯ ط£ظ„ط؛ظٹطھ ظ…طھط§ط¨ط¹ط© ط§ظ„ظ…طھط¬ط± :store. ظ„ظ† طھطµظ„ظƒ ط¥ط´ط¹ط§ط±ط§طھ ط¬ط¯ظٹط© ظ…ظ†ظ‡.', [
            'store' => $store->name,
        ]);

        NotificationService::sendFcmNotification(
            $tokens,
            $title,
            $body,
            'store_unfollow_confirmation',
            [
                'store_id' => $store->getKey(),
                'store_name' => $store->name,
            ]
        );
    }

    private function notifyFollowerConfirmation(User $follower, Store $store): void
    {
        $tokens = UserFcmToken::query()
            ->where('user_id', $follower->getKey())
            ->pluck('fcm_token')
            ->filter()
            ->values()
            ->all();

        if ($tokens === []) {
            return;
        }

        $title = __('تمت متابعة المتجر');
        $body = __('أنت تتابع المتجر :store. ستصلك إشعارات بكل جديد.', [
            'store' => $store->name,
        ]);

        NotificationService::sendFcmNotification(
            $tokens,
            $title,
            $body,
            'store_follow_confirmation',
            [
                'store_id' => $store->getKey(),
                'store_name' => $store->name,
            ]
        );
    }

                private function notifyStoreOwnerOfFollowerSafe(Store $store, User $follower): void
    {
        $ownerId = $store->user_id;
        if ($ownerId === null || $ownerId === $follower->getKey()) {
            return;
        }

        $tokens = UserFcmToken::query()
            ->where('user_id', $ownerId)
            ->pluck('fcm_token')
            ->filter()
            ->values()
            ->all();

        if ($tokens === []) {
            return;
        }

        $title = 'تمت متابعة جديدة لمتجرك';
        $body = sprintf(
            '%s قام بمتابعة متجرك %s',
            $follower->name ?? 'مستخدم',
            $store->name
        );

        NotificationService::sendFcmNotification(
            $tokens,
            $title,
            $body,
            'store_follow',
            [
                'store_id' => $store->getKey(),
                'follower_id' => $follower->getKey(),
                'store_name' => $store->name,
            ]
        );
    }

    private function notifyFollowerConfirmationSafe(User $follower, Store $store): void
    {
        $tokens = UserFcmToken::query()
            ->where('user_id', $follower->getKey())
            ->pluck('fcm_token')
            ->filter()
            ->values()
            ->all();

        if ($tokens === []) {
            return;
        }

        $title = 'تمت متابعة المتجر';
        $body = sprintf(
            'أنت تتابع المتجر %s. ستصلك إشعارات بكل جديد.',
            $store->name
        );

        NotificationService::sendFcmNotification(
            $tokens,
            $title,
            $body,
            'store_follow_confirmation',
            [
                'store_id' => $store->getKey(),
                'store_name' => $store->name,
            ]
        );
    }

    private function formatStoreReview(StoreReview $review): array
    {
        $user = $review->relationLoaded('user') ? $review->user : null;

        return [
            'id' => $review->getKey(),
            'store_id' => $review->store_id,
            'user_id' => $review->user_id,
            'rating' => (int) $review->rating,
            'comment' => $review->comment,
            'attachments' => $review->attachments ?? [],
            'created_at' => optional($review->created_at)->toIso8601String(),
            'updated_at' => optional($review->updated_at)->toIso8601String(),
            'user' => $user ? [
                'id' => $user->getKey(),
                'name' => $user->name,
                'profile' => $this->resolveMediaUrl($user->profile ?? null),
            ] : null,
        ];
    }

    private function formatStoreReviewIfExists(?StoreReview $review): ?array
    {
        return $review ? $this->formatStoreReview($review) : null;
    }

    private function buildStoreReviewSummary(int $storeId): array
    {
        $average = StoreReview::query()
            ->where('store_id', $storeId)
            ->avg('rating');

        $total = StoreReview::query()
            ->where('store_id', $storeId)
            ->count();

        return [
            'average_rating' => $average !== null ? round((float) $average, 2) : null,
            'total_reviews' => (int) $total,
            'distribution' => $this->getStoreReviewDistribution($storeId),
        ];
    }

    private function getStoreReviewDistribution(int $storeId): array
    {
        $distribution = array_fill(1, 5, 0);

        $rows = StoreReview::query()
            ->select('rating', DB::raw('count(*) as total'))
            ->where('store_id', $storeId)
            ->groupBy('rating')
            ->get();

        foreach ($rows as $row) {
            $rating = (int) $row->rating;
            if ($rating >= 1 && $rating <= 5) {
                $distribution[$rating] = (int) $row->total;
            }
        }

        return $distribution;
    }

    private function normalizeAttachments(mixed $attachments): ?array
    {
        if (!is_array($attachments)) {
            return null;
        }

        $clean = [];
        foreach ($attachments as $value) {
            if (is_string($value)) {
                $trimmed = trim($value);
                if ($trimmed !== '') {
                    $clean[] = $trimmed;
                }
            }
        }

        return $clean === [] ? null : array_values($clean);
    }

    private function userHasStoreReview(int $storeId, int $userId): bool
    {
        return StoreReview::query()
            ->where('store_id', $storeId)
            ->where('user_id', $userId)
            ->exists();
    }

    private function getUserStoreReview(int $storeId, int $userId): ?StoreReview
    {
        return StoreReview::query()
            ->where('store_id', $storeId)
            ->where('user_id', $userId)
            ->with('user:id,name,profile')
            ->first();
    }

    private function notifyStoreOwnerAboutStoreReviewSafe(Store $store, StoreReview $review, User $reviewer): void
    {
        $ownerId = $store->user_id;
        if ($ownerId === null || $ownerId === $reviewer->getKey()) {
            return;
        }

        $tokens = UserFcmToken::query()
            ->where('user_id', $ownerId)
            ->pluck('fcm_token')
            ->filter()
            ->values()
            ->all();

        if ($tokens === []) {
            return;
        }

        $title = __('طھظ‚ظٹظٹظ… ط¬ط¯ظٹط¯ ظ„ظ„ظ…طھط¬ط±');
        $body = __(':user ظ‚ط§ظ… ط¨طھط±ظƒ طھظ‚ظٹظٹظ…ظ‡ ظ„ظ„ظ…طھط¬ط± :store', [
            'user' => $reviewer->name ?? __('ظ…ط³طھط®ط¯ظ…'),
            'store' => $store->name,
        ]);

        NotificationService::sendFcmNotification(
            $tokens,
            $title,
            $body,
            'store_review',
            [
                'store_id' => $store->getKey(),
                'review_id' => $review->getKey(),
                'rating' => $review->rating,
            ]
        );
    }

    private function formatStoreManualBanks(Store $store): array
    {
        $accounts = StoreGatewayAccount::query()
            ->where('store_id', $store->getKey())
            ->where('is_active', true)
            ->whereHas('storeGateway', static fn ($query) => $query->where('is_active', true))
            ->with('storeGateway')
            ->orderBy('id')
            ->get();

        return $accounts->map(static function (StoreGatewayAccount $account) {
            $gateway = $account->storeGateway;

            return array_filter([
                'store_gateway_account_id' => $account->getKey(),
                'store_gateway_id' => $account->store_gateway_id,
                'gateway' => $gateway ? [
                    'id' => $gateway->getKey(),
                    'name' => $gateway->name,
                    'logo_url' => $gateway->logo_url,
                ] : null,
                'beneficiary_name' => $account->beneficiary_name,
                'account_number' => $account->account_number,
            ], static fn ($value) => $value !== null && $value !== '');
        })->values()->all();
    }
}
