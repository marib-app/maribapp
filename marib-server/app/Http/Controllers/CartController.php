<?php

namespace App\Http\Controllers;

use App\Models\CartItem;
use App\Models\Category;
use App\Models\Item;
use App\Models\User;
use App\Services\DepartmentReportService;
use Illuminate\Http\JsonResponse;
use App\Services\CartShippingQuoteService;
use App\Services\TelemetryService;
use App\Models\CartCouponSelection;
use App\Services\DepartmentNoticeService;
use App\Services\DepartmentSupportService;
use Illuminate\Support\Arr;
use App\Services\DepartmentPolicyService;

use App\Models\Coupon;
use Illuminate\Support\Str;
use Illuminate\Http\Request;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Config;
use Illuminate\Support\Facades\Cache;

use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;
use App\Services\OrderCheckoutService;
use Carbon\Carbon;

class CartController extends Controller
{

    public function __construct(
        private readonly DepartmentReportService $departmentReportService,
        private readonly CartShippingQuoteService $cartShippingQuoteService,
        private readonly TelemetryService $telemetry,
        private readonly DepartmentNoticeService $departmentNoticeService,
        private readonly DepartmentPolicyService $departmentPolicyService,

        private readonly DepartmentSupportService $departmentSupportService,
    ) {


    }

    public function index(Request $request): JsonResponse
    {
        $user = $request->user();
        $cartItems = $this->userCartItems($user);
        $this->recordCartTelemetry('cart.view_cart', $user, $cartItems);

        $includeCheckout = $this->shouldIncludeCheckout($request);

        return $this->buildResponse($user, $cartItems, __('تم جلب السلة بنجاح.'), $includeCheckout);
    
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $this->validateAddOrUpdateRequest($request);

        if (! empty($validated['department']) && ! empty($validated['section']) && $validated['department'] !== $validated['section']) {
            return $this->validationError(__('يجب أن يتطابق القسم المحدد مع حقل section.'), 422);
        }

        $item = Item::select(['id', 'price', 'category_id', 'interface_type', 'all_category_ids', 'currency'])
            ->find($validated['item_id']);

        if (! $item) {
            return $this->validationError(__('العنصر المطلوب غير متاح.'), 422);
        }


        $user = $request->user();


        $department = $this->resolveDepartment($item, $validated);

        $itemDepartment = $this->resolveItemDepartment($item);

        if (! $department && $itemDepartment) {
            $department = $itemDepartment;
        }

        if (! $department) {
            $existingDepartment = $this->existingCartDepartment($user);

            if ($existingDepartment && ($itemDepartment === null || $itemDepartment === $existingDepartment)) {
                $department = $existingDepartment;
            }
        }


        if (! $department) {
            return $this->validationError(__('تعذر تحديد القسم للسلة.'), 422);
        }

        if (! in_array($department, Config::get('cart.departments', []), true)) {
            return $this->validationError(__('القسم المحدد غير مدعوم.'), 422);
        }

        if (! $this->itemBelongsToDepartment($item, $department)) {
            return $this->validationError(__('العنصر لا ينتمي إلى هذا القسم.'), 422);
        }


        $hasDifferentDepartment = $user->cartItems()
            ->where('department', '!=', $department)
            ->exists();

        if ($hasDifferentDepartment) {
            return $this->validationError(__('لا يمكن أن تحتوي السلة على أكثر من قسم واحد في نفس الوقت.'), 409);
        }

        $quantity = (int) $validated['quantity'];

        $cartItem = CartItem::firstOrNew([
            'user_id' => $user->id,
            'item_id' => $item->id,
            

            'variant_id' => $validated['variant_id'] ?? null,

            'department' => $department,
        ]);



        $normalizedCurrency = array_key_exists('currency', $validated)
            ? $this->normalizeCurrency($validated['currency'])
            : ($cartItem->exists && $cartItem->currency
                ? $this->normalizeCurrency($cartItem->currency)
                : $this->normalizeCurrency($item->currency ?? $this->defaultCurrency()));

        $existingCurrencies = $user->cartItems()
            ->when($cartItem->exists, static fn ($query) => $query->where('id', '!=', $cartItem->getKey()))
            ->pluck('currency')
            ->map(fn (?string $currency) => $this->normalizeCurrency($currency))
            ->filter()
            ->unique()
            ->values();

        if ($existingCurrencies->isNotEmpty()) {
            if ($response = $this->ensureSingleCurrency($existingCurrencies, $normalizedCurrency)) {
                return $response;
            }
        }


        if ($cartItem->exists) {
            $cartItem->quantity += $quantity;
        } else {
            $cartItem->quantity = $quantity;


        }

        $cartItem->unit_price = (float) ($validated['unit_price'] ?? $item->price);

        if (array_key_exists('unit_price_locked', $validated)) {
            $cartItem->unit_price_locked = $validated['unit_price_locked'] !== null
                ? (float) $validated['unit_price_locked']
                : null;
        } elseif (! $cartItem->unit_price_locked) {
            $cartItem->unit_price_locked = (float) $cartItem->unit_price;
        }

        if (array_key_exists('currency', $validated) || ! $cartItem->currency) {
            $cartItem->currency = $normalizedCurrency;


        }

        if (array_key_exists('attributes', $validated)) {
            $cartItem->attributes = $validated['attributes'];
        }

        if (array_key_exists('stock_snapshot', $validated)) {
            $cartItem->stock_snapshot = $validated['stock_snapshot'];
        }


        $cartItem->save();
        $this->cartShippingQuoteService->clearCachedQuotes($user);


        $cartItems = $this->userCartItems($user);

        $this->recordCartTelemetry('cart.add_to_cart', $user, $cartItems, [
            'item_id' => $item->getKey(),
            'cart_item_id' => $cartItem->getKey(),
            'quantity' => $cartItem->quantity,
            'added_quantity' => $quantity,
        ]);
        $includeCheckout = $this->shouldIncludeCheckout($request);

        return $this->buildResponse(
            $user,
            $cartItems,
            
            __('تم إضافة العنصر إلى السلة بنجاح.'),
            $includeCheckout
        );
    }

