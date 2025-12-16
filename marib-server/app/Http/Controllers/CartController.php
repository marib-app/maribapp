<?php

namespace App\Http\Controllers;

use App\Models\CartItem;
use App\Models\Category;
use App\Models\Item;
use App\Models\Store;
use App\Models\StoreGatewayAccount;
use App\Models\User;
use App\Services\DepartmentReportService;
use Illuminate\Http\JsonResponse;
use App\Services\CartShippingQuoteService;
use App\Services\TelemetryService;
use App\Models\CartCouponSelection;
use App\Services\DepartmentNoticeService;
use App\Services\DepartmentSupportService;
use App\Services\ItemPurchaseOptionsService;
use Illuminate\Support\Arr;
use App\Services\DepartmentPolicyService;
use App\Services\Store\StoreStatusService;
use App\Support\VariantKeyNormalizer;

use App\Models\Coupon;
use Illuminate\Support\Str;
use Illuminate\Http\Request;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Config;
use Illuminate\Support\Facades\Storage;
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
        private readonly ItemPurchaseOptionsService $itemPurchaseOptionsService,
        private readonly StoreStatusService $storeStatusService,
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

        $item = Item::select(['id', 'price', 'category_id', 'interface_type', 'all_category_ids', 'currency', 'store_id'])
            ->find($validated['item_id']);

        if (! $item) {
            return $this->validationError(__('العنصر المطلوب غير متاح.'), 422);
        }


        $user = $request->user();
        $storeId = $item->store_id ? (int) $item->store_id : null;
        $isStoreItem = $storeId !== null;

        if ($isStoreItem) {
            if ($this->cartHasGeneralItems($user)) {
                $this->clearGeneralCart($user);
            }

            $existingStoreId = $this->existingCartStoreId($user);

            if ($existingStoreId !== null && $existingStoreId !== $storeId) {
                $this->clearStoreCart($user);
            }
        } elseif ($this->cartHasStoreItems($user)) {
            $this->clearStoreCart($user);
        }


        $department = $this->resolveDepartment($item, $validated);

        $itemDepartment = $this->resolveItemDepartment($item);

        if (! $department && $itemDepartment) {
            $department = $itemDepartment;
        }

        if ($isStoreItem && ! $department) {
            $department = $this->normalizeDepartment(Config::get('cart.default_department', 'store'));
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


        $rawAttributes = $validated['attributes'] ?? [];
        if (is_string($rawAttributes)) {
            $decoded = json_decode($rawAttributes, true);
            $rawAttributes = is_array($decoded) ? $decoded : [];
        }

        if (is_string($rawAttributes)) {
            $decoded = json_decode($rawAttributes, true);
            $rawAttributes = is_array($decoded) ? $decoded : [];
        }

        if (! is_array($rawAttributes)) {
            $rawAttributes = [];
        }

        try {
            $normalizedAttributes = $this->itemPurchaseOptionsService->sanitizeAttributes($item, $rawAttributes);
        } catch (ValidationException $exception) {
            return $this->validationError($exception->getMessage(), 422);
        }

        $variantKey = $this->itemPurchaseOptionsService->generateVariantKey($item, $normalizedAttributes);

        if (array_key_exists('variant_key', $validated)) {
            $expectedVariantKey = VariantKeyNormalizer::normalize($validated['variant_key'] ?? null);

            if ($expectedVariantKey !== $variantKey) {
                return $this->validationError(
                    __('تم تغيير خيارات المنتج بطريقة غير صالحة. يرجى إعادة المحاولة.'),
                    422,
                    'invalid_variant_key'
                );
            }
        }



        $cartItem = CartItem::firstOrNew([
            'user_id' => $user->id,
            'item_id' => $item->id,
            'store_id' => $storeId,


            'variant_id' => $validated['variant_id'] ?? null,
            'variant_key' => $variantKey,

            'department' => $department,
        ]);



        $itemCurrency = $this->normalizeCurrency($item->currency ?? null);
        $requestedCurrency = array_key_exists('currency', $validated)
        
        ? $this->normalizeCurrency($validated['currency'])
            : null;

        if ($itemCurrency && $requestedCurrency && $requestedCurrency !== $itemCurrency) {
            return $this->validationError(
                __('cart.currency_mismatch_with_item', [
                    'item_currency' => $itemCurrency,
                    'requested_currency' => $requestedCurrency,
                ]),
                422,
                'currency_mismatch'
            );
        }

        $normalizedCurrency = $itemCurrency
            ?? ($requestedCurrency
                ?? ($cartItem->exists && $cartItem->currency
                    ? $this->normalizeCurrency($cartItem->currency)
                    : $this->normalizeCurrency($this->defaultCurrency())));
        $currentCurrency = $this->normalizeCurrency($cartItem->currency ?? null);



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

        $effectiveUnitPrice = array_key_exists('unit_price', $validated)
            ? (float) $validated['unit_price']
            : $item->calculateDiscountedPrice();

        $cartItem->unit_price = $effectiveUnitPrice;

        if (array_key_exists('unit_price_locked', $validated)) {
            $cartItem->unit_price_locked = $validated['unit_price_locked'] !== null
                ? (float) $validated['unit_price_locked']
                : null;
        } elseif (! $cartItem->unit_price_locked) {
            $cartItem->unit_price_locked = $effectiveUnitPrice;
        }

        if ($normalizedCurrency !== $currentCurrency) {
            $cartItem->currency = $normalizedCurrency;


        }

        $cartItem->variant_key = $variantKey;
        $cartItem->variant_id = $validated['variant_id'] ?? $cartItem->variant_id;
        $cartItem->attributes = $normalizedAttributes;

        $availableStock = $this->itemPurchaseOptionsService->resolveAvailableStock($item, $variantKey);
        if ($availableStock !== null) {
            $snapshot = is_array($cartItem->stock_snapshot) ? $cartItem->stock_snapshot : [];
            $snapshot['variant_key'] = $variantKey;
            $snapshot['available_quantity'] = $availableStock;
            $cartItem->stock_snapshot = $snapshot;


        }

        if (array_key_exists('stock_snapshot', $validated)) {
            $incomingSnapshot = $validated['stock_snapshot'];
            if (is_array($incomingSnapshot)) {
                $snapshot = is_array($cartItem->stock_snapshot) ? $cartItem->stock_snapshot : [];
                $cartItem->stock_snapshot = array_merge($snapshot, $incomingSnapshot);
            } else {
                $cartItem->stock_snapshot = $incomingSnapshot;
            }
        
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
            'variant_key' => ['nullable', 'string', 'max:512'],
            'attributes' => ['nullable', 'array'],
            'stock_snapshot' => ['nullable', 'array'],
            'unit_price' => ['nullable', 'numeric', 'min:0'],
            'unit_price_locked' => ['nullable', 'numeric', 'min:0'],
            'currency' => ['nullable', 'string', 'size:3'],

        ]);

        $user = $request->user();
        $cartItem = CartItem::query()
            ->with('item')
            ->where('user_id', $user->id)
            ->whereKey($cartItemId)
            ->first();

        if (! $cartItem) {
            return $this->validationError(__('العنصر غير موجود في سلة المشتريات.'), 422);
        }



        $itemCurrency = $this->normalizeCurrency($cartItem->item?->currency ?? null);
        $requestedCurrency = array_key_exists('currency', $validated)
        
        ? $this->normalizeCurrency($validated['currency'])
            : null;
        $currentCurrency = $this->normalizeCurrency($cartItem->currency ?? null);

        if ($itemCurrency && $requestedCurrency && $requestedCurrency !== $itemCurrency) {
            return $this->validationError(
                __('cart.currency_mismatch_with_item', [
                    'item_currency' => $itemCurrency,
                    'requested_currency' => $requestedCurrency,
                ]),
                422,
                'currency_mismatch'
            );
        }

        $normalizedCurrency = $itemCurrency
            ?? ($requestedCurrency ?? $currentCurrency);


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





        $itemModel = $cartItem->item;


        $rawAttributes = array_key_exists('attributes', $validated)
            ? $validated['attributes']
            : ($cartItem->attributes ?? []);

        if (! is_array($rawAttributes)) {
            $rawAttributes = [];
        
        }
        $normalizedAttributes = is_array($cartItem->attributes) ? $cartItem->attributes : [];
        $variantKey = $cartItem->variant_key ?? '';

        if ($itemModel instanceof Item) {
            try {
                $normalizedAttributes = $this->itemPurchaseOptionsService->sanitizeAttributes($itemModel, $rawAttributes);
            } catch (ValidationException $exception) {
                return $this->validationError($exception->getMessage(), 422);
            }

            $variantKey = $this->itemPurchaseOptionsService->generateVariantKey($itemModel, $normalizedAttributes);

        if (array_key_exists('variant_key', $validated)) {
            $expectedVariantKey = VariantKeyNormalizer::normalize($validated['variant_key'] ?? null);
            if ($expectedVariantKey !== $variantKey) {
                return $this->validationError(
                    __('تم تغيير خيارات المنتج بطريقة غير صالحة. يرجى إعادة المحاولة.'),
                    422,
                    'invalid_variant_key'
                );
                }
            }

            if ($variantKey !== ($cartItem->variant_key ?? '')) {
                $conflict = CartItem::query()
                    ->where('user_id', $user->id)
                    ->where('item_id', $cartItem->item_id)
                    ->where('department', $cartItem->department)
                    ->where('variant_key', $variantKey)
                    ->where('id', '!=', $cartItem->id)
                    ->exists();

                if ($conflict) {
                    return $this->validationError(__('لا يمكن تحديث المتغير المحدد لأنه موجود بالفعل في السلة.'), 409);
                }



                $cartItem->variant_key = $variantKey;
            }

            $availableStock = $this->itemPurchaseOptionsService->resolveAvailableStock($itemModel, $variantKey);
            if ($availableStock !== null) {
                $snapshot = is_array($cartItem->stock_snapshot) ? $cartItem->stock_snapshot : [];
                $snapshot['variant_key'] = $variantKey;
                $snapshot['available_quantity'] = $availableStock;
                $cartItem->stock_snapshot = $snapshot;
            }
        }

        if (array_key_exists('variant_id', $validated)) {
            $cartItem->variant_id = $validated['variant_id'] ?? null;

        }

        $cartItem->attributes = $normalizedAttributes;

        $cartItem->quantity = (int) $validated['quantity'];

        if (array_key_exists('stock_snapshot', $validated)) {
            $incomingSnapshot = $validated['stock_snapshot'];
            if (is_array($incomingSnapshot)) {
                $snapshot = is_array($cartItem->stock_snapshot) ? $cartItem->stock_snapshot : [];
                $cartItem->stock_snapshot = array_merge($snapshot, $incomingSnapshot);
            } else {
                $cartItem->stock_snapshot = $incomingSnapshot;
            }
        
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

        if ($normalizedCurrency !== $currentCurrency) {
            $cartItem->currency = $normalizedCurrency;

    
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

        $storeContext = $this->summarizeCartStoreContext($cartItems);

        if ($storeContext['multiple_stores']) {
            return $this->validationError(__('cart.multi_store_not_supported'), 409, 'multiple_store_items');
        }

        if ($storeContext['has_store_items'] && $storeContext['has_general_items']) {
            return $this->validationError(__('cart.store_cart_conflict'), 409, 'store_cart_conflict');
        }

        $storeId = $storeContext['store_id'];

        $normalizedCode = Str::upper(trim((string) $couponCode));


        $coupon = Coupon::query()
            ->whereRaw('upper(code) = ?', [$normalizedCode])
            ->forStore($storeId)
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

        $cartStore = $this->extractCartStore($cartItems);
        $items = $this->mapCartItems($cartItems);
        $storeMeta = $this->formatCartStoreSummary($cartItems, $cartStore);


        $subtotal = $cartItems->sum(static fn (CartItem $cartItem) => $cartItem->subtotal);

        $totalQuantity = $cartItems->sum('quantity');

        $discounts = $this->resolveDiscounts($user, $selection, $subtotal, $cartItems);

        [$currency, $currencyConflict] = $this->resolveCurrency(collect($items), null);
        if ($currency === null && ! $currencyConflict) {
            $currency = $this->defaultCurrency();
        }

        $total = (float) ($subtotal - $discounts['total']);

        $data = [
            'department' => $this->formatDepartmentMetadata($departmentKey),
            'store' => $storeMeta,
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
                    'assurance' => null,
                ],
                'currency' => $this->defaultCurrency(),
                'currency_conflict' => false,
                'total' => (float) ($subtotal - $discounts['total']),
            ];
        }

        $cartStore = $this->extractCartStore($cartItems);
        $storeSummary = $this->formatCartStoreSummary($cartItems, $cartStore);
        $storeStatus = $storeSummary['status'] ?? null;
        $assurance = $storeSummary['assurance'] ?? null;




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

        if ($cartStore && is_array($storeStatus)) {
            $blocking = $this->applyStoreCheckoutConstraints($cartStore, $storeStatus, $subtotal, $blocking);
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
                'assurance' => $assurance,
                'store' => $storeSummary,
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
                'store_id' => $cartItem->store_id,
                'name' => $item?->name,
                'image' => $item?->image,
                'product_link' => $item?->product_link,
                'quantity' => $cartItem->quantity,
                'department' => $cartItem->department,
                'variant_id' => $cartItem->variant_id,
                'variant_key' => $cartItem->variant_key,
                'attributes' => $cartItem->attributes ?? [],
                'stock_snapshot' => $cartItem->stock_snapshot ?? [],
                'unit_price' => $cartItem->unit_price !== null ? (float) $cartItem->unit_price : null,
                'unit_price_locked' => (float) $cartItem->getLockedUnitPrice(),
                'final_unit_price' => (float) $cartItem->getLockedUnitPrice(),
                'currency' => $currency,
                'subtotal' => (float) $cartItem->subtotal,
                'store' => $this->formatStoreMetadata($item?->store),
            ];
        })->values()->all();
    }

    protected function formatStoreMetadata(?Store $store): ?array
    {
        if (! $store) {
            return null;
        }

        return [
            'id' => $store->id,
            'name' => $store->name,
            'slug' => $store->slug,
            'status' => $store->status,
        ];
    }

    protected function buildStoreAssurancePayload(Store $store): ?array
    {
        $owner = $store->owner;

        if (! $owner || $owner->account_type !== User::ACCOUNT_TYPE_SELLER) {
            return null;
        }

        if (! $owner->hasActiveVerification()) {
            return null;
        }

        return [
            'active' => true,
            'type' => 'verified_merchant',
            'message' => __('تم تفعيل ضمان الطلب لهذا التاجر الموثّق، سيتم حماية المبلغ أو تعويضك عند حدوث مشكلة.'),
            'verification_expires_at' => $owner->verification_expires_at,
        ];
    }

    protected function extractCartStore(Collection $cartItems): ?Store
    {
        $storeId = $cartItems->pluck('store_id')->filter()->unique()->values()->first();

        if (! $storeId) {
            return null;
        }

        $store = $cartItems
            ->map(static fn (CartItem $cartItem) => $cartItem->item?->store)
            ->filter()
            ->firstWhere('id', $storeId);

        if ($store instanceof Store) {
            $store->loadMissing(['settings', 'workingHours', 'owner.latestApprovedVerificationRequest']);

            return $store;
        }

        return Store::with(['settings', 'workingHours', 'owner.latestApprovedVerificationRequest'])->find($storeId);
    }

    protected function summarizeCartStoreContext(Collection $cartItems): array
    {
        $storeIds = $cartItems->pluck('store_id')->filter()->unique()->values();
        $hasStoreItems = $storeIds->isNotEmpty();
        $hasGeneralItems = $cartItems->contains(static fn (CartItem $cartItem) => $cartItem->store_id === null);

        $storeId = null;
        if ($storeIds->count() === 1) {
            $firstId = $storeIds->first();
            $storeId = $firstId !== null ? (int) $firstId : null;
        }

        return [
            'store_ids' => $storeIds,
            'store_id' => $storeId,
            'has_store_items' => $hasStoreItems,
            'has_general_items' => $hasGeneralItems,
            'multiple_stores' => $storeIds->count() > 1,
        ];
    }

    protected function resolveStoreLogoUrl(?string $path): ?string
    {
        if (! $path) {
            return null;
        }

        try {
            return url(Storage::url($path));
        } catch (\Throwable) {
            return url($path);
        }
    }

    protected function applyStoreCheckoutConstraints(
        Store $store,
        array $status,
        float $subtotal,
        ?array $blocking
    ): ?array {
        $isOpen = (bool) ($status['is_open_now'] ?? false);
        $closureMode = $status['closure_mode'] ?? 'full';

        if (! $isOpen) {
            $nextOpenHuman = $this->formatNextOpenTime($status['next_open_at'] ?? null);
            $message = $nextOpenHuman
                ? __('لا يمكن إكمال الطلب لأن المتجر مغلق حالياً وسيتم فتحه في :time.', ['time' => $nextOpenHuman])
                : __('لا يمكن إكمال الطلب لأن المتجر مغلق حالياً.');

            $blocking = $this->addBlockingReasonToPayload($blocking, 'store_closed', $message, [
                'store_id' => $store->id,
                'next_open_at' => $status['next_open_at'] ?? null,
            ]);
        } elseif ($closureMode === 'browse_only') {
            $message = __('قام التاجر بتفعيل وضع التصفح فقط حالياً، ولا يمكن تنفيذ الطلب.');
            $blocking = $this->addBlockingReasonToPayload($blocking, 'store_browse_only', $message, [
                'store_id' => $store->id,
            ]);
        }

        $minOrderAmount = (float) ($status['min_order_amount'] ?? 0);
        if ($minOrderAmount > 0 && $subtotal + 0.0001 < $minOrderAmount) {
            $message = __('قيمة الطلب الحالية أقل من الحد الأدنى (:amount).', [
                'amount' => number_format($minOrderAmount, 2),
            ]);

            $blocking = $this->addBlockingReasonToPayload($blocking, 'store_min_order', $message, [
                'store_id' => $store->id,
                'required_amount' => $minOrderAmount,
                'current_amount' => $subtotal,
            ]);
        }

        return $blocking;
    }

    protected function formatNextOpenTime(?string $isoString): ?string
    {
        if (! $isoString) {
            return null;
        }

        try {
            return Carbon::parse($isoString)
                ->locale(app()->getLocale())
                ->translatedFormat('d MMM yyyy h:mm a');
        } catch (\Throwable) {
            return $isoString;
        }
    }

    protected function addBlockingReasonToPayload(?array $blocking, string $code, string $message, array $context = []): array
    {
        if (! is_array($blocking)) {
            $blocking = [
                'address_required' => false,
                'currency_conflict' => false,
                'reasons' => [],
            ];
        }

        $blocking['reasons'] ??= [];

        if (! in_array($code, $blocking['reasons'], true)) {
            $blocking['reasons'][] = $code;
        }

        if (! isset($blocking['message'])) {
            $blocking['message'] = $message;
        }

        if ($context !== []) {
            $blocking['context'] ??= [];
            $blocking['context'][$code] = $context;
        }

        return $blocking;
    }

    protected function formatCartStoreSummary(Collection $cartItems, ?Store $store = null): ?array
    {
        $store ??= $this->extractCartStore($cartItems);

        if (! $store) {
            $storeId = $cartItems->pluck('store_id')->filter()->unique()->values()->first();

            if (! $storeId) {
                return null;
            }

            $store = Store::with(['settings', 'workingHours'])->find($storeId);

            if (! $store) {
                return ['id' => $storeId];
            }
        }

        $status = $this->storeStatusService->resolve($store);
        $store->loadMissing(['owner.latestApprovedVerificationRequest']);
        $assurance = $store->owner ? $this->buildStoreAssurancePayload($store) : null;
        $summary = [
            'id' => $store->id,
            'name' => $store->name,
            'slug' => $store->slug,
            'logo_url' => $this->resolveStoreLogoUrl($store->logo_path),
            'status' => $status,
        ];

        if ($store->owner) {
            $summary['owner'] = [
                'id' => $store->owner->id,
                'account_type' => $store->owner->account_type,
                'is_verified' => $store->owner->is_verified,
                'verification_status' => $store->owner->verification_status,
                'verification_expires_at' => $store->owner->verification_expires_at,
            ];
        }

        $manualBanks = $this->resolveStoreManualBanks($store);
        if ($manualBanks !== []) {
            $summary['manual_banks'] = $manualBanks;
        }

        if ($assurance !== null) {
            $summary['assurance'] = $assurance;
        }

        return $summary;
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
        $discounts = $this->resolveDiscounts($user, $selection, $subtotal, $cartItems);

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
    protected function resolveDiscounts(User $user, ?CartCouponSelection $selection, float $subtotal, Collection $cartItems): array
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

        $context = $this->summarizeCartStoreContext($cartItems);

        if ($context['multiple_stores'] || ($context['has_store_items'] && $context['has_general_items'])) {
            $selection->delete();

            return $discounts;
        }

        $storeId = $context['store_id'];

        if ($coupon->store_id !== null) {
            if ($storeId === null || (int) $coupon->store_id !== (int) $storeId) {
                $selection->delete();

                return $discounts;
            }
        } elseif ($storeId === null) {
            // General coupon on general cart - fine.
        }

        if (! $coupon->isCurrentlyActive()) {
            $selection->delete();

            return $discounts;
        }

        if (! $coupon->isWithinUsageLimits($user->getKey())) {
            $selection->delete();

            return $discounts;
        }

        if (! $coupon->meetsMinimumOrder($subtotal)) {
            $selection->delete();

            return $discounts;
        }

        $amount = round($coupon->calculateDiscount($subtotal), 2);
        $discounts['total'] += $amount;


        $discounts['coupons'][] = [
            'id' => $coupon->getKey(),
            'code' => $coupon->code,
            'name' => $coupon->name,
            'amount' => $amount,
            'status' => 'applied',
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
            'variant_key' => ['nullable', 'string', 'max:512'],
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

    protected function existingCartStoreId(User $user): ?int
    {
        return $user->cartItems()
            ->whereNotNull('store_id')
            ->pluck('store_id')
            ->filter()
            ->unique()
            ->values()
            ->first();
    }

    protected function cartHasStoreItems(User $user): bool
    {
        return $user->cartItems()->whereNotNull('store_id')->exists();
    }

    protected function clearGeneralCart(User $user): void
    {
        $user->cartItems()->whereNull('store_id')->delete();
    }

    protected function clearStoreCart(User $user): void
    {
        $user->cartItems()->whereNotNull('store_id')->delete();
    }

    protected function cartHasGeneralItems(User $user): bool
    {
        return $user->cartItems()->whereNull('store_id')->exists();
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
                $query->select(['id', 'name', 'image', 'product_link', 'store_id', 'slug'])
                    ->with([
                        'store' => static function ($storeQuery) {
                            $storeQuery
                                ->select(['id', 'name', 'slug', 'status', 'logo_path', 'timezone'])
                                ->with(['settings', 'workingHours']);
                        },
                    ]);
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
        $storeId = $cartItems->pluck('store_id')->filter()->unique()->values()->first();

        return [
            'user_id' => $user->getKey(),
            'cart_item_count' => $cartItems->count(),
            'cart_total_quantity' => (int) $cartItems->sum('quantity'),
            'cart_subtotal' => $subtotal,
            'departments' => $departments,
            'store_id' => $storeId,
            'cart_currency' => $currency,
        ];
    }


    protected function normalizeCurrency(?string $currency): ?string
    {
        if ($currency === null) {
            return null;
        }

        $trimmed = trim($currency);

        if ($trimmed === '') {
            return null;
        }

        return strtoupper($trimmed);
    
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
     * @return array<int, array<string, mixed>>
     */
    protected function resolveStoreManualBanks(?Store $store): array
    {
        if (! $store) {
            return [];
        }

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
