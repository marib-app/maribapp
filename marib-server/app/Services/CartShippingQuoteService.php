<?php

namespace App\Services;
use App\Models\Address;

use App\Models\CartItem;
use App\Models\Pricing\PricingPolicy;
use App\Models\User;
use App\Services\Exceptions\DeliveryPricingException;
use App\Services\Pricing\ActivePricingPolicyCache;
use Illuminate\Contracts\Cache\Repository as CacheRepository;
use Illuminate\Support\Arr;
use App\Services\DepartmentNoticeService;
use Carbon\Carbon;
use App\Support\DepositCalculator;
use App\Services\OrderCheckoutService;
use App\Services\DepartmentPolicyService;

use App\Models\Item;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class CartShippingQuoteService
{
    private const CACHE_PREFIX = 'cart:shipping_quote:';
    private const CACHE_LATEST_PREFIX = 'cart:shipping_quote_latest:';
    private const CACHE_INDEX_PREFIX = 'cart:shipping_quote_index:';

    private const CACHE_TTL_MINUTES = 10;

    public function __construct(
        private readonly DeliveryPricingService $deliveryPricingService,
        private readonly DepartmentNoticeService $departmentNoticeService,
        private readonly DepartmentPolicyService $departmentPolicyService,
        private readonly ?CacheRepository $cache = null,
    ) {
    }

    /**
     * @param array<string, mixed> $options
     *
     * @return array<string, mixed>
     *
     * @throws ValidationException
     * @throws DeliveryPricingException
     */
    public function quote(User $user, ?string $addressId = null, ?string $department = null, array $options = []): array
    {
        $requestId = (string) Str::uuid();
        $normalizedTiming = OrderCheckoutService::normalizeTimingToken($options['timing'] ?? null);
        $depositEnabled = (bool) ($options['deposit_enabled'] ?? false);

        $cartItems = $this->loadCartItems($user);

        if ($cartItems->isEmpty()) {
            Log::warning('cart.shipping_quote.empty_cart', [
                'request_id' => $requestId,
                'user_id' => $user->id,
            ]);

            throw ValidationException::withMessages([
                'cart' => __('سلة التسوق فارغة.'),
            ]);
        }

        $resolvedDepartment = $this->resolveDepartment($cartItems, $department);
        $address = $this->resolveAddress($user, $addressId);

        if (! $address) {
            Log::warning('cart.shipping_quote.address_missing', [
                'request_id' => $requestId,
                'user_id' => $user->id,
                'address_id' => $addressId,
            ]);

            throw $this->addressRequiredException();

        }


        if (! $this->addressHasValidCoordinates($address)) {


            Log::warning('cart.shipping_quote.address_coordinates_missing', [


                'request_id' => $requestId,
                'user_id' => $user->id,
                'address_id' => $addressId,
                'address' => $this->addressToArray($address),
            ]);

            throw $this->addressRequiredException();

        }


        $distanceKm = $this->resolveDistance($address);
        $distanceKm = is_numeric($distanceKm) ? (float) $distanceKm : null;


        $cartValue = (float) $this->calculateCartValue($cartItems);
        $weightTotal = (float) $this->calculateCartWeight($cartItems);
        $departmentPolicyData = $this->departmentPolicyService->policyFor($resolvedDepartment);
        $departmentPolicy = $this->resolveDepartmentDepositPolicy($resolvedDepartment, $departmentPolicyData);
        
        $depositSummary = DepositCalculator::summarizePolicy($departmentPolicy);

        $vendorId = $this->resolveVendorId($cartItems);

        [$policy, $fallbackUsed] = $this->resolvePolicy($resolvedDepartment, $vendorId);
        $policyVersion = $this->resolvePolicyVersion($policy);


        $addressKey = $this->addressIdentifier($addressId, $address);
        $resolvedAddressId = $this->resolvedAddressId($addressId, $address);

        $cacheKey = $this->cacheKey(
            $user->id,
            $addressKey,
            $resolvedDepartment,
            $cartValue,
            $weightTotal,
            $policyVersion,
            $depositEnabled,
        );


        if (! empty($options['force_refresh'])) {
            $this->cache()->forget($cacheKey);
            $this->cache()->forget(self::latestCacheKeyFor($user->id, $resolvedDepartment));


        }

        $cachedPayload = $this->cache()->get($cacheKey);

        if (is_array($cachedPayload)) {
            if ($this->quotePayloadExpired($cachedPayload)) {
                Log::info('cart.shipping_quote.cache_expired', [
                    'request_id' => $requestId,
                    'user_id' => $user->id,
                    'cache_key' => $cacheKey,
                ]);

                $this->cache()->forget($cacheKey);
            } else {
                Log::info('cart.shipping_quote.cache_hit', [
                    'request_id' => $requestId,
                    'user_id' => $user->id,
                    'cache_key' => $cacheKey,
                ]);

                return $this->formatResponse(
                    $cachedPayload,
                    $requestId,
                    $policy,
                    $fallbackUsed,
                    $policyVersion,
                    true,
                );
            }
        }

        Log::info('cart.shipping_quote.compute', [
            'request_id' => $requestId,
            'user_id' => $user->id,
            'address_id' => $addressId,
            'department' => $resolvedDepartment,
            'cart_value' => $cartValue,
            'weight_total' => $weightTotal,
            'policy_id' => $policy->id,
            'policy_department' => $policy->department,
            'fallback_used' => $fallbackUsed,
            'policy_version' => $policyVersion,
        ]);



                $pricingRequest = [
            'order_total' => (float) $cartValue,
            'distance_km' => $distanceKm,
            'weight_total' => (float) $weightTotal,
            'department' => $resolvedDepartment,
            'currency' => strtoupper((string) ($policy->currency ?? config('app.currency', 'YER'))),
        ];

        foreach (['payment', 'timing'] as $optionKey) {
            if ($optionKey === 'timing') {
                if ($normalizedTiming !== null) {
                    $pricingRequest[$optionKey] = $normalizedTiming;
                }

                continue;
            }

            if (array_key_exists($optionKey, $options)) {
                $pricingRequest[$optionKey] = $options[$optionKey];
            }
        }

        try {

            $result = $this->deliveryPricingService->calculate($pricingRequest);

        } catch (DeliveryPricingException $exception) {
            Log::error('cart.shipping_quote.failed', [
                'request_id' => $requestId,
                'user_id' => $user->id,
                'address_id' => $addressId,
                'department' => $resolvedDepartment,
                'cart_value' => $cartValue,
                'weight_total' => $weightTotal,
                'policy_id' => $policy->id,
                'error' => $exception->getMessage(),
            ]);

            throw $exception;
        }

        $payload = $this->buildPayload(
            $result,
            $policy,
            $fallbackUsed,
            $policyVersion,
            $resolvedDepartment,
            $cartValue,
            $weightTotal,
            $distanceKm,
            $departmentPolicyData,
            $depositSummary,
            $depositEnabled,

        );


        if ($normalizedTiming !== null) {
            $payload['delivery_payment_timing'] = $normalizedTiming;
        }



        $payload['address_id'] = $resolvedAddressId;
        $payload['context'] = array_merge($payload['context'] ?? [], [
            'address_id' => $resolvedAddressId,
        ]);
        $payload['meta'] = array_merge($payload['meta'] ?? [], [
            'address_key' => $addressKey,
            'cart_value' => $cartValue,
            'weight_total' => $weightTotal,
            'department' => $resolvedDepartment,
        ]);

        $this->cache()->put($cacheKey, $payload, now()->addMinutes(self::CACHE_TTL_MINUTES));

        $this->rememberCacheKey($user->id, $cacheKey);


        $referencePayload = [
            'cache_key' => $cacheKey,
            'address_id' => $resolvedAddressId,
            'address_key' => $addressKey,
            'cart_value' => $cartValue,
            'weight_total' => $weightTotal,
            'policy_version' => $policyVersion,
            'quote_id' => $payload['quote_id'] ?? null,
            'quote_expires_at' => $payload['expires_at'] ?? null,
            'created_at' => now()->timestamp,            
            'deposit_enabled' => $depositEnabled,


        ];

        if ($normalizedTiming !== null) {
            $referencePayload['delivery_payment_timing'] = $normalizedTiming;
            $referencePayload['delivery_payment_timing_recorded_at'] = now()->timestamp;
        }


        $this->storeLatestReference(
            $user->id,
            $resolvedDepartment,

            $referencePayload

        );

        return $this->formatResponse(
            $payload,
            $requestId,
            $policy,
            $fallbackUsed,
            $policyVersion,
            false,
        );
    }

    private function loadCartItems(User $user): Collection
    {
        return $user->cartItems()->with('item')->get();
    }

    private function resolveDepartment(Collection $cartItems, ?string $requested): ?string
    {
        if ($requested !== null && $requested !== '') {
            return $requested;
        }

        return $cartItems->pluck('department')->filter()->unique()->values()->first();
    }



   /**
     * @return array<string, mixed>|null
     */
    private function resolveDepartmentDepositPolicy(?string $department, ?array $policyData = null): ?array
    {
        if ($department === null || $department === '') {
            if (is_array($policyData)) {
                $text = $policyData['return_policy_text'] ?? null;
                if ($text !== null && $text !== '') {
                    return ['return_policy_text' => $text];
                }
            }

            return null;
        }

        $policy = is_array($policyData) ? $policyData : $this->departmentPolicyService->policyFor($department);
        $deposit = is_array($policy['deposit'] ?? null) ? $policy['deposit'] : [];


        if (! array_key_exists('department', $deposit)) {
            $deposit['department'] = $department;
        }

        if (! array_key_exists('return_policy_text', $deposit)) {
            $deposit['return_policy_text'] = $policy['return_policy_text'] ?? null;
        }


        $ratio = (float) ($deposit['ratio'] ?? 0.0);
        $minimum = (float) ($deposit['minimum_amount'] ?? 0.0);
        $text = $deposit['return_policy_text'] ?? null;


        $hasPolicyText = is_string($text) && trim($text) !== '';
        if ($ratio <= 0.0 && $minimum <= 0.0 && ! $hasPolicyText) {


            return null;
        }
        return $deposit;

    }


    private function resolveVendorId(Collection $cartItems): ?int
    {
        foreach ($cartItems as $cartItem) {
            $item = $cartItem->item;

            if ($item instanceof Item && $item->user_id) {
                return (int) $item->user_id;
            }
        }

        return null;
    }


    /**
     * @return array<string, mixed>|null
     */
    private function resolveAddress(User $user, ?string $addressId): ?Address
    {
        if ($addressId === null || $addressId === '') {


            return null;
        }

        return $user->addresses()->whereKey($addressId)->first();




    }

    public function ensureUserHasValidAddress(User $user, ?string $department = null): void
    {
        $address = $this->resolveCurrentAddress($user, $department);

        if (! $address || ! $this->addressHasValidCoordinates($address)) {
            throw $this->addressRequiredException();
        }



    
    }

    /**
     * @param Address|array<string, mixed>|null $address
     */
    private function resolveDistance(Address|array|null $address): ?float
    {
        if ($address === null) {
            return null;
        }

        if ($address instanceof Address) {
            $distance = $address->distance_km;

            return $distance === null ? null : (float) $distance;
        }



        $distance = Arr::get($address, 'distance_km', Arr::get($address, 'distance'));

        if ($distance === null) {
            return null;
        }

        return (float) $distance;
    }


    private function resolveCoordinate(Address|array|null $address, string $key): ?float
    {
        if ($address === null) {
            return null;
        }

        if ($address instanceof Address) {
            $value = $address->{$key} ?? null;

            return $value === null ? null : (float) $value;
        }

        $value = Arr::get($address, $key);

        if ($value === null) {
            return null;
        }

        return (float) $value;
    }




    private function addressHasValidCoordinates(Address|array|null $address): bool
    {
        if ($address === null) {
            return false;
        }

        $latitude = $this->resolveCoordinate($address, 'latitude');
        $longitude = $this->resolveCoordinate($address, 'longitude');
        $distanceKm = $this->resolveDistance($address);

        return $latitude !== null && $longitude !== null && $distanceKm !== null && $distanceKm >= 0;
    }

    private function resolveCurrentAddress(User $user, ?string $department): ?Address
    {
        $latestKey = self::latestCacheKeyFor($user->id, $department);
        $reference = $this->cache()->get($latestKey);

        $addressId = null;

        if (is_array($reference)) {
            $addressId = $reference['address_id'] ?? null;

            if ($addressId !== null && $addressId !== '') {
                $address = $this->resolveAddress($user, (string) $addressId);

                if ($address) {
                    return $address;
                }
            }
        }

        $defaultAddress = $user->addresses()
            ->where('is_default', true)
            ->first();

        if ($defaultAddress) {
            return $defaultAddress;
        }

        return $user->addresses()->latest('id')->first();
    }





    private function calculateCartValue(Collection $cartItems): float
    {
        return (float) $cartItems->reduce(static function (float $carry, CartItem $item) {
            return $carry + ($item->quantity * $item->getLockedUnitPrice());
        }, 0.0);
    }

    private function calculateCartWeight(Collection $cartItems): float
    {
        return (float) $cartItems->reduce(function (float $carry, CartItem $item) {
            return $carry + $this->resolveItemWeight($item);
        }, 0.0);
    }

    private function resolveItemWeight(CartItem $item): float
    {
        $quantity = max(1, (int) $item->quantity);
        $snapshot = is_array($item->stock_snapshot) ? $item->stock_snapshot : [];

        if (array_key_exists('weight_total', $snapshot)) {
            return (float) $snapshot['weight_total'];
        }

        $weightPerUnit = $this->normalizeWeightValue($snapshot);

        if ($weightPerUnit === null && is_array($item->attributes)) {
            $weightPerUnit = $this->normalizeWeightValue($item->attributes);
        }

        if ($weightPerUnit === null) {
            $deliverySize = $item->item?->delivery_size;
            $numericDelivery = $this->normalizeDeliverySizeWeight($deliverySize);

            if ($numericDelivery !== null) {
                $weightPerUnit = $numericDelivery;
            } elseif (is_string($deliverySize) && $deliverySize !== '') {


                $normalizedSize = strtolower(trim($deliverySize));
                $sizeWeightMap = config('services.delivery_pricing.size_weight_map', []);

                if (is_array($sizeWeightMap) && array_key_exists($normalizedSize, $sizeWeightMap)) {
                    $weightPerUnit = (float) $sizeWeightMap[$normalizedSize];
                }
            }
        }



        if ($weightPerUnit === null) {
            return 0.0;
        }

        return (float) $weightPerUnit * $quantity;
    }


    private function normalizeDeliverySizeWeight(mixed $value): ?float
    {
        if ($value === null) {
            return null;
        }

        if (is_numeric($value)) {
            $weight = (float) $value;
        } elseif (is_string($value)) {
            $normalized = strtr($value, [
                '٠' => '0',
                '١' => '1',
                '٢' => '2',
                '٣' => '3',
                '٤' => '4',
                '٥' => '5',
                '٦' => '6',
                '٧' => '7',
                '٨' => '8',
                '٩' => '9',
                '۰' => '0',
                '۱' => '1',
                '۲' => '2',
                '۳' => '3',
                '۴' => '4',
                '۵' => '5',
                '۶' => '6',
                '۷' => '7',
                '۸' => '8',
                '۹' => '9',
                '٫' => '.',
                '،' => '.',
            ]);

            $normalized = str_replace(',', '.', trim($normalized));

            
            if ($normalized === '') {
                return null;
            }

            if (str_starts_with($normalized, '.')) {
                $normalized = '0' . $normalized;
            }

            if (!preg_match('/^(?:\d+)(?:\.\d+)?$/', $normalized)) {
                return null;
            }

            $weight = (float) $normalized;
        } else {
            return null;
        }

        if ($weight <= 0) {
            return null;
        }

        return round($weight, 3);
    }



    /**
     * @param array<string, mixed> $data
     */
    private function normalizeWeightValue(array $data): ?float
    {
        if (array_key_exists('weight_total', $data)) {
            return (float) $data['weight_total'];
        }

        if (array_key_exists('weight_kg', $data)) {
            return (float) $data['weight_kg'];
        }

        if (array_key_exists('weight', $data)) {
            $weight = (float) $data['weight'];
            $unit = strtolower((string) ($data['weight_unit'] ?? 'kg'));

            if ($unit === 'g' || $unit === 'gram' || $unit === 'grams') {
                return $weight / 1000;
            }

            return $weight;
        }

        if (array_key_exists('weight_g', $data)) {
            return ((float) $data['weight_g']) / 1000;
        }

        if (array_key_exists('weight_per_unit', $data)) {
            return (float) $data['weight_per_unit'];
        }

        return null;
    }

    /**
     * @return array{0: PricingPolicy, 1: bool}
     *
     * @throws ValidationException
     */
    private function resolvePolicy(?string $department, ?int $vendorId = null): array
    {
        $policy = ActivePricingPolicyCache::get($department, $vendorId);

        if (! $policy) {
            throw ValidationException::withMessages([
                'policy' => __('لم يتم العثور على سياسة تسعير نشطة.'),
            ]);
        }

        $vendorMatched = $vendorId !== null && (int) $policy->vendor_id === $vendorId;

        if ($vendorMatched) {
            return [$policy, false];
        }

        $fallbackUsed = false;

        if ($vendorId !== null) {
            $fallbackUsed = true;
        }

        if ($department !== null && $policy->department !== $department) {
            $fallbackUsed = true;
        }
        return [$policy, $fallbackUsed];
    }

    private function resolvePolicyVersion(PricingPolicy $policy): string
    {
        $timestamp = $policy->updated_at?->timestamp ?? $policy->created_at?->timestamp ?? time();

        return sha1($policy->id . '|' . $policy->code . '|' . $timestamp . '|' . $policy->mode);
    }

    /**
     * @param array<string, mixed> $payload
     */
    private function formatResponse(
        array $payload,
        string $requestId,
        PricingPolicy $policy,
        bool $fallbackUsed,
        string $policyVersion,
        bool $cached,
    ): array {
        $department = $this->extractDepartmentFromPayload($payload);
        $departmentPolicy = $payload['department_policy'] ?? null;

        if ($departmentPolicy === null && $department !== null) {
            $departmentPolicy = $this->departmentPolicyService->policyFor($department);

            
        }

        return array_merge(
            $payload,
            [
                'policy' => array_merge($payload['policy'] ?? [], [
                    'fallback_used' => $fallbackUsed,
                ]),
                'meta' => array_merge($payload['meta'] ?? [], [
                    'cached' => $cached,
                    'request_id' => $requestId,
                    'policy_version' => $policyVersion,
                ]),
                'department_notice' => $this->departmentNoticeService->getActiveNotice($department),
                'department_policy' => $departmentPolicy,


            ],
        );
    }

    private function extractDepartmentFromPayload(array $payload): ?string
    {
        $meta = $payload['meta'] ?? null;
        $department = is_array($meta) ? ($meta['department'] ?? null) : null;

        if (! is_string($department) || $department === '') {
            $context = $payload['context'] ?? null;
            $department = is_array($context) ? ($context['department'] ?? null) : ($payload['department'] ?? null);
        }

        if (! is_string($department) || $department === '') {
            return null;
        }

        return $department;
    }



    private function addressIdentifier(?string $addressId, Address|array|null $address): string
    {
        if ($addressId !== null && $addressId !== '') {
            return $addressId;
        }


        if ($address instanceof Address) {
            return (string) $address->getKey();
        }

        if ($address && array_key_exists('id', $address)) {
            return (string) $address['id'];
        }

        $encoded = json_encode($address);

        if ($encoded === false) {
            return sha1(serialize($address));
        }

        return sha1($encoded);
    }


    /**
     * @return array<string, mixed>|null
     */
    private function addressToArray(?Address $address): ?array
    {
        return $address?->attributesToArray();
    }


    private function cacheKey(
        int $userId,
        string $addressKey,
        ?string $department,
        float $cartValue,
        float $weightTotal,
        string $policyVersion,
        bool $depositEnabled,
    ): string {
        return self::CACHE_PREFIX . implode(':', [
            $userId,
            $addressKey,
            $department ?? 'default',
            number_format($cartValue, 2, '.', ''),
            number_format($weightTotal, 3, '.', ''),
            $policyVersion,
            $depositEnabled ? 'deposit:on' : 'deposit:off',
        ]);
    }

    public static function latestCacheKeyFor(int $userId, ?string $department): string
    {
        return self::CACHE_LATEST_PREFIX . implode(':', [
            $userId,
            $department ?? 'default',
        ]);
    
    }




    public static function cacheIndexKeyFor(int $userId): string
    {
        return self::CACHE_INDEX_PREFIX . $userId;
    }

    public function clearCachedQuotes(User $user): void
    {
        $indexKey = $this->cacheIndexKey($user->id);
        $keys = $this->cache()->get($indexKey);

        if (is_array($keys)) {
            foreach ($keys as $key) {
                if (is_string($key) && $key !== '') {
                    $this->cache()->forget($key);
                }
            }
        }

        $this->cache()->forget($indexKey);
    }

    public function computeCartMetrics(Collection $cartItems): array



    {
        return [
            'cart_value' => $this->calculateCartValue($cartItems),
            'weight_total' => $this->calculateCartWeight($cartItems),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function buildPayload(
        DeliveryPricingResult $result,
        PricingPolicy $policy,
        bool $fallbackUsed,
        string $policyVersion,
        ?string $department,
        float $cartValue,
        float $weightTotal,
        float $distance,
        array $departmentPolicy,
        array $depositSummary,

        bool $depositEnabled,

    ): array {
        $raw = $result->getRawData();
        $currency = strtoupper((string) ($raw['currency'] ?? $policy->currency ?? config('app.currency', 'YER')));


        $quoteReference = $this->normalizeQuoteReference($raw);
        $meta = $this->buildPayloadMeta($raw, $quoteReference, $policyVersion);

        $freeApplied = null;

        if (array_key_exists('free_applied', $raw)) {
            $freeApplied = (bool) $raw['free_applied'];
        } elseif ($result->freeApplied === true) {
            $freeApplied = true;
        }

        if ($freeApplied === null) {
            $freeApplied = (bool) ($raw['free_shipping_applied'] ?? $raw['free_shipping'] ?? false);
        }

        $paymentOptions = $result->getPaymentOptions();

        if (empty($paymentOptions)) {
            $paymentFromRaw = $raw['payment'] ?? [];

            if (is_array($paymentFromRaw)) {
                $paymentOptions = $paymentFromRaw;
            }
        }


        $payment = [
            'collect_on_delivery' => (bool) ($paymentOptions['collect_on_delivery'] ?? $raw['collect_on_delivery'] ?? false),
            'prepaid_required' => (bool) ($paymentOptions['prepaid_required'] ?? $raw['prepaid_required'] ?? false),
            'due_now' => (bool) ($paymentOptions['due_now'] ?? $raw['due_now'] ?? true),
            'allow_pay_now' => $result->allowsPayNow(),
            'allow_pay_on_delivery' => $result->allowsPayOnDelivery(),
            'cod_fee' => $result->getCodFee(),
        ];

        $timingCodes = $result->getTimingCodes();
        $suggestedTiming = $result->getSuggestedTiming() ?? ($raw['suggested_timing'] ?? null);

        if (! empty($timingCodes)) {
            $payment['timing_codes'] = $timingCodes;
        }

        if ($suggestedTiming !== null) {
            $payment['suggested_timing'] = $suggestedTiming;
        }


        $distanceKm = (float) ($raw['distance_km'] ?? $raw['distance'] ?? $distance);
        $weightTotalValue = $raw['weight_total']
            ?? $raw['weight_kg']
            ?? $raw['weight']
            ?? $weightTotal;

        $codFee = $result->getCodFee();



        $payload = [
            'amount' => (float) ($raw['total'] ?? $result->total),
            'currency' => $currency,
            'free_applied' => $freeApplied,
            'eta' => $raw['eta'] ?? null,
            'breakdown' => $result->getBreakdown(),
            'policy_id' => $policy->id,
            'rule_id' => $result->getRuleId(),
            'tier_id' => $result->getTierId(),
            'distance_km' => (float) $distanceKm,
            'weight_total' => (float) $weightTotalValue,
            'allow_pay_now' => $result->allowsPayNow(),
            'allow_pay_on_delivery' => $result->allowsPayOnDelivery(),
            'cod_fee' => $codFee,
            'suggested_timing' => $suggestedTiming,
            'timing_codes' => $timingCodes,

            'policy' => [
                'id' => $policy->id,
                'code' => $policy->code,
                'department' => $policy->department,
                'mode' => $policy->mode,
                'version' => $policyVersion,
                'fallback_used' => $fallbackUsed,
            ],
            'payment' => $payment,
            'context' => [
                'department' => $department,
                'cart_value' => $cartValue,
                'weight_total' => (float) $weightTotalValue,
                'distance_km' => $distanceKm,
            ],
            'meta' => $meta,
        ];

        if ($departmentPolicy !== []) {
            $payload['department_policy'] = $departmentPolicy;
        }


        $depositPayload = $this->buildDepositPayload(
            $depositSummary,
            $cartValue,
            (float) ($payload['amount'] ?? 0.0),
            $depositEnabled,
        );

        if ($depositPayload !== null) {
            $payload['deposit'] = $depositPayload;
        }


        if (isset($quoteReference['id'])) {
            $payload['quote_id'] = $quoteReference['id'];

            if (! isset($payload['id']) || $payload['id'] === null || $payload['id'] === '') {
                $payload['id'] = $quoteReference['id'];
            }
        }

        if (isset($quoteReference['expires_at'])) {
            $payload['expires_at'] = $quoteReference['expires_at'];
        }

        return $payload;
    }




    /**
     * @param array<string, mixed> $summary
     * @return array<string, mixed>|null
     */
    private function buildDepositPayload(array $summary, float $goodsTotal, float $deliveryTotal, bool $depositEnabled): ?array
    {
        $ratio = (float) ($summary['ratio'] ?? 0.0);
        if ($ratio <= 0.0) {

            
            return null;
        }


        $returnPolicyText = $summary['return_policy_text'] ?? null;
        $policy = $summary['policy'] ?? null;

 
        if (is_array($policy) && ! array_key_exists('raw', $policy)) {
            $policy['raw'] = $policy;
 
    }

        $payload = [
            'available' => true,
            'enabled' => $depositEnabled,


            'ratio' => round($ratio, 4),
        ];

        if (is_array($policy)) {
            $payload['policy'] = $policy;
        }

        if ($returnPolicyText !== null) {
            $payload['return_policy_text'] = $returnPolicyText;
        }

        if ($depositEnabled) {
            $required = DepositCalculator::calculateRequiredAmount($summary, $goodsTotal, $deliveryTotal);
            $required = round(max($required, 0.0), 2);
            $orderTotal = round($goodsTotal + $deliveryTotal, 2);
            $remainingOrderBalance = round(max($orderTotal - $required, 0.0), 2);
            $remainingGoodsBalance = round(max($goodsTotal - $required, 0.0), 2);

            $payload['details'] = [
                'required_amount' => $required,
                'paid_amount' => 0.0,
                'remaining_amount' => $required,
                'goods_total' => round($goodsTotal, 2),
                'delivery_total' => round($deliveryTotal, 2),
                'ratio' => round($ratio, 4),
                'status' => $required > 0.0 ? 'pending' : 'waived',
                'total_order_amount' => $orderTotal,
                'remaining_order_balance' => $remainingOrderBalance,
                'remaining_goods_balance' => $remainingGoodsBalance,
            ];

            if (is_array($policy)) {
                $payload['details']['policy'] = $policy;
            }

            if ($returnPolicyText !== null) {
                $payload['details']['return_policy_text'] = $returnPolicyText;
            }
        }

        return $payload;
    }






    /**
     * @param array<string, mixed> $payload
     */
    private function quotePayloadExpired(array $payload): bool
    {
        $expiresAt = $payload['expires_at'] ?? Arr::get($payload, 'meta.quote.expires_at');

        if ($expiresAt === null || $expiresAt === '') {
            return false;
        }

        try {
            $expiry = $this->normalizeQuoteExpiration($expiresAt);
        } catch (\Throwable) {
            return false;
        }

        if ($expiry === null) {
            return false;
        }

        return Carbon::parse($expiry)->isPast();
    }

    /**
     * @param array<string, mixed> $raw
     * @return array<string, mixed>
     */
    private function buildPayloadMeta(array $raw, array $quoteReference, string $policyVersion): array
    {
        $meta = [];

        if (isset($raw['meta']) && is_array($raw['meta'])) {
            $meta = $raw['meta'];
        }

        if (isset($quoteReference['metadata'])) {
            $quoteMeta = $quoteReference['metadata'];
        } else {
            $quoteMeta = [];
        }

        $existingQuoteMeta = [];

        if (isset($meta['quote']) && is_array($meta['quote'])) {
            $existingQuoteMeta = $meta['quote'];
        }

        $meta = array_replace_recursive($meta, [
            'cached' => false,
            'policy_version' => $policyVersion,
        ]);

        if ($quoteReference !== []) {
            $meta['quote'] = $this->mergeQuoteReferenceMeta($existingQuoteMeta, $quoteReference);
        }

        return $this->removeEmptyMetaValues($meta);
    }

    /**
     * @param array<string, mixed> $current
     * @param array<string, mixed> $reference
     * @return array<string, mixed>
     */
    private function mergeQuoteReferenceMeta(array $current, array $reference): array
    {
        $merged = array_replace_recursive($current, $reference);

        if (! array_key_exists('id', $reference) && array_key_exists('id', $current)) {
            $merged['id'] = $current['id'];
        }

        if (! array_key_exists('expires_at', $reference) && array_key_exists('expires_at', $current)) {
            $merged['expires_at'] = $current['expires_at'];
        }

        if (isset($current['metadata']) && isset($reference['metadata']) && is_array($current['metadata']) && is_array($reference['metadata'])) {
            $merged['metadata'] = array_replace_recursive($current['metadata'], $reference['metadata']);
        } elseif (! array_key_exists('metadata', $reference) && array_key_exists('metadata', $current)) {
            $merged['metadata'] = $current['metadata'];
        }

        return $this->removeEmptyMetaValues($merged);
    }

    /**
     * @param array<string, mixed> $data
     * @return array<string, mixed>
     */
    private function removeEmptyMetaValues(array $data): array
    {
        foreach ($data as $key => $value) {
            if ($value === null) {
                unset($data[$key]);

                continue;
            }

            if (is_array($value)) {
                $cleaned = $this->removeEmptyMetaValues($value);

                if ($cleaned === []) {
                    unset($data[$key]);

                    continue;
                }

                $data[$key] = $cleaned;
            }
        }

        return $data;
    }

    /**
     * @param array<string, mixed> $raw
     * @return array<string, mixed>
     */
    private function normalizeQuoteReference(array $raw): array
    {
        $quoteSources = [];

        $quote = $raw['quote'] ?? null;

        if (is_array($quote)) {
            $quoteSources[] = $quote;
        }

        $metaQuote = Arr::get($raw, 'meta.quote');

        if (is_array($metaQuote)) {
            $quoteSources[] = $metaQuote;
        }

        $normalized = [];

        foreach ($quoteSources as $source) {
            $normalized = array_replace_recursive($normalized, $source);
        }

        $idCandidates = [
            $raw['quote_id'] ?? null,
            $raw['id'] ?? null,
            $normalized['quote_id'] ?? null,
            $normalized['id'] ?? null,
        ];

        $id = $this->firstNonEmptyString($idCandidates);

        $expiresCandidates = [
            $raw['expires_at'] ?? null,
            $raw['quote_expires_at'] ?? null,
            $normalized['expires_at'] ?? null,
        ];

        $expiresAt = null;

        foreach ($expiresCandidates as $candidate) {
            $expiresAt = $this->normalizeQuoteExpiration($candidate);

            if ($expiresAt !== null) {
                break;
            }
        }

        $metadata = [];

        $metadataSources = [
            $normalized['metadata'] ?? null,
            $normalized['meta'] ?? null,
            Arr::get($raw, 'quote.metadata'),
            Arr::get($raw, 'quote.meta'),
            Arr::get($raw, 'meta.quote.metadata'),


        ];


        foreach ($metadataSources as $source) {
            if (is_array($source)) {
                $metadata = array_replace_recursive($metadata, $source);
            }
        }

        $reference = [];

        if ($id !== null) {
            $reference['id'] = $id;
        }

        if ($expiresAt !== null) {
            $reference['expires_at'] = $expiresAt;
        }

        if ($metadata !== []) {
            $reference['metadata'] = $metadata;
        }

        return $reference;
    }

    private function firstNonEmptyString(array $candidates): ?string
    {
        foreach ($candidates as $candidate) {
            if (is_string($candidate) && trim($candidate) !== '') {
                return $candidate;
            }

            if (is_numeric($candidate)) {
                $stringCandidate = (string) $candidate;

                if ($stringCandidate !== '') {
                    return $stringCandidate;
                }
            }
        }

        return null;
    }

    private function normalizeQuoteExpiration(mixed $value): ?string
    {
        if ($value === null || $value === '') {
            return null;
        }

        if (is_numeric($value)) {
            return Carbon::createFromTimestamp((int) $value)->toIso8601String();
        }

        if (is_string($value)) {
            try {
                return Carbon::parse($value)->toIso8601String();
            } catch (\Throwable) {
                return null;
            }
        }

        return null;

    }

    private function resolvedAddressId(?string $addressId, Address|array|null $address): ?string
    {
        if ($addressId !== null && $addressId !== '') {
            return $addressId;
        }

        if ($address instanceof Address) {
            return (string) $address->getKey();
        }

        if (is_array($address) && array_key_exists('id', $address)) {
            return (string) $address['id'];
        }

        return null;
    }


    private function addressRequiredException(): ValidationException
    {
        return ValidationException::withMessages([
            'address_id' => __('يجب اختيار عنوان صالح لحساب رسوم الشحن.'),
        ])->errorBag('address_required');
    }


    private function cacheIndexKey(int $userId): string
    {
        return self::cacheIndexKeyFor($userId);
    }

    private function rememberCacheKey(int $userId, string $key): void
    {
        $indexKey = $this->cacheIndexKey($userId);
        $keys = $this->cache()->get($indexKey);

        if (! is_array($keys)) {
            $keys = [];
        }

        if (! in_array($key, $keys, true)) {
            $keys[] = $key;
        }

        $this->cache()->put($indexKey, $keys, now()->addMinutes(self::CACHE_TTL_MINUTES));
    }

    /**
     * @param array<string, mixed> $reference
     */
    private function storeLatestReference(int $userId, ?string $department, array $reference): void
    {
        $latestKey = self::latestCacheKeyFor($userId, $department);


                $existing = $this->cache()->get($latestKey);

        if (is_array($existing)) {
            $reference = array_merge($existing, $reference);
        }


        $reference['department'] = $department;


        if (array_key_exists('delivery_payment_timing', $reference) && ($reference['delivery_payment_timing'] ?? null) === null) {
            unset($reference['delivery_payment_timing_recorded_at']);
        }


        $this->cache()->put($latestKey, $reference, now()->addMinutes(self::CACHE_TTL_MINUTES));
        $this->rememberCacheKey($userId, $latestKey);
    }

    

    public function rememberDeliveryPaymentTiming(User $user, ?string $department, ?string $timing): void
    {
        $normalized = OrderCheckoutService::normalizeTimingToken($timing);
        $latestKey = self::latestCacheKeyFor($user->id, $department);
        $existing = $this->cache()->get($latestKey);

        if (! is_array($existing)) {
            return;
        }

        $payload = [
            'delivery_payment_timing' => $normalized,
        ];

        if ($normalized !== null) {
            $payload['delivery_payment_timing_recorded_at'] = now()->timestamp;
        }

        $this->storeLatestReference($user->id, $department, $payload);
    }

    public function getStoredDeliveryPaymentTiming(User $user, ?string $department = null): ?string
    {
        if ($department !== null) {
            $latestKey = self::latestCacheKeyFor($user->id, $department);
            $reference = $this->cache()->get($latestKey);

            return is_array($reference)
                ? ($reference['delivery_payment_timing'] ?? null)
                : null;
        }

        $keys = $this->cache()->get($this->cacheIndexKey($user->id));

        if (! is_array($keys)) {
            return null;
        }

        foreach (array_reverse($keys) as $key) {
            if (! is_string($key) || $key === '' || ! Str::startsWith($key, self::CACHE_LATEST_PREFIX)) {
                continue;
            }

            $reference = $this->cache()->get($key);

            if (is_array($reference) && array_key_exists('delivery_payment_timing', $reference)) {
                return $reference['delivery_payment_timing'];
            }
        }

        return null;
    }


    private function cache(): CacheRepository
    {
        return $this->cache ?? Cache::store();
    }
}