    public function updateQuantity(Request $request, int $cartItemId): JsonResponse
    {
        $validated = $request->validate([
            'quantity' => ['required', 'integer', 'min:1'],
            'variant_id' => ['nullable', 'integer'],
            'attributes' => ['nullable', 'array'],
            'stock_snapshot' => ['nullable', 'array'],
            'unit_price' => ['nullable', 'numeric', 'min:0'],
            'unit_price_locked' => ['nullable', 'numeric', 'min:0'],
            'currency' => ['nullable', 'string', 'size:3'],

        ]);

        $user = $request->user();
        $cartItem = CartItem::where('user_id', $user->id)->find($cartItemId);


        if (! $cartItem) {
            return $this->validationError(__('العنصر غير موجود في سلة المشتريات.'), 422);
        }



        $normalizedCurrency = array_key_exists('currency', $validated)
            ? $this->normalizeCurrency($validated['currency'])
            : $this->normalizeCurrency($cartItem->currency ?? null);

        $existingCurrencies = $user->cartItems()
            ->where('id', '!=', $cartItem->getKey())
            ->pluck('currency')
            ->map(fn (?string $currency) => $this->normalizeCurrency($currency))
            ->filter()
            ->unique()
            ->values();

        if ($existingCurrencies->isNotEmpty()) {
            if ($response = $this->ensureSingleCurrency($existingCurrencies, $normalizedCurrency)) {
                return $response;
            }
        }





        if (array_key_exists('variant_id', $validated) && $validated['variant_id'] !== $cartItem->variant_id) {
            $conflict = CartItem::query()
                ->where('user_id', $user->id)
                ->where('item_id', $cartItem->item_id)
                ->where('department', $cartItem->department)
                ->where('variant_id', $validated['variant_id'])
                ->where('id', '!=', $cartItem->id)
                ->exists();

            if ($conflict) {
                return $this->validationError(__('لا يمكن تحديث المتغير المحدد لأنه موجود بالفعل في السلة.'), 409);
            }

            $cartItem->variant_id = $validated['variant_id'];
        }


        $cartItem->quantity = (int) $validated['quantity'];


        if (array_key_exists('attributes', $validated)) {
            $cartItem->attributes = $validated['attributes'];
        }

        if (array_key_exists('stock_snapshot', $validated)) {
            $cartItem->stock_snapshot = $validated['stock_snapshot'];
        }

        if (array_key_exists('unit_price', $validated)) {
            $cartItem->unit_price = $validated['unit_price'] !== null
                ? (float) $validated['unit_price']
                : null;
        }

        if (array_key_exists('unit_price_locked', $validated)) {
            $cartItem->unit_price_locked = $validated['unit_price_locked'] !== null
                ? (float) $validated['unit_price_locked']
                : null;
        }

        if (array_key_exists('currency', $validated)) {
            $cartItem->currency = $normalizedCurrency;
        } elseif ($cartItem->currency) {
            $cartItem->currency = $this->normalizeCurrency($cartItem->currency);
        
        }


        $cartItem->save();
        $this->cartShippingQuoteService->clearCachedQuotes($user);

        $cartItems = $this->userCartItems($user);

        $this->recordCartTelemetry('cart.update_cart', $user, $cartItems, [
            'cart_item_id' => $cartItem->getKey(),
            'item_id' => $cartItem->item_id,
            'quantity' => $cartItem->quantity,
        ]);

        $includeCheckout = $this->shouldIncludeCheckout($request);

        return $this->buildResponse(
            $user,
            $cartItems,
            
            __('تم تحديث الكمية بنجاح.'),
            $includeCheckout
        );
    }

    public function destroy(Request $request, int $cartItemId): JsonResponse
    {
        $user = $request->user();
        $cartItem = CartItem::where('user_id', $user->id)->find($cartItemId);


        if (! $cartItem) {
            return $this->validationError(__('العنصر غير موجود في سلة المشتريات.'), 422);
        }

        $cartItem->delete();
        $this->cartShippingQuoteService->clearCachedQuotes($user);
        $includeCheckout = $this->shouldIncludeCheckout($request);

        return $this->buildResponse(
            $user,
            $this->userCartItems($user),
            
            
            __('تم حذف العنصر من السلة.'),
            $includeCheckout
        );
    }

    public function clear(Request $request): JsonResponse
    {
        $departments = Config::get('cart.departments', []);


        $request->merge([
            'department' => $this->normalizeDepartment($request->input('department')),
            'section' => $this->normalizeDepartment($request->input('section')),
        ]);



        $validated = $request->validate([
            'department' => ['nullable', 'string', Rule::in($departments)],
            'section' => ['nullable', 'string', Rule::in($departments)],
        ]);

        if (! empty($validated['department']) && ! empty($validated['section']) && $validated['department'] !== $validated['section']) {
            return $this->validationError(__('يجب أن يتطابق القسم المحدد مع حقل section.'), 422);
        }
        $user = $request->user();

        $department = $validated['department'] ?? $validated['section'] ?? null;

        $query = $user->cartItems();

        if ($department) {
            $query->where('department', $department);
        }

        $query->delete();
        $this->cartShippingQuoteService->clearCachedQuotes($user);
        $includeCheckout = $this->shouldIncludeCheckout($request);

        return $this->buildResponse(
            $request->user(),
            $this->userCartItems($request->user()),
            
            __('تم إفراغ السلة بنجاح.'),
            $includeCheckout
        );
    }


    public function applyCoupon(Request $request): JsonResponse
    {
        if ($request->filled('couponCode') && ! $request->hasAny(['coupon_code', 'code'])) {
            $request->merge([
                'coupon_code' => $request->input('couponCode'),
            ]);
        }

        if ($request->filled('coupon') && ! $request->hasAny(['coupon_code', 'code', 'couponCode'])) {
            $request->merge([
                'coupon_code' => $request->input('coupon'),
            ]);
        }

        try {
            $validated = $request->validate(
                [
                    'coupon_code' => ['sometimes', 'required_without:code', 'string', 'max:191'],
                    'code' => ['sometimes', 'required_without:coupon_code', 'string', 'max:191'],
                ],
                [
                    'coupon_code.required_without' => __('يرجى إدخال رمز القسيمة.'),
                    'code.required_without' => __('يرجى إدخال رمز القسيمة.'),
                    'coupon_code.string' => __('يجب أن يكون رمز القسيمة نصاً صالحاً.'),
                    'code.string' => __('يجب أن يكون رمز القسيمة نصاً صالحاً.'),
                    'coupon_code.max' => __('يجب ألا يتجاوز رمز القسيمة :max حرفاً.', ['max' => 191]),
                    'code.max' => __('يجب ألا يتجاوز رمز القسيمة :max حرفاً.', ['max' => 191]),
                ]
            );
        } catch (ValidationException $exception) {
            $errors = $exception->errors();
            $message = Arr::flatten($errors)[0] ?? __('تعذر التحقق من رمز القسيمة.');

            return response()->json([
                'status' => false,
                'code' => 'validation_error',
                'message' => $message,
                'errors' => $errors,
            ], 422);
        }


        $couponCode = $validated['coupon_code'] ?? $validated['code'];


        $user = $request->user();
        $cartItems = $this->userCartItems($user);

        if ($cartItems->isEmpty()) {
            return $this->validationError(__('لا يمكن تطبيق قسيمة على سلة فارغة.'), 422, 'empty_cart');
        }

        $departments = $cartItems->pluck('department')->filter()->unique();

        if ($departments->count() > 1) {
            return $this->validationError(__('لا يمكن أن تحتوي السلة على أكثر من قسم واحد في نفس الوقت.'), 409, 'multiple_departments');
        }


        $departmentKey = $departments->first();

        try {
            $this->cartShippingQuoteService->ensureUserHasValidAddress($user, $departmentKey);
        } catch (ValidationException $exception) {
            return $this->addressRequiredResponse($exception);
        }


        $normalizedCode = Str::upper(trim((string) $couponCode));


        $coupon = Coupon::query()
            ->whereRaw('upper(code) = ?', [$normalizedCode])
            ->first();

        if (! $coupon) {
            return $this->validationError(__('رمز القسيمة غير صالح.'), 422, 'invalid_coupon');
        }

        if (! $coupon->isCurrentlyActive()) {
            return $this->validationError(__('هذه القسيمة غير متاحة حالياً.'), 422, 'inactive_coupon');
        }

        if (! $coupon->isWithinUsageLimits($user->getKey())) {
            return $this->validationError(__('تم تجاوز الحد الأقصى لاستخدام هذه القسيمة.'), 422, 'usage_limit_reached');
        }

        $subtotal = $cartItems->sum(static fn (CartItem $cartItem) => $cartItem->subtotal);

        if (! $coupon->meetsMinimumOrder($subtotal)) {
            return $this->validationError(__('قيمة الطلب أقل من الحد الأدنى المطلوب لاستخدام هذه القسيمة.'), 422, 'min_order_not_met');
        }

        CartCouponSelection::updateOrCreate(
            ['user_id' => $user->getKey()],
            [
                'coupon_id' => $coupon->getKey(),
                'department' => $departments->first(),
                'applied_at' => now(),
            ]
        );


        $this->recordCartTelemetry('cart.coupon_applied', $user, $cartItems, [
            'coupon_id' => $coupon->getKey(),
            'coupon_code' => $coupon->code,
        ]);


        $includeCheckout = $this->shouldIncludeCheckout($request);


        return $this->buildResponse(
            $user,
            $cartItems,
            __('تم تطبيق القسيمة على السلة بنجاح.'),
            $includeCheckout
        );
    }

    public function removeCoupon(Request $request): JsonResponse
    {
        $user = $request->user();
                $cartItems = $this->userCartItems($user);
        $departmentKey = $cartItems->pluck('department')->filter()->unique()->values()->first();

        try {
            $this->cartShippingQuoteService->ensureUserHasValidAddress($user, $departmentKey);
        } catch (ValidationException $exception) {
            return $this->addressRequiredResponse($exception);
        }
        $selection = $user->cartCouponSelection()->first();

        if ($selection) {
            $selection->delete();
        }


        if ($selection) {
            $this->recordCartTelemetry('cart.coupon_removed', $user, $cartItems, [
                'coupon_id' => $selection->coupon_id,
                'coupon_code' => optional($selection->coupon)->code,
            ]);
        }

        $includeCheckout = $this->shouldIncludeCheckout($request);

        return $this->buildResponse(
            $user,
            $cartItems,
            __('تمت إزالة القسيمة من السلة.'),
            $includeCheckout
        );
    }

    protected function buildResponse(User $user, Collection $cartItems, string $message, bool $includeCheckout = false): JsonResponse
    {

        $selection = $user->cartCouponSelection()->with('coupon')->first();

        if ($cartItems->isEmpty() && $selection) {
            $selection->delete();
            $selection = null;
        }

        $departmentKey = $cartItems->pluck('department')->filter()->unique()->values()->first();
        if ($selection && $selection->department && $departmentKey && $selection->department !== $departmentKey) {
            $selection->delete();
            $selection = null;
        }

        $items = $this->mapCartItems($cartItems);


        $subtotal = $cartItems->sum(static fn (CartItem $cartItem) => $cartItem->subtotal);

        $totalQuantity = $cartItems->sum('quantity');

        $discounts = $this->resolveDiscounts($user, $selection, $subtotal);

        [$currency, $currencyConflict] = $this->resolveCurrency(collect($items), null);
        if ($currency === null && ! $currencyConflict) {
            $currency = $this->defaultCurrency();
        }

        $total = (float) ($subtotal - $discounts['total']);

        $data = [
            'department' => $this->formatDepartmentMetadata($departmentKey),
            'items' => $items,
            'subtotal' => (float) $subtotal,
            'discounts' => $discounts,
            'total' => $total,
            'currency' => $currency,
            'currency_conflict' => $currencyConflict,
            'total_quantity' => (int) $totalQuantity,
            'meta' => [
                'last_updated' => $this->latestCartTimestamp($cartItems)?->toIso8601String(),
            ],
            'checkout' => null,
        ];

        if ($includeCheckout) {
            $checkout = $this->buildCheckoutPayload(
                $user,
                $cartItems,
                $departmentKey,
                $items,
                $subtotal,
                $discounts
            );

            $data['checkout'] = $checkout['payload'];
            $data['currency'] = $checkout['currency'] ?? $data['currency'];
            $data['currency_conflict'] = $checkout['currency_conflict'];
            $data['total'] = $checkout['total'];
        }

        return response()->json([
            'status' => true,
            'message' => $message,
            'data' => $data,
        ]);
    }

    /**
     * @return array{payload: array<string, mixed>, currency: ?string, currency_conflict: bool, total: float}
     */
    protected function buildCheckoutPayload(
        User $user,
        Collection $cartItems,
        ?string $departmentKey,
        array $items,
        float $subtotal,
        array $discounts
    ): array {
        if ($cartItems->isEmpty()) {
            return [
                'payload' => [
                    'delivery_quote' => null,
                    'delivery_payment_options' => [],
                    'delivery_payment_timing' => null,
                    'blocking' => null,
                    'department_notice' => null,
                    'department_policy' => null,
                    'support' => null,
                ],
                'currency' => $this->defaultCurrency(),
                'currency_conflict' => false,
                'total' => (float) ($subtotal - $discounts['total']),
            ];
        }




        $metrics = $this->cartShippingQuoteService->computeCartMetrics($cartItems);
        $rawDeliveryQuote = $this->getDeliveryQuote($user, $departmentKey, $metrics);
        $requiresAddressBlock = $this->requiresAddressBlock($user, $rawDeliveryQuote);
        $deliveryQuote = $requiresAddressBlock ? null : $rawDeliveryQuote;
        
        [$currency, $currencyConflict] = $this->resolveCurrency(collect($items), $rawDeliveryQuote);


        if ($currency === null && ! $currencyConflict) {
            $currency = $this->defaultCurrency();
        }

        $deliveryAmount = $this->resolveDeliveryAmount($deliveryQuote);

        $total = (float) ($subtotal - $discounts['total'] + $deliveryAmount);
        $departmentPolicy = $this->departmentPolicyService->policyFor($departmentKey);


        $blockingReasons = [];

        if ($requiresAddressBlock) {
            $blockingReasons[] = 'missing_address';
        }

        if ($currencyConflict) {
            $blockingReasons[] = 'multiple_currencies';
        }

        $blocking = $blockingReasons === []
            ? null
            : [
                'address_required' => $requiresAddressBlock,
                'currency_conflict' => $currencyConflict,
                'reasons' => $blockingReasons,
            ];



            $cartCurrencies = collect($items)
                ->pluck('currency')
                ->filter()
                ->unique()
                ->values();

            $blocking ??= [];


        if ($currencyConflict) {
            $blocking['message'] = __('cart.currency_conflict_summary', [
                'currencies' => $cartCurrencies->implode(', ') ?: __('cart.currency_not_specified'),
            ]);
        
        }


        $departmentNotice = $this->departmentNoticeService->getActiveNotice($departmentKey);
        $departmentPolicy = $this->rememberDepartmentPolicy($departmentKey);
        $support = $this->rememberDepartmentSupport($departmentKey);
        $deliveryPaymentOptions = $this->buildDeliveryPaymentOptions($user, $departmentKey, $deliveryQuote);

        return [
            'payload' => [


                'delivery_quote' => $deliveryQuote,
                'delivery_payment_options' => $deliveryPaymentOptions,
                'delivery_payment_timing' => $deliveryPaymentOptions['selected_timing'] ?? null,
                'blocking' => $blocking,
                'department_notice' => $departmentNotice,
                'department_policy' => $departmentPolicy,
                'support' => $support,
            ],
            'currency' => $currency,
            'currency_conflict' => $currencyConflict,
            'total' => $total,
        ];
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    protected function mapCartItems(Collection $cartItems): array
    {
        return $cartItems->map(function (CartItem $cartItem) {
            $item = $cartItem->item;
            $currency = $this->normalizeCurrency($cartItem->currency ?? null);


            return [
                'cart_item_id' => $cartItem->id,
                'item_id' => $cartItem->item_id,
                'name' => $item?->name,
                'image' => $item?->image,
                'product_link' => $item?->product_link,
                'quantity' => $cartItem->quantity,
                'department' => $cartItem->department,
                'variant_id' => $cartItem->variant_id,
                'attributes' => $cartItem->attributes ?? [],
                'stock_snapshot' => $cartItem->stock_snapshot ?? [],
                'unit_price' => $cartItem->unit_price !== null ? (float) $cartItem->unit_price : null,
                'unit_price_locked' => (float) $cartItem->getLockedUnitPrice(),
                'currency' => $currency,
                'subtotal' => (float) $cartItem->subtotal,
            ];
        })->values()->all();
    }
    protected function latestCartTimestamp(Collection $cartItems): ?Carbon
    {
        $timestamps = $cartItems
            ->map(static function (CartItem $cartItem) {
                $updatedAt = $cartItem->updated_at ?? $cartItem->created_at;
                if ($updatedAt instanceof Carbon) {
                    return $updatedAt;
                }

                if ($updatedAt === null) {
                    return null;
                }

                return Carbon::parse($updatedAt);
            })
            ->filter();

        if ($timestamps->isEmpty()) {
            return null;
        }

        return $timestamps->max();
    }

    protected function rememberDepartmentPolicy(?string $departmentKey): ?array
    {
        if (! $departmentKey) {
            return null;
        }

        return Cache::remember(
            sprintf('cart:department_policy:%s', $departmentKey),
            now()->addMinutes(30),
            fn () => $this->departmentPolicyService->policyFor($departmentKey)
        );
    }

    protected function rememberDepartmentSupport(?string $departmentKey): ?array
    {
        if (! $departmentKey) {
            return null;
        }

        return Cache::remember(
            sprintf('cart:department_support:%s', $departmentKey),
            now()->addMinutes(30),
            fn () => $this->departmentSupportService->supportFor($departmentKey)
        );
    }

    protected function isNotModified(Request $request, string $etag, Carbon $lastModified): bool
    {
        $ifNoneMatch = $request->headers->get('If-None-Match');
        if ($ifNoneMatch !== null && trim($ifNoneMatch, '"') === $etag) {
            return true;
        }

        $ifModifiedSince = $request->headers->get('If-Modified-Since');
        if ($ifModifiedSince !== null) {
            try {
                $ifModified = Carbon::parse($ifModifiedSince);
                if ($lastModified->lessThanOrEqualTo($ifModified)) {
                    return true;
                }
            } catch (\Exception) {
                // Ignore parsing errors and proceed with fresh response.
            }
        }

        return false;
    }

    protected function shouldIncludeCheckout(Request $request): bool
    {
        if ($request->has('include_checkout')) {
            return $this->boolFrom($request->input('include_checkout'));
        }

        if ($request->has('with')) {
            $with = Arr::wrap($request->input('with'));
            return in_array('checkout', $with, true);
        }

        return false;
    }




    public function showDeliveryPaymentTiming(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'department' => ['nullable', 'string', 'max:191'],
        ]);

        $user = $request->user();
        $department = $validated['department'] ?? null;
        $timing = $this->cartShippingQuoteService->getStoredDeliveryPaymentTiming($user, $department);

        return response()->json([
            'status' => true,
            'message' => __('cart.delivery_payment_timing.fetched'),
            'data' => [
                'department' => $department,
                'delivery_payment_timing' => $timing,
            ],
        ]);
    }




    public function updateDeliveryPaymentTiming(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'department' => ['nullable', 'string', 'max:191'],
            'delivery_payment_timing' => [
                'nullable',
                'string',
                Rule::in(OrderCheckoutService::allowedDeliveryPaymentTimingTokens()),
            ],
        ]);

        $user = $request->user();
        $department = $validated['department'] ?? null;
        $timing = OrderCheckoutService::normalizeTimingToken($validated['delivery_payment_timing'] ?? null);

        $this->cartShippingQuoteService->rememberDeliveryPaymentTiming($user, $department, $timing);

        $storedTiming = $this->cartShippingQuoteService->getStoredDeliveryPaymentTiming($user, $department);

        return response()->json([
            'status' => true,
            'message' => __('cart.delivery_payment_timing.updated'),
            'data' => [
                'department' => $department,
                'delivery_payment_timing' => $storedTiming,
            ],
        ]);
    }


    

    public function checkoutInfo(Request $request): JsonResponse
    {
        $user = $request->user();
        $cartItems = $this->userCartItems($user);

        $selection = $user->cartCouponSelection()->with('coupon')->first();
        if ($cartItems->isEmpty() && $selection) {
            $selection->delete();
            $selection = null;
        }

        $departmentKey = $cartItems->pluck('department')->filter()->unique()->values()->first();
        if ($selection && $selection->department && $departmentKey && $selection->department !== $departmentKey) {
            $selection->delete();
            $selection = null;
        }

        $items = $this->mapCartItems($cartItems);
        $subtotal = $cartItems->sum(static fn (CartItem $cartItem) => $cartItem->subtotal);
        $discounts = $this->resolveDiscounts($user, $selection, $subtotal);

        $checkout = $this->buildCheckoutPayload(
            $user,
            $cartItems,
            $departmentKey,
            $items,
            $subtotal,
            $discounts
        );

        $lastModified = $this->latestCartTimestamp($cartItems) ?? Carbon::now();
        $etag = sha1(json_encode([
            'user' => $user->getKey(),
            'updated_at' => $lastModified->toIso8601String(),
            'total' => $checkout['total'],
            'currency' => $checkout['currency'],
            'discount_total' => $discounts['total'] ?? null,
        ], JSON_THROW_ON_ERROR));

        if ($this->isNotModified($request, $etag, $lastModified)) {
            return response('', 304)
                ->setEtag($etag)
                ->setLastModified($lastModified);
        }

        $response = response()->json([
            'status' => true,
            'message' => __('تم جلب معلومات السداد والشحن بنجاح.'),
            'data' => [
                'department' => $this->formatDepartmentMetadata($departmentKey),
                'checkout' => $checkout['payload'],
                'subtotal' => (float) $subtotal,
                'discounts' => $discounts,
                'total' => $checkout['total'],
                'currency' => $checkout['currency'],
                'currency_conflict' => $checkout['currency_conflict'],
            ],
        ]);

        $response->setEtag($etag);
        $response->setLastModified($lastModified);

        return $response;
    }


    /**
     * @return array{coupons: array<int, array<string, mixed>>, total: float}
     */
    protected function resolveDiscounts(User $user, ?CartCouponSelection $selection, float $subtotal): array
    {
        $discounts = [
            'coupons' => [],
            'total' => 0.0,
        ];

        if (! $selection) {
            return $discounts;
        }

        $coupon = $selection->coupon;

        if (! $coupon) {
            $selection->delete();

            return $discounts;
        }

        $status = 'applied';
        $amount = 0.0;

        if (! $coupon->isCurrentlyActive()) {
            $status = 'inactive_coupon';
        } elseif (! $coupon->isWithinUsageLimits($user->getKey())) {
            $status = 'usage_limit_reached';
        } elseif (! $coupon->meetsMinimumOrder($subtotal)) {
            $status = 'min_order_not_met';
        } else {
            $amount = round($coupon->calculateDiscount($subtotal), 2);
            $discounts['total'] += $amount;
        }

        $discounts['coupons'][] = [
            'id' => $coupon->getKey(),
            'code' => $coupon->code,
            'name' => $coupon->name,
            'amount' => $amount,
            'status' => $status,
            'discount_type' => $coupon->discount_type,
            'discount_value' => $coupon->discount_value,
            'minimum_order_amount' => $coupon->minimum_order_amount !== null ? (float) $coupon->minimum_order_amount : null,
            'max_uses' => $coupon->max_uses,
            'max_uses_per_user' => $coupon->max_uses_per_user,
            'starts_at' => $coupon->starts_at?->toIso8601String(),
            'ends_at' => $coupon->ends_at?->toIso8601String(),
            'applied_at' => $selection->applied_at?->toIso8601String(),
            'department' => $selection->department,
        ];

        return $discounts;
    }
    



    protected function validateAddOrUpdateRequest(Request $request): array
    {
        $departments = Config::get('cart.departments', []);


        $request->merge([
            'department' => $this->normalizeDepartment($request->input('department')),
            'section' => $this->normalizeDepartment($request->input('section')),
        ]);


        return $request->validate([
            'item_id' => ['required', 'integer', 'exists:items,id'],
            'quantity' => ['required', 'integer', 'min:1'],
            'department' => ['nullable', 'string', Rule::in($departments)],
            'section' => ['nullable', 'string', Rule::in($departments)],
            'category_id' => ['nullable', 'integer', 'exists:categories,id'],
            'variant_id' => ['nullable', 'integer'],
            'attributes' => ['nullable', 'array'],
            'stock_snapshot' => ['nullable', 'array'],
            'unit_price' => ['nullable', 'numeric', 'min:0'],
            'unit_price_locked' => ['nullable', 'numeric', 'min:0'],
            'currency' => ['nullable', 'string', 'size:3'],


        ]);
    }

    protected function resolveDepartment(Item $item, array $validated): ?string
    {
        $department = $this->normalizeDepartment($validated['department'] ?? null)
            ?? $this->normalizeDepartment($validated['section'] ?? null);

        if ($department) {
            return $department;
        }

        $categoryId = $validated['category_id'] ?? $item->category_id;

        if ($categoryId) {
            $department = $this->departmentFromCategory((int) $categoryId);
        }

        if (! $department && $item->interface_type) {
            $department = $this->normalizeDepartment(Config::get('cart.interface_map.' . $item->interface_type));
        }

        return $department ?: $this->defaultDepartment();
    }

    protected function defaultDepartment(): ?string
    {
        $departments = Config::get('cart.departments', []);
        $preferred = $this->normalizeDepartment(Config::get('cart.default_department'));

        if ($preferred && in_array($preferred, $departments, true)) {
            return $preferred;
        }

        return $departments[0] ?? null;
    }

    protected function normalizeDepartment(?string $value): ?string
    {
        if ($value === null) {
            return null;
        }

        $normalized = Str::of($value)
            ->lower()
            ->trim();

        if ($normalized->isEmpty()) {
            return null;


        }


        $normalized = $normalized
            ->replaceMatches('/[إأآٱ]/u', 'ا')
            ->replace('ة', 'ه')
            ->replace('ى', 'ي')
            ->replace('ؤ', 'و')
            ->replace('ئ', 'ي')
            ->replaceMatches('/[\s_\-]+/u', '')
            ->replaceMatches('/[^a-z0-9\x{0621}-\x{064A}]+/u', '')
            ->value();

        if ($normalized === '') {
            return null;
        }

        $aliases = [
            'shein' => 'shein',
            'شيان' => 'shein',
            'شيئن' => 'shein',
            'شيان' => 'shein',
            'شين' => 'shein',
            'computer' => 'computer',
            'كمبيوتر' => 'computer',
            'الكترون' => 'computer',
            'حاسب' => 'computer',
            'store' => 'store',
            'stores' => 'store',
            'storeproducts' => 'store',
            'storeproduct' => 'store',
            'market' => 'store',
            'markets' => 'store',
            'general' => 'store',
            'default' => 'store',
            'public' => 'store',
            'accessor' => 'store',
            'متجر' => 'store',
            'المتجر' => 'store',
            'متجرعام' => 'store',
            'سوق' => 'store',
            'السوق' => 'store',
            'بقاله' => 'store',
            'عام' => 'store',
            'عامه' => 'store',
            'سوبرماركت' => 'store',
            'ماركت' => 'store',
        ];

        if (array_key_exists($normalized, $aliases)) {
            return $aliases[$normalized];
        }

        if (str_contains($normalized, 'shein') || str_contains($normalized, 'شيان') || str_contains($normalized, 'شين')) {
            return 'shein';
        }

        if (str_contains($normalized, 'computer') || str_contains($normalized, 'كمبيوتر') || str_contains($normalized, 'الكترون') || str_contains($normalized, 'حاسب')) {
            return 'computer';
        }

        if (str_contains($normalized, 'store') || str_contains($normalized, 'market') || str_contains($normalized, 'متجر') || str_contains($normalized, 'سوق')) {
            return 'store';
        }

        if (str_starts_with($normalized, 'category')) {
            $digits = preg_replace('/\D+/', '', $normalized);
            if ($digits !== '') {
                $department = $this->departmentFromCategory((int) $digits);
                if ($department) {
                    return $department;
                }
            }
        }

        $departments = Config::get('cart.departments', []);
        if (in_array($normalized, $departments, true)) {
            return $normalized;
        }

        return null;


    }

    protected function departmentFromCategory(int $categoryId): ?string
    {
        static $categoriesCache = null;

        if ($categoriesCache === null) {
            $categoriesCache = Category::select(['id', 'parent_category_id'])->get()->keyBy('id');
        }

        $categories = $categoriesCache;

        $currentId = $categoryId;
        $visited = [];

        while ($currentId && ! in_array($currentId, $visited, true)) {
            $visited[] = $currentId;

            foreach (Config::get('cart.department_roots', []) as $department => $rootId) {
                if ($currentId === $rootId) {
                    return $department;
                }
            }

            $category = $categories->get($currentId);

            if (! $category) {
                break;
            }

            $currentId = $category->parent_category_id ?? null;
        }

        return null;
    }

    protected function itemBelongsToDepartment(Item $item, string $department): bool
    {
        $itemDepartment = $this->resolveItemDepartment($item);

        if (! $itemDepartment) {
            return true;
        }

        return $itemDepartment === $department;
    }

    protected function resolveItemDepartment(Item $item): ?string

    {
        $itemDepartment = $this->departmentFromCategory((int) $item->category_id);

        if (! $itemDepartment && $item->interface_type) {
            $itemDepartment = $this->normalizeDepartment(Config::get('cart.interface_map.' . $item->interface_type));
        }

        if (! $itemDepartment && ! empty($item->all_category_ids)) {
            $categoryIds = array_filter(array_map('intval', explode(',', (string) $item->all_category_ids)));

            foreach ($categoryIds as $categoryId) {
                $itemDepartment = $this->departmentFromCategory($categoryId);

                if ($itemDepartment) {
                    break;
                }
            }
        }

        return $itemDepartment ? $this->normalizeDepartment($itemDepartment) : null;
    }

    protected function existingCartDepartment(User $user): ?string
    {
        return $user->cartItems()
            ->whereNotNull('department')
            ->pluck('department')
            ->map(fn ($value) => $this->normalizeDepartment($value))
            ->filter()
            ->unique()
            ->values()
            ->first();
        
        }

    protected function defaultCurrency(): string
    {
        return config('app.currency_code', 'USD');
    }


    protected function userCartItems(User $user): Collection
    {
        return $user->cartItems()
            ->with(['item' => static function ($query) {
                $query->select(['id', 'name', 'image', 'product_link']);
            }])
            ->orderByDesc('created_at')
            ->get();
        
        }


    protected function recordCartTelemetry(string $event, User $user, Collection $cartItems, array $extra = []): void
    {
        $context = array_merge($this->buildCartTelemetryContext($user, $cartItems), $extra);

        $this->telemetry->record($event, $context);
    }

    protected function buildCartTelemetryContext(User $user, Collection $cartItems): array
    {
        $subtotal = round($cartItems->sum(static fn (CartItem $cartItem) => $cartItem->subtotal), 2);
        $departments = $cartItems->pluck('department')->filter()->unique()->values()->all();
        $currency = $cartItems->pluck('currency')->filter()->unique()->values()->first();

        return [
            'user_id' => $user->getKey(),
            'cart_item_count' => $cartItems->count(),
            'cart_total_quantity' => (int) $cartItems->sum('quantity'),
            'cart_subtotal' => $subtotal,
            'departments' => $departments,
            'cart_currency' => $currency,
        ];
    }


    protected function normalizeCurrency(?string $currency): ?string
    {
        if ($currency === null) {
            return null;
        }

        return strtoupper($currency);
    }



    private function boolFrom(mixed $value): bool
    {
        if (is_bool($value)) {
            return $value;
        }

        if ($value === null) {
            return false;
        }

        if (is_string($value)) {
            $filtered = filter_var($value, FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE);

            if ($filtered !== null) {
                return $filtered;
            }
        }

        return (bool) $value;
    }



    protected function ensureSingleCurrency(Collection $existingCurrencies, ?string $incomingCurrency): ?JsonResponse
    {
        if ($incomingCurrency !== null && $existingCurrencies->contains($incomingCurrency)) {
            return null;
        }

        $currentCurrencies = $existingCurrencies->implode(', ');

        if ($currentCurrencies === '') {
            $currentCurrencies = __('cart.currency_not_specified');
        }

        $requestedCurrency = $incomingCurrency ?? __('cart.currency_not_specified');

        return $this->validationError(
            __('cart.currency_conflict_on_add', [
                'current_currencies' => $currentCurrencies,
                'requested_currency' => $requestedCurrency,
            ]),
            409,
            'multiple_currencies'
        );
    }


    protected function formatDepartmentMetadata(?string $department): array
    {
        $available = $this->departmentReportService->availableDepartments();

        return [
            'key' => $department,
            'label' => $department ? ($available[$department] ?? $department) : null,
        ];
    }



    protected function buildDeliveryPaymentOptions(User $user, ?string $department, ?array $deliveryQuote): ?array
    {
        if ($deliveryQuote === null) {
            return null;
        }

        $availableTimings = [];

        if ($this->boolFrom(Arr::get($deliveryQuote, 'allow_pay_now', Arr::get($deliveryQuote, 'payment.allow_pay_now')))) {
            $availableTimings[] = OrderCheckoutService::DELIVERY_TIMING_PAY_NOW;
        }

        if ($this->boolFrom(Arr::get($deliveryQuote, 'allow_pay_on_delivery', Arr::get($deliveryQuote, 'payment.allow_pay_on_delivery')))) {
            $availableTimings[] = OrderCheckoutService::DELIVERY_TIMING_PAY_ON_DELIVERY;
        }

        $timingCodes = Arr::get($deliveryQuote, 'timing_codes', Arr::get($deliveryQuote, 'payment.timing_codes', []));
        $normalizedCodes = [];

        if (is_array($timingCodes)) {
            foreach ($timingCodes as $key => $value) {
                if (is_string($key) && $this->boolFrom($value)) {
                    $normalizedKey = OrderCheckoutService::normalizeTimingToken($key);

                    if ($normalizedKey !== null) {
                        $normalizedCodes[] = $normalizedKey;
                    }
                }

                if (is_string($value)) {
                    $normalizedValue = OrderCheckoutService::normalizeTimingToken($value);

                    if ($normalizedValue !== null) {
                        $normalizedCodes[] = $normalizedValue;
                    }
                }
            }
        }

        if ($normalizedCodes !== []) {
            $availableTimings = array_merge($availableTimings, $normalizedCodes);
        }

        $availableTimings = array_values(array_unique(array_filter($availableTimings)));

        $storedTiming = $deliveryQuote['delivery_payment_timing']
            ?? Arr::get($deliveryQuote, 'meta.delivery_payment_timing')
            ?? $this->cartShippingQuoteService->getStoredDeliveryPaymentTiming($user, $department);

        $selectedTiming = OrderCheckoutService::normalizeTimingToken($storedTiming);

        $suggestedTiming = OrderCheckoutService::normalizeTimingToken(
            Arr::get($deliveryQuote, 'suggested_timing', Arr::get($deliveryQuote, 'payment.suggested_timing'))
        );

        if ($selectedTiming !== null && ! in_array($selectedTiming, $availableTimings, true)) {
            $selectedTiming = null;
        }

        if ($selectedTiming === null) {
            if ($suggestedTiming !== null && in_array($suggestedTiming, $availableTimings, true)) {
                $selectedTiming = $suggestedTiming;
            } elseif ($availableTimings !== []) {
                $selectedTiming = $availableTimings[0];
            }
        }

        $normalizedCodes = array_values(array_unique(array_filter($normalizedCodes)));

        return [
            'allow_pay_now' => in_array(OrderCheckoutService::DELIVERY_TIMING_PAY_NOW, $availableTimings, true),
            'allow_pay_on_delivery' => in_array(OrderCheckoutService::DELIVERY_TIMING_PAY_ON_DELIVERY, $availableTimings, true),
            'available_timings' => $availableTimings,
            'selected_timing' => $selectedTiming,
            'suggested_timing' => $suggestedTiming,
            'timing_codes' => $normalizedCodes,
        ];
    }





    /**
     * @param array{cart_value: float, weight_total: float} $metrics
     */
    protected function getDeliveryQuote(User $user, ?string $department, array $metrics): ?array
    
    {

        $latestKey = CartShippingQuoteService::latestCacheKeyFor($user->id, $department);
        $reference = Cache::get($latestKey);


        if (! is_array($reference) || empty($reference['cache_key']) || ! is_string($reference['cache_key'])) {
            return null;
        }

        if (! $this->quoteMatchesMetrics($reference, $metrics)) {
            return null;
        }

        $payload = Cache::get($reference['cache_key']);

        if (! is_array($payload)) {
            return null;
        }

        $addressId = $payload['address_id'] ?? $reference['address_id'] ?? null;
        $payload['address_id'] = $addressId;

        if (! array_key_exists('department_policy', $payload)) {
            $payload['department_policy'] = $this->departmentPolicyService->policyFor($department);
        }

        $context = is_array($payload['context'] ?? null) ? $payload['context'] : [];
        $context = array_merge($context, [
            'cart_value' => $metrics['cart_value'],
            'weight_total' => $metrics['weight_total'],
            'department' => $department,
        ]);

        if ($addressId !== null) {
            $context['address_id'] = $addressId;
        }

        $payload['context'] = $context;

        $meta = is_array($payload['meta'] ?? null) ? $payload['meta'] : [];
        $meta = array_merge($meta, [
            'cached' => true,
            'cache_key' => $reference['cache_key'],
            'cart_value' => $metrics['cart_value'],
            'weight_total' => $metrics['weight_total'],
        ]);

        $addressKey = $reference['address_key'] ?? ($meta['address_key'] ?? null);

        if ($addressKey !== null) {
            $meta['address_key'] = $addressKey;
        }

        if ($department !== null) {
            $meta['department'] = $department;
        }



        $deliveryTiming = $reference['delivery_payment_timing'] ?? null;

        if ($deliveryTiming !== null) {
            $payload['delivery_payment_timing'] = $deliveryTiming;
            $meta['delivery_payment_timing'] = $deliveryTiming;
        }


        $payload['meta'] = $meta;

        return $payload;


    }

    /**
     * @param array<string, mixed> $reference
     * @param array{cart_value: float, weight_total: float} $metrics
     */
    protected function quoteMatchesMetrics(array $reference, array $metrics): bool


    {
        if (array_key_exists('cart_value', $reference)) {
            $expected = (float) $reference['cart_value'];

            if ($this->valuesDiffer($expected, (float) ($metrics['cart_value'] ?? 0.0), 0.01)) {
                return false;

                        }

            }

        if (array_key_exists('weight_total', $reference)) {
            $expected = (float) $reference['weight_total'];

            if ($this->valuesDiffer($expected, (float) ($metrics['weight_total'] ?? 0.0), 0.001)) {
                return false;

            }
        }

        return true;
    }

    protected function valuesDiffer(float $expected, float $actual, float $tolerance): bool
    {
        return abs($expected - $actual) > $tolerance;
    }

    protected function resolveDeliveryAmount(?array $deliveryQuote): float
    {
        if ($deliveryQuote === null) {
            return 0.0;
        }

        if (array_key_exists('amount', $deliveryQuote)) {
            return (float) $deliveryQuote['amount'];
        }

        if (array_key_exists('total', $deliveryQuote)) {
            return (float) $deliveryQuote['total'];


        }

        return 0.0;
    }

    /**
     * @return array{0: ?string, 1: bool}
     */
    protected function resolveCurrency(Collection $items, ?array $deliveryQuote): array
    
    {
        $currencies = $items
            ->pluck('currency')
            ->map(fn (?string $currency) => $this->normalizeCurrency($currency))
            ->filter()
            ->unique()
            ->values();

        if ($currencies->count() > 1) {
            return [null, true];
        }

        if ($currencies->count() === 1) {
            return [$currencies->first(), false];
        }




        if (is_array($deliveryQuote)) {
            $deliveryCurrency = $this->normalizeCurrency($deliveryQuote['currency'] ?? null);

            if ($deliveryCurrency) {
                return [$deliveryCurrency, false];
            }


        }

        return [null, false];
    }



    protected function requiresAddressBlock(User $user, ?array $deliveryQuote): bool
    {
        return empty($deliveryQuote) || ! $this->userHasValidAddress($user);
    }

    protected function userHasValidAddress(User $user): bool
    {
        return $user->addresses()
            ->whereNotNull('latitude')
            ->whereNotNull('longitude')
            ->whereNotNull('distance_km')
            ->where('distance_km', '>=', 0)
            ->exists();
    }



    protected function validationError(string $message, int $status = 422, ?string $code = null): JsonResponse
    {
        $payload = [
            'status' => false,
            'message' => $message,
        ];

        if ($code !== null) {
            $payload['code'] = $code;
        }

        return response()->json($payload, $status);


    }

    protected function addressRequiredResponse(ValidationException $exception): JsonResponse
    {
        return response()->json([
            'status' => false,
            'code' => 'address_required',
            'message' => __('يجب اختيار عنوان صالح لحساب رسوم الشحن.'),
            'errors' => $exception->errors(),
        ], 422);

        
    }
}