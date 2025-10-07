<?php

namespace App\Http\Controllers;


use App\Models\DeliveryPrice;
use App\Models\Pricing\PricingDistanceRule;
use App\Models\ShippingOverride;
use App\Models\User;
use App\Models\Pricing\PricingPolicy;
use App\Models\Pricing\PricingWeightTier;
use App\Services\Pricing\ActivePricingPolicyCache;
use App\Services\Pricing\PricingAuditLogger;
use Illuminate\Http\RedirectResponse;
use Illuminate\Validation\ValidationException;
use App\Services\DepartmentReportService;
use App\Services\ResponseService;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Validation\Rule;
use Illuminate\Support\Arr;


class DeliveryPriceController extends Controller
{
    public function __construct(
        protected DepartmentReportService $departmentReportService,
        protected PricingAuditLogger $pricingAuditLogger



    ) {


    }



    public function index(Request $request)
    {
        ResponseService::noAnyPermissionThenRedirect(['delivery-prices-list']);
        

        $departments = $this->departmentReportService->availableDepartments();
        $department = $this->resolveDepartment($request->get('department'));
        $vendors = $this->loadVendorOptions();
        $vendorId = $this->resolveVendor($request->get('vendor'), $vendors);

        
        $deliveryPrices = DeliveryPrice::department($department)

            ->get()
            ->sortBy(fn ($price) => sprintf('%s-%015.2f', $price->size ?? '', $price->min_distance ?? 0))
            ->values();
        $policy = ActivePricingPolicyCache::get($department, $vendorId);

        if (!$policy) {
            $policy = $this->resolvePolicyForDepartment($department);
            ActivePricingPolicyCache::forget($policy->department);
            ActivePricingPolicyCache::forget($policy->department, $vendorId);
            $policy = ActivePricingPolicyCache::get($policy->department, $vendorId) ?? $policy;

                }

        if ($policy) {
            $policy = PricingPolicy::query()
                ->with([
                    'weightTiers' => function ($tierQuery) {
                        $tierQuery->orderBy('min_weight')
                            ->orderBy('id')
                            ->with([
                                'distanceRules' => function ($ruleQuery) {
                                    $ruleQuery->orderBy('min_distance')
                                        ->orderBy('id');
                                },
                            ]);
                    },

                    
                    'distanceRules' => function ($ruleQuery) {
                        $ruleQuery->orderBy('min_distance')
                            ->orderBy('id');
                    },

                ])
                ->find($policy->getKey()) ?? $policy;

        }





        $policyModes = [
            PricingPolicy::MODE_DISTANCE_ONLY => 'حسب المسافة',
            PricingPolicy::MODE_WEIGHT_DISTANCE => 'الوزن + المسافة',
        ];



        $paymentSettings = $this->resolvePaymentSettings(
            $policy,
            $department,
            $vendorId,
            $vendors,
            $departments
        );


        return view('delivery-prices.index', [
            'departments' => $departments,
            'department' => $department,
            'vendors' => $vendors,
            'vendor' => $vendorId,

            'policy' => $policy,
            'policyData' => $this->transformPolicy($policy),
            'policyModes' => $policyModes,
            'deliveryPrices' => $deliveryPrices,
            'paymentSettings' => $paymentSettings,

        ]);
    
    
    }

    public function create(Request $request): RedirectResponse

    {
        ResponseService::noAnyPermissionThenRedirect(['delivery-prices-create']);
        
        $department = $this->resolveDepartment($request->query('department'));

        return redirect()->route('delivery-prices.index', array_filter([
            'department' => $department,
        ]));
    
    }








    public function edit(Request $request, DeliveryPrice $deliveryPrice): RedirectResponse

    {




                $department = $this->resolveDepartment($request->query('department')) ?? $deliveryPrice->department;
                
        return redirect()->route('delivery-prices.index', array_filter([
            'department' => $department,
            'highlight_rule' => $deliveryPrice->getKey(),
        ]));
    }

    public function updatePolicy(Request $request, PricingPolicy $policy): RedirectResponse
    {
        ResponseService::noAnyPermissionThenRedirect(['delivery-prices-update']);

        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'mode' => ['required', Rule::in([PricingPolicy::MODE_DISTANCE_ONLY, PricingPolicy::MODE_WEIGHT_DISTANCE])],
            'currency' => ['required', 'string', 'size:3'],
            'free_shipping_enabled' => ['sometimes', 'boolean'],
            'free_shipping_threshold' => ['nullable', 'numeric', 'min:0'],
            'min_order_total' => ['nullable', 'numeric', 'min:0'],
            'max_order_total' => ['nullable', 'numeric', 'min:0'],
            'allow_pay_now' => ['sometimes', 'boolean'],
            'allow_pay_on_delivery' => ['sometimes', 'boolean'],
            'cod_fee' => ['nullable', 'numeric', 'min:0'],
            'vendor_id' => ['nullable', 'integer', Rule::exists('users', 'id')->where(fn ($query) => $query->where('account_type', User::ACCOUNT_TYPE_SELLER))],
            'context_department' => ['nullable', 'string'],
            'notes' => ['nullable', 'string', 'max:2000'],
        ], [], [
            'name' => 'اسم السياسة',
            'mode' => 'وضع التسعير',
            'currency' => 'العملة',
            'free_shipping_enabled' => 'تفعيل الشحن المجاني',
            'free_shipping_threshold' => 'حد الشحن المجاني',
            'min_order_total' => 'الحد الأدنى لقيمة الطلب',
            'max_order_total' => 'الحد الأقصى لقيمة الطلب',
            'allow_pay_now' => 'السماح بالدفع الآن',
            'allow_pay_on_delivery' => 'السماح بالدفع عند الاستلام',
            'cod_fee' => 'رسوم الدفع عند الاستلام',
            'vendor_id' => 'التاجر',
            'context_department' => 'القسم المختار',
            'notes' => 'الملاحظات',



        ]);

        $freeShippingEnabled = (bool) ($validated['free_shipping_enabled'] ?? false);






        $threshold = array_key_exists('free_shipping_threshold', $validated)

            ? ($validated['free_shipping_threshold'] === null || $validated['free_shipping_threshold'] === ''
                ? null
                : (float) $validated['free_shipping_threshold'])
            : null;

        if ($freeShippingEnabled && $threshold === null) {
            throw ValidationException::withMessages([
                'free_shipping_threshold' => 'يرجى تحديد حد لقيمة الطلب عند تفعيل الشحن المجاني.',
            ]);
        }





        $minOrder = array_key_exists('min_order_total', $validated)
            ? ($validated['min_order_total'] === null || $validated['min_order_total'] === ''
                ? null
                : (float) $validated['min_order_total'])
            : null;
        $maxOrder = array_key_exists('max_order_total', $validated)
            ? ($validated['max_order_total'] === null || $validated['max_order_total'] === ''
                ? null
                : (float) $validated['max_order_total'])
            : null;

        if ($minOrder !== null && $maxOrder !== null && $minOrder > $maxOrder) {
            throw ValidationException::withMessages([
                'min_order_total' => 'يجب ألا يكون الحد الأدنى أكبر من الحد الأقصى لقيمة الطلب.',
                'max_order_total' => 'يجب ألا يكون الحد الأقصى أقل من الحد الأدنى لقيمة الطلب.',
            ]);
        }



        $allowPayNow = $request->boolean('allow_pay_now');
        $allowPayOnDelivery = $request->boolean('allow_pay_on_delivery');
        $codFee = array_key_exists('cod_fee', $validated)
            ? ($validated['cod_fee'] === null || $validated['cod_fee'] === ''
                ? null
                : round((float) $validated['cod_fee'], 2))
            : null;
        $vendorId = array_key_exists('vendor_id', $validated) && $validated['vendor_id'] !== null
            ? (int) $validated['vendor_id']
            : null;
        $contextDepartment = $this->resolveDepartment($validated['context_department'] ?? $policy->department);


        $oldSnapshot = $this->snapshotPolicy($policy);





        $policy->name = $validated['name'];
        $policy->mode = $validated['mode'];
        $policy->currency = strtoupper($validated['currency']);
        $policy->notes = $validated['notes'] ?? null;
        
        $policy->description = $validated['notes'] ?? null;
        $policy->free_shipping_enabled = $freeShippingEnabled;
        $policy->free_shipping_threshold = $freeShippingEnabled ? $threshold : null;
        $policy->min_order_total = $minOrder;
        $policy->max_order_total = $maxOrder;

        $policy->save();

        $this->storePaymentOverride($policy, [
            'allow_pay_now' => $allowPayNow,
            'allow_pay_on_delivery' => $allowPayOnDelivery,
            'cod_fee' => $codFee,
        ], $vendorId, $contextDepartment);


        ActivePricingPolicyCache::forget($policy->department);



        ActivePricingPolicyCache::forget($contextDepartment, $vendorId);
        if ($vendorId !== null) {
            ActivePricingPolicyCache::forget($policy->department, $vendorId);
        }


        $this->pricingAuditLogger->record(
            $policy,
            null,
            null,
            'pricing_policy.updated',
            $oldSnapshot,
            $this->snapshotPolicy($policy),
            'تم تحديث إعدادات سياسة التسعير.'
        );


        $redirectDepartment = $contextDepartment ?? $policy->department;


        return redirect()->route('delivery-prices.index', array_filter([
            'department' => $redirectDepartment,
            'vendor' => $vendorId,
            
            ]))->with('success', 'تم تحديث سياسة التسعير بنجاح.');
    }

 
    public function storeWeightTier(Request $request, PricingPolicy $policy): RedirectResponse
    {
        ResponseService::noAnyPermissionThenRedirect(['delivery-prices-create']);


        $validated = $request->validate([
            'name' => ['required', 'string', 'max:100'],
            'min_weight' => ['required', 'numeric', 'min:0'],
            'max_weight' => ['nullable', 'numeric', 'gt:min_weight'],
            'base_price' => ['nullable', 'numeric', 'min:0'],

            'price_per_km' => ['nullable', 'numeric', 'min:0'],
            'flat_fee' => ['nullable', 'numeric', 'min:0'],
            'sort_order' => ['nullable', 'integer', 'min:0'],
            'notes' => ['nullable', 'string', 'max:2000'],

            'status' => ['sometimes', 'boolean'],
        ], [], [
            'name' => 'اسم شريحة الوزن',
            'min_weight' => 'الوزن الأدنى',
            'max_weight' => 'الوزن الأقصى',
            'base_price' => 'السعر الأساسي',

            'price_per_km' => 'السعر لكل كيلومتر',
            'flat_fee' => 'الرسوم الثابتة',
            'sort_order' => 'ترتيب العرض',
            'notes' => 'الملاحظات',
        ]);
    

        $this->ensureWeightRangeIsValid(
            $policy,
            (float) $validated['min_weight'],
            $this->nullableFloat($validated, 'max_weight')
        );

        $tier = new PricingWeightTier();
        $tier->pricing_policy_id = $policy->getKey();
        $tier->name = $validated['name'];
        $tier->min_weight = (float) $validated['min_weight'];
        $tier->max_weight = $this->nullableFloat($validated, 'max_weight');
        $tier->base_price = array_key_exists('base_price', $validated) ? (float) $validated['base_price'] : 0.0;
        $tier->status = (bool) ($validated['status'] ?? true);
        $tier->price_per_km = array_key_exists('price_per_km', $validated) ? (float) $validated['price_per_km'] : 0.0;
        $tier->flat_fee = array_key_exists('flat_fee', $validated) ? (float) $validated['flat_fee'] : 0.0;
        $tier->sort_order = array_key_exists('sort_order', $validated)
            ? (int) $validated['sort_order']
            : (($policy->weightTiers()->max('sort_order') ?? -1) + 1);
        $tier->notes = $validated['notes'] ?? null;

        $tier->save();

        ActivePricingPolicyCache::forget($policy->department);

        $this->pricingAuditLogger->record(
            $policy,
            $tier,
            null,
            'pricing_weight_tier.created',
            null,
            $this->snapshotTier($tier),
            'تم إنشاء شريحة وزن جديدة.'
        );

        return redirect()->route('delivery-prices.index', array_filter([
            'department' => $policy->department,
        ]))->with('success', 'تمت إضافة شريحة الوزن بنجاح.');
    }






    public function updateWeightTier(Request $request, PricingWeightTier $weightTier): RedirectResponse
    {
        ResponseService::noAnyPermissionThenRedirect(['delivery-prices-update']);


        $policy = $weightTier->policy;

        $validated = $request->validate([
            'name' => ['required', 'string', 'max:100'],
            'min_weight' => ['required', 'numeric', 'min:0'],
            'max_weight' => ['nullable', 'numeric', 'gt:min_weight'],
            'base_price' => ['nullable', 'numeric', 'min:0'],

            'price_per_km' => ['nullable', 'numeric', 'min:0'],
            'flat_fee' => ['nullable', 'numeric', 'min:0'],
            'sort_order' => ['nullable', 'integer', 'min:0'],
            'notes' => ['nullable', 'string', 'max:2000'],

            'status' => ['sometimes', 'boolean'],
        ], [], [
            'name' => 'اسم شريحة الوزن',
            'min_weight' => 'الوزن الأدنى',
            'max_weight' => 'الوزن الأقصى',
            'base_price' => 'السعر الأساسي',

            'price_per_km' => 'السعر لكل كيلومتر',
            'flat_fee' => 'الرسوم الثابتة',
            'sort_order' => 'ترتيب العرض',
            'notes' => 'الملاحظات',

        ]);

        $this->ensureWeightRangeIsValid(
            $policy,
            (float) $validated['min_weight'],
            $this->nullableFloat($validated, 'max_weight'),
            $weightTier->getKey()
        );



            
        $oldSnapshot = $this->snapshotTier($weightTier);

        $weightTier->name = $validated['name'];
        $weightTier->min_weight = (float) $validated['min_weight'];
        $weightTier->max_weight = $this->nullableFloat($validated, 'max_weight');
        $weightTier->base_price = array_key_exists('base_price', $validated) ? (float) $validated['base_price'] : 0.0;
        $weightTier->status = (bool) ($validated['status'] ?? true);
        $weightTier->price_per_km = array_key_exists('price_per_km', $validated) ? (float) $validated['price_per_km'] : 0.0;
        $weightTier->flat_fee = array_key_exists('flat_fee', $validated) ? (float) $validated['flat_fee'] : 0.0;
        $weightTier->sort_order = array_key_exists('sort_order', $validated)
            ? (int) $validated['sort_order']
            : $weightTier->sort_order;
        $weightTier->notes = $validated['notes'] ?? null;

        $weightTier->save();

        ActivePricingPolicyCache::forget($policy->department);

        $this->pricingAuditLogger->record(
            $policy,
            $weightTier,
            null,
            'pricing_weight_tier.updated',
            $oldSnapshot,
            $this->snapshotTier($weightTier),
            'تم تحديث إعدادات شريحة الوزن.'
        );


        return redirect()->route('delivery-prices.index', array_filter([
            'department' => $policy->department,
        ]))->with('success', 'تم تحديث شريحة الوزن بنجاح.');
    }

    public function destroyWeightTier(Request $request, PricingWeightTier $weightTier): RedirectResponse
    {
        ResponseService::noAnyPermissionThenRedirect(['delivery-prices-delete']);

        $policy = $weightTier->policy;
        $snapshot = $this->snapshotTier($weightTier);





        $weightTier->delete();

        ActivePricingPolicyCache::forget($policy?->department);


        $this->pricingAuditLogger->record(
            $policy,
            $weightTier,
            null,
            'pricing_weight_tier.deleted',
            $snapshot,
            null,
            'تم حذف شريحة وزن.'
        );

        return redirect()->route('delivery-prices.index', array_filter([
            'department' => $policy?->department,
        ]))->with('success', 'تم حذف شريحة الوزن بنجاح.');
    }


    



    public function store(Request $request): RedirectResponse
    {
        ResponseService::noAnyPermissionThenRedirect(['delivery-prices-create']);


        
         

        
        $validated = $request->validate([


            'weight_tier_id' => [
                'nullable',
                'required_unless:applies_to,' . PricingDistanceRule::APPLIES_TO_POLICY,
                'exists:pricing_weight_tiers,id',
            ],
            'policy_id' => [
                'nullable',
                'required_if:applies_to,' . PricingDistanceRule::APPLIES_TO_POLICY,
                'exists:pricing_policies,id',
            ],



            'min_distance' => ['required', 'numeric', 'min:0'],
            'max_distance' => ['nullable', 'numeric', 'gt:min_distance'],
            'price' => ['nullable', 'numeric', 'min:0'],
            'currency' => ['required', 'string', 'size:3'],

            'price_type' => ['required', Rule::in([PricingDistanceRule::PRICE_TYPE_FLAT, PricingDistanceRule::PRICE_TYPE_PER_KM])],
            'sort_order' => ['nullable', 'integer', 'min:0'],
            'applies_to' => ['required', Rule::in([
                PricingDistanceRule::APPLIES_TO_WEIGHT_TIER,
                PricingDistanceRule::APPLIES_TO_POLICY,
            ])],


            'is_free_shipping' => ['sometimes', 'boolean'],
            'status' => ['sometimes', 'boolean'],
            'notes' => ['nullable', 'string', 'max:2000'],


        ], [], [
            'weight_tier_id' => 'شريحة الوزن',
            'policy_id' => 'سياسة التسعير',
            'min_distance' => 'المسافة الأدنى',
            'max_distance' => 'المسافة الأقصى',
            'price' => 'السعر',
            'currency' => 'العملة',

            'price_type' => 'نوع التسعير',
            'sort_order' => 'ترتيب العرض',
            'notes' => 'الملاحظات',
        ]);
        $appliesTo = $validated['applies_to'];
        $policy = null;
        $tier = null;
        if ($appliesTo === PricingDistanceRule::APPLIES_TO_POLICY) {
            $policy = PricingPolicy::with('distanceRules')->findOrFail($validated['policy_id']);


            if ($policy->status !== PricingPolicy::STATUS_ACTIVE) {
                throw ValidationException::withMessages([
                    'policy_id' => 'يجب اختيار سياسة تسعير نشطة.',
                ]);
            }
        } else {
            $tier = PricingWeightTier::with('policy', 'distanceRules')->findOrFail($validated['weight_tier_id']);
            $policy = $tier->policy;
        }


        

        $isFreeShipping = (bool) ($validated['is_free_shipping'] ?? false);
        if (!$isFreeShipping && !array_key_exists('price', $validated)) {
            throw ValidationException::withMessages([
                'price' => 'يجب تحديد السعر عندما لا يكون الشحن مجانيًا.',
            ]);


        }
    
        $minDistance = (float) $validated['min_distance'];
        $maxDistance = $this->nullableFloat($validated, 'max_distance');



        $this->ensureDistanceRangeIsValid(
            $tier,
            $minDistance,
            $maxDistance
        );

        if ($appliesTo === PricingDistanceRule::APPLIES_TO_POLICY) {
            $this->ensurePolicyDistanceRangeIsValid(
                $policy,
                $minDistance,
                $maxDistance
            );
        }



        $priceType = $validated['price_type'] ?? PricingDistanceRule::PRICE_TYPE_FLAT;
        $sortOrder = array_key_exists('sort_order', $validated)
            ? (int) $validated['sort_order']
            : (($appliesTo === PricingDistanceRule::APPLIES_TO_WEIGHT_TIER
                ? $tier?->distanceRules()->max('sort_order')
                : $policy?->distanceRules()->max('sort_order')) ?? -1) + 1;

    


        $deliveryPrice = new DeliveryPrice();
        $deliveryPrice->pricing_policy_id = $policy?->getKey();


        $deliveryPrice->pricing_weight_tier_id = $tier?->getKey();
        $deliveryPrice->min_distance = $minDistance;
        $deliveryPrice->max_distance = $maxDistance;
        $deliveryPrice->is_free_shipping = $isFreeShipping;
        $deliveryPrice->price_type = $priceType;


        $deliveryPrice->price = $isFreeShipping ? 0.0 : (float) ($validated['price'] ?? 0);
        $deliveryPrice->currency = strtoupper($validated['currency']);

        $deliveryPrice->applies_to = $appliesTo;
        $deliveryPrice->sort_order = $sortOrder;
        $deliveryPrice->notes = $validated['notes'] ?? null;

        $deliveryPrice->status = (bool) ($validated['status'] ?? true);
        $deliveryPrice->save();

        $deliveryPrice->refresh();

        ActivePricingPolicyCache::forget($policy?->department);

        $this->pricingAuditLogger->record(
            $policy,
            $tier,
            $deliveryPrice,
            'delivery_price.created',
            null,
            $this->snapshotRule($deliveryPrice),
            'تم إنشاء قاعدة تسعير للمسافات.'
        );

        return redirect()->route('delivery-prices.index', array_filter([
            'department' => $policy?->department,
        ]))->with('success', 'تمت إضافة قاعدة المسافة بنجاح.');
    }

    public function update(Request $request, DeliveryPrice $deliveryPrice): RedirectResponse





    {
        ResponseService::noAnyPermissionThenRedirect(['delivery-prices-update']);


        $validated = $request->validate([

            'weight_tier_id' => [
                'nullable',
                'required_unless:applies_to,' . PricingDistanceRule::APPLIES_TO_POLICY,
                'exists:pricing_weight_tiers,id',
            ],
            'policy_id' => [
                'nullable',
                'required_if:applies_to,' . PricingDistanceRule::APPLIES_TO_POLICY,
                'exists:pricing_policies,id',
            ],

            'min_distance' => ['required', 'numeric', 'min:0'],
            'max_distance' => ['nullable', 'numeric', 'gt:min_distance'],
            'price' => ['nullable', 'numeric', 'min:0'],
            'currency' => ['required', 'string', 'size:3'],
            'price_type' => ['required', Rule::in([PricingDistanceRule::PRICE_TYPE_FLAT, PricingDistanceRule::PRICE_TYPE_PER_KM])],
            'sort_order' => ['nullable', 'integer', 'min:0'],
            'applies_to' => ['required', Rule::in([
                PricingDistanceRule::APPLIES_TO_WEIGHT_TIER,
                PricingDistanceRule::APPLIES_TO_POLICY,
            ])],


            'is_free_shipping' => ['sometimes', 'boolean'],
            'status' => ['sometimes', 'boolean'],
            'notes' => ['nullable', 'string', 'max:2000'],

        ], [], [

            
            'weight_tier_id' => 'شريحة الوزن',
            'policy_id' => 'سياسة التسعير',

            'min_distance' => 'المسافة الأدنى',
            'max_distance' => 'المسافة الأقصى',
            'price' => 'السعر',
            'currency' => 'العملة',

            'price_type' => 'نوع التسعير',
            'sort_order' => 'ترتيب العرض',
            'notes' => 'الملاحظات',

        ]);

        $appliesTo = $validated['applies_to'];
        $tier = null;
        $policy = null;

        if ($appliesTo === PricingDistanceRule::APPLIES_TO_POLICY) {
            $policyId = $validated['policy_id'] ?? $deliveryPrice->pricing_policy_id;
            $policy = PricingPolicy::with('distanceRules')->findOrFail($policyId);

            if ($policy->status !== PricingPolicy::STATUS_ACTIVE) {
                throw ValidationException::withMessages([
                    'policy_id' => 'يجب اختيار سياسة تسعير نشطة.',
                ]);
            }
        } else {
            $tierId = $validated['weight_tier_id'] ?? $deliveryPrice->pricing_weight_tier_id;
            $tier = PricingWeightTier::with('policy', 'distanceRules')->findOrFail($tierId);
            $policy = $tier->policy;
        }

        if (!$policy) {
            $policy = $deliveryPrice->policy()->first();
        }

        $isFreeShipping = (bool) ($validated['is_free_shipping'] ?? false);






        
        if (!$isFreeShipping && !array_key_exists('price', $validated)) {
            throw ValidationException::withMessages([
                'price' => 'يجب تحديد السعر عندما لا يكون الشحن مجانيًا.',
            ]);
        }

        $minDistance = (float) $validated['min_distance'];
        $maxDistance = $this->nullableFloat($validated, 'max_distance');



        $this->ensureDistanceRangeIsValid(
            $tier,
            $minDistance,
            $maxDistance,
            $deliveryPrice->getKey()
        );

        if ($appliesTo === PricingDistanceRule::APPLIES_TO_POLICY) {
            $this->ensurePolicyDistanceRangeIsValid(
                $policy,
                $minDistance,
                $maxDistance,
                $deliveryPrice->getKey()
            );
        }




        $oldSnapshot = $this->snapshotRule($deliveryPrice);




        $deliveryPrice->pricing_policy_id = $policy?->getKey();
        $deliveryPrice->pricing_weight_tier_id = $tier?->getKey();

                $deliveryPrice->applies_to = $validated['applies_to'] ?? PricingDistanceRule::APPLIES_TO_WEIGHT_TIER;

        $deliveryPrice->min_distance = $minDistance;
        $deliveryPrice->max_distance = $maxDistance;
        $deliveryPrice->is_free_shipping = $isFreeShipping;
        $deliveryPrice->price_type = $validated['price_type'] ?? PricingDistanceRule::PRICE_TYPE_FLAT;


        $deliveryPrice->price = $isFreeShipping ? 0.0 : (float) ($validated['price'] ?? 0);
        $deliveryPrice->currency = strtoupper($validated['currency']);
        $deliveryPrice->applies_to = $validated['applies_to'] ?? PricingDistanceRule::APPLIES_TO_WEIGHT_TIER;
        $deliveryPrice->sort_order = array_key_exists('sort_order', $validated)
            ? (int) $validated['sort_order']
            : $deliveryPrice->sort_order;
        $deliveryPrice->notes = $validated['notes'] ?? null;

        $deliveryPrice->status = (bool) ($validated['status'] ?? true);
        $deliveryPrice->save();

        $deliveryPrice->refresh();




        ActivePricingPolicyCache::forget($policy?->department);

        $this->pricingAuditLogger->record(
            $policy,
            $tier,
            $deliveryPrice,
            'delivery_price.updated',
            $oldSnapshot,
            $this->snapshotRule($deliveryPrice),
            'تم تعديل قاعدة تسعير للمسافات.'
        );

        return redirect()->route('delivery-prices.index', array_filter([
            'department' => $policy?->department,
        ]))->with('success', 'تم تحديث قاعدة المسافة بنجاح.');
    }

    public function destroy(Request $request, DeliveryPrice $deliveryPrice): RedirectResponse
    {
        ResponseService::noAnyPermissionThenRedirect(['delivery-prices-delete']);

        $tier = $deliveryPrice->weightTier()->with('policy')->first();
        $policy = $tier?->policy;


        $policy = $tier?->policy;
        $deliveryPrice->loadMissing(['weightTier.policy', 'policy']);
        $tier = $deliveryPrice->weightTier;
        $policy = $deliveryPrice->policy ?? $tier?->policy;

        $snapshot = $this->snapshotRule($deliveryPrice);








        $deliveryPrice->delete();


        ActivePricingPolicyCache::forget($policy?->department);


        $this->pricingAuditLogger->record(
            $policy,
            $tier,
            null,
            'delivery_price.deleted',
            $snapshot,
            null,
            'تم حذف قاعدة تسعير للمسافات.'
        );


        $this->cleanupWeightTier($tier);


        return redirect()->route('delivery-prices.index', array_filter([
            'department' => $policy?->department,
        ]))->with('success', 'تم حذف قاعدة المسافة بنجاح.');


    }


    public function toggleStatus(Request $request, DeliveryPrice $deliveryPrice): RedirectResponse

    {
        ResponseService::noAnyPermissionThenRedirect(['delivery-prices-update']);

        $deliveryPrice->loadMissing(['weightTier.policy', 'policy']);
        $tier = $deliveryPrice->weightTier;
        $policy = $deliveryPrice->policy ?? $tier?->policy;
        $tier = $deliveryPrice->weightTier()->with('policy')->first();
        $policy = $tier?->policy;
        $oldSnapshot = $this->snapshotRule($deliveryPrice);




        $deliveryPrice->status = !$deliveryPrice->status;
        $deliveryPrice->save();
        $deliveryPrice->refresh();

        ActivePricingPolicyCache::forget($policy?->department);

        $this->pricingAuditLogger->record(
            $policy,
            $tier,
            $deliveryPrice,
            'delivery_price.status_toggled',
            $oldSnapshot,
            $this->snapshotRule($deliveryPrice),
            'تم تغيير حالة قاعدة التسعير.'
        );





        return redirect()->route('delivery-prices.index', array_filter([
            'department' => $policy?->department,
        ]))->with('success', 'تم تحديث حالة قاعدة التسعير بنجاح.');



    }






    public function calculateDeliveryPrice(Request $request): JsonResponse
    {

        $departments = $this->departmentReportService->availableDepartments();


        $validated = $request->validate([


            'distance' => 'required|numeric|min:0',
            'mode' => ['nullable', Rule::in([PricingPolicy::MODE_DISTANCE_ONLY, PricingPolicy::MODE_WEIGHT_DISTANCE])],
            'weight' => 'nullable|numeric|min:0',
            'order_total' => 'nullable|numeric|min:0',
            
            
            
            'department' => ['nullable', 'string', Rule::in(array_keys($departments))],


        ]);

        try {


            $department = $this->resolveDepartment($validated['department'] ?? null);
            $policy = ActivePricingPolicyCache::get($department);

            if (!$policy) {
                return response()->json([
                    'success' => false,
                    'message' => 'لم يتم العثور على سياسة تسعير نشطة.',
                ], 404);
            }

            $mode = $validated['mode'] ?? $policy->mode ?? PricingPolicy::MODE_DISTANCE_ONLY;
            $distance = (float) $validated['distance'];
            $weight = array_key_exists('weight', $validated) ? (float) $validated['weight'] : null;
            $orderTotal = array_key_exists('order_total', $validated) ? (float) $validated['order_total'] : 0.0;

            $policy->loadMissing(['weightTiers.distanceRules', 'distanceRules']);


            if ($mode === PricingPolicy::MODE_WEIGHT_DISTANCE && $weight === null) {
                return response()->json([
                    'success' => false,
                    'message' => 'يجب تحديد الوزن عند اختيار وضع الوزن + المسافة.',
                ], 422);
            }
            

            if ($policy->min_order_total !== null && $orderTotal < $policy->min_order_total) {
                return response()->json([
                    'success' => false,
                    'message' => 'قيمة الطلب أقل من الحد الأدنى المسموح به لهذه السياسة.',
                ], 422);
            }

            if ($policy->max_order_total !== null && $orderTotal > $policy->max_order_total) {
                return response()->json([
                    'success' => false,
                    'message' => 'قيمة الطلب تتجاوز الحد الأقصى المسموح به لهذه السياسة.',
                ], 422);
            
            }






            if ($mode === PricingPolicy::MODE_DISTANCE_ONLY) {
                $qualifiesForFreeShipping = $policy->free_shipping_enabled
                    && $policy->free_shipping_threshold !== null
                    && $orderTotal >= $policy->free_shipping_threshold;

                $rule = $policy->distanceRules->first(function (PricingDistanceRule $rule) use ($distance) {
                    $min = $rule->min_distance ?? 0;
                    $max = $rule->max_distance;

                    if (!$rule->status) {
                        return false;
                    }

                    if ($distance < $min) {
                        return false;
                    }

                    if ($max !== null && $distance > $max) {
                        return false;
                    }

                    return true;
                });

                if (!$rule) {
                    return response()->json([
                        'success' => false,
                        'message' => 'لم يتم العثور على قاعدة مسافة مطابقة للسياسة.',
                    ], 404);
                }

                $currency = $rule->currency ?? $policy->currency;
                $priceType = $rule->price_type ?? PricingDistanceRule::PRICE_TYPE_FLAT;

                if (!in_array($priceType, [PricingDistanceRule::PRICE_TYPE_FLAT, PricingDistanceRule::PRICE_TYPE_PER_KM], true)) {
                    return response()->json([
                        'success' => false,
                        'message' => 'نوع تسعير المسافة المحدد غير مدعوم.',
                    ], 422);
                }

                $breakdown = [];
                $freeShippingApplied = false;
                $total = 0.0;

                if ($qualifiesForFreeShipping) {
                    $freeShippingApplied = true;
                    $breakdown[] = [
                        'type' => 'free_shipping_threshold',
                        'description' => 'تم تطبيق الشحن المجاني لتجاوز الحد الأدنى لقيمة الطلب.',
                        'amount' => 0.0,
                        'price_type' => $priceType,
                        'components' => [
                            [
                                'label' => 'قيمة الطلب',
                                'value' => $orderTotal,
                            ],
                            [
                                'label' => 'حد الشحن المجاني',
                                'value' => $policy->free_shipping_threshold,
                            ],
                        ],
                    ];
                } elseif ($rule->is_free_shipping) {
                    $freeShippingApplied = true;
                    $breakdown[] = [
                        'type' => 'free_shipping_rule',
                        'description' => 'هذه المسافة مؤهلة للشحن المجاني.',
                        'amount' => 0.0,
                        'price_type' => $priceType,
                        'components' => array_values(array_filter([
                            $rule->min_distance !== null ? [
                                'label' => 'المسافة الدنيا',
                                'value' => $rule->min_distance,
                            ] : null,
                            $rule->max_distance !== null ? [
                                'label' => 'المسافة القصوى',
                                'value' => $rule->max_distance,
                            ] : null,
                        ])),
                    ];
                } else {
                    if ($priceType === PricingDistanceRule::PRICE_TYPE_PER_KM) {
                        $perKmRate = (float) ($rule->price ?? 0.0);
                        $distancePrice = $perKmRate * $distance;

                        $breakdown[] = [
                            'type' => 'distance_rule',
                            'description' => 'سعر الشحن حسب المسافة (لكل كيلومتر).',
                            'amount' => $distancePrice,
                            'price_type' => $priceType,
                            'components' => [
                                [
                                    'label' => 'السعر لكل كيلومتر',
                                    'value' => $perKmRate,
                                ],
                                [
                                    'label' => 'المسافة',
                                    'value' => $distance,
                                ],
                            ],
                        ];

                        $total = $distancePrice;
                    } else {
                        $distancePrice = (float) ($rule->price ?? 0.0);

                        $breakdown[] = [
                            'type' => 'distance_rule',
                            'description' => 'سعر الشحن حسب قاعدة المسافة.',
                            'amount' => $distancePrice,
                            'price_type' => $priceType,
                            'components' => [
                                [
                                    'label' => 'رسوم ثابتة',
                                    'value' => $distancePrice,
                                ],
                            ],
                        ];

                        $total = $distancePrice;
                    }
                }

                return response()->json([
                    'success' => true,
                    'message' => 'تم حساب سعر التوصيل بنجاح.',
                    'price' => (float) $total,
                    'currency' => $currency,
                    'free_shipping_applied' => $freeShippingApplied,
                    'breakdown' => array_values($breakdown),
                ]);
            }


            $tier = $policy->weightTiers->first(function (PricingWeightTier $tier) use ($mode, $weight) {
                if (!$tier->status) {
                    return false;
                }

                if ($mode === PricingPolicy::MODE_WEIGHT_DISTANCE) {
                    
                    
                    $min = $tier->min_weight ?? 0;
                    $max = $tier->max_weight;

                    if ($weight < $min) {
                        return false;
                    }



                    if ($max !== null && $weight > $max) {
                        return false;
                    }
                 }            
       
                return true;
            });


            if (!$tier) {
                return response()->json([
                    'success' => false,
                    'message' => 'لم يتم العثور على شريحة وزن مطابقة.',
                ], 404);



            }

            $rule = $tier->distanceRules->first(function (PricingDistanceRule $rule) use ($distance) {
                $min = $rule->min_distance ?? 0;
                $max = $rule->max_distance;



                if (!$rule->status) {
                    return false;
                }

                if ($distance < $min) {
                    return false;
                }

                if ($max !== null && $distance > $max) {
                    return false;
                }

                return true;
            });

            if (!$rule) {
                return response()->json([
                    'success' => false,
                    'message' => 'لم يتم العثور على قاعدة مسافة مطابقة.',
                ], 404);
            }

            if (
                $policy->free_shipping_enabled
                && $policy->free_shipping_threshold !== null
                && $orderTotal >= $policy->free_shipping_threshold
            ) {
                return response()->json([
                    'success' => true,
                    'price' => 0.0,
                    'currency' => $policy->currency,
                    'free_shipping_applied' => true,
                    'message' => 'تم تطبيق الشحن المجاني لتجاوز الحد الأدنى لقيمة الطلب.',
                ]);
            }

            if ($rule->is_free_shipping) {
                return response()->json([
                    'success' => true,
                    'price' => 0.0,
                    'currency' => $rule->currency ?? $policy->currency,
                    'free_shipping_applied' => true,
                    'message' => 'هذه المسافة مؤهلة للشحن المجاني.',
                ]);
            }


            $price = (float) $rule->price;
            $currency = $rule->currency ?? $policy->currency;

            if ($rule->price_type === PricingDistanceRule::PRICE_TYPE_PER_KM) {
                $perKmRate = (float) ($rule->price ?? 0.0);
                if ($perKmRate <= 0.0) {
                    $perKmRate = (float) ($tier->price_per_km ?? 0.0);
                }
                $price = $perKmRate * $distance;
            }



            $price += (float) ($tier->base_price ?? 0.0);
            $price += (float) ($tier->flat_fee ?? 0.0);




            return response()->json([
                'success' => true,
                'price' => $price,
                'currency' => $currency,
                'free_shipping_applied' => false,
                'message' => 'تم حساب سعر التوصيل بنجاح.',


            ]);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,


                'message' => 'حدث خطأ أثناء حساب سعر التوصيل: ' . $e->getMessage(),
            ], 500);


        }
    }

    protected function resolveDepartment(?string $department): ?string
    {
        if (empty($department)) {
            return null;
        }

        $department = strtolower($department);
        $available = array_keys($this->departmentReportService->availableDepartments());

        return in_array($department, $available, true) ? $department : null;
    }

    protected function resolvePolicyForDepartment(?string $department): PricingPolicy
    {
        return PricingPolicy::resolveDefaultForDepartment($department);
    }





    protected function loadVendorOptions(): array
    {
        return User::query()
            ->sellers()
            ->orderBy('name')
            ->pluck('name', 'id')
            ->toArray();
    }

    protected function resolveVendor($vendor, array $vendorOptions): ?int
    {
        if ($vendor === null || $vendor === '') {
            return null;
        }

        if (!is_numeric($vendor)) {
            return null;
        }

        $vendorId = (int) $vendor;

        return array_key_exists($vendorId, $vendorOptions) ? $vendorId : null;
    }

    protected function resolvePaymentSettings(?PricingPolicy $policy, ?string $department, ?int $vendorId, array $vendors, array $departments): array
    {
        $settings = $this->defaultPaymentSettings();
        $source = 'default';
        $vendorHasOverride = false;
        $departmentHasOverride = false;

        $globalOverride = $this->extractPaymentSettingsFromOverride(
            $this->findGlobalPaymentOverride()
        );

        if ($globalOverride) {
            $settings = $this->applyPaymentOverride($settings, $globalOverride);
        }

        if ($department !== null) {
            $departmentOverride = $this->extractPaymentSettingsFromOverride(
                $this->findDepartmentPaymentOverride($department)
            );

            if ($departmentOverride) {
                $settings = $this->applyPaymentOverride($settings, $departmentOverride);
                $source = 'department';
                $departmentHasOverride = true;
            }
        }

        if ($vendorId !== null) {
            $vendorOverride = $this->extractPaymentSettingsFromOverride(
                $this->findVendorPaymentOverride($vendorId, $department)
            );

            if ($vendorOverride) {
                $settings = $this->applyPaymentOverride($settings, $vendorOverride);
                $source = 'vendor';
                $vendorHasOverride = true;
            } elseif ($departmentHasOverride) {
                $source = 'department';
            }
        }

        if ($source === 'default' && $departmentHasOverride) {
            $source = 'department';
        }

        $settings['source'] = $source;
        $settings['source_label'] = $this->describePaymentSource($source, $vendorId, $vendors, $department, $departments);
        $settings['vendor_has_override'] = $vendorHasOverride;
        $settings['department_has_override'] = $departmentHasOverride;

        return $settings;
    }

    protected function defaultPaymentSettings(): array
    {
        return [
            'allow_pay_now' => true,
            'allow_pay_on_delivery' => false,
            'cod_fee' => null,
            'source' => 'default',
            'source_label' => 'الإعدادات الافتراضية',
            'vendor_has_override' => false,
            'department_has_override' => false,
        ];
    }

    protected function findGlobalPaymentOverride(): ?ShippingOverride
    {
        return ShippingOverride::query()
            ->active()
            ->where('scope_type', 'global')
            ->whereNull('scope_id')
            ->whereNull('department')
            ->orderByDesc('id')
            ->first();
    }

    protected function findDepartmentPaymentOverride(?string $department): ?ShippingOverride
    {
        if ($department === null) {
            return null;
        }

        return ShippingOverride::query()
            ->active()
            ->where('scope_type', 'department')
            ->whereNull('scope_id')
            ->where('department', $department)
            ->orderByDesc('id')
            ->first();
    }

    protected function findVendorPaymentOverride(int $vendorId, ?string $department): ?ShippingOverride
    {
        $query = ShippingOverride::query()
            ->active()
            ->where('scope_type', 'vendor')
            ->where('scope_id', $vendorId);

        if ($department === null) {
            $query->whereNull('department');
        } else {
            $query->whereIn('department', [$department, null])
                ->orderByRaw('CASE WHEN department = ? THEN 0 ELSE 1 END', [$department]);
        }

        return $query->orderByDesc('id')->first();
    }

    protected function extractPaymentSettingsFromOverride(?ShippingOverride $override): ?array
    {
        if (!$override) {
            return null;
        }

        $metadata = $override->metadata ?? [];

        if (!is_array($metadata)) {
            return null;
        }

        $payment = Arr::get($metadata, 'payment');

        if (!is_array($payment)) {
            return null;
        }

        $present = [];
        $values = [];

        if (array_key_exists('allow_pay_now', $payment)) {
            $present['allow_pay_now'] = true;
            $values['allow_pay_now'] = $this->normalizeBoolValue($payment['allow_pay_now']);
        }

        if (array_key_exists('allow_pay_on_delivery', $payment)) {
            $present['allow_pay_on_delivery'] = true;
            $values['allow_pay_on_delivery'] = $this->normalizeBoolValue($payment['allow_pay_on_delivery']);
        }

        if (array_key_exists('cod_fee', $payment)) {
            $present['cod_fee'] = true;
            $values['cod_fee'] = $this->normalizeFloatValue($payment['cod_fee']);
        }

        if ($present === []) {
            return null;
        }

        return [
            'values' => $values,
            'present' => $present,
        ];
    }

    protected function applyPaymentOverride(array $settings, array $override): array
    {
        foreach (['allow_pay_now', 'allow_pay_on_delivery', 'cod_fee'] as $key) {
            if (!empty($override['present'][$key])) {
                $settings[$key] = $override['values'][$key] ?? ($key === 'cod_fee' ? null : false);
            }
        }

        return $settings;
    }

    protected function describePaymentSource(string $source, ?int $vendorId, array $vendors, ?string $department, array $departments): string
    {
        return match ($source) {
            'vendor' => $vendorId !== null
                ? 'إعدادات التاجر: ' . ($vendors[$vendorId] ?? ('#' . $vendorId))
                : 'إعدادات التاجر',
            'department' => $department !== null
                ? 'إعدادات القسم: ' . ($departments[$department] ?? $department)
                : 'إعدادات السياسة',
            default => 'الإعدادات الافتراضية',
        };
    }

    protected function storePaymentOverride(PricingPolicy $policy, array $paymentSettings, ?int $vendorId, ?string $department): void
    {
        $payload = $this->preparePaymentPayload($paymentSettings);

        $scopeType = $vendorId !== null
            ? 'vendor'
            : ($department !== null ? 'department' : 'global');

        $overrideQuery = ShippingOverride::query()
            ->where('scope_type', $scopeType);

        if ($vendorId !== null) {
            $overrideQuery->where('scope_id', $vendorId);
        } else {
            $overrideQuery->whereNull('scope_id');
        }

        if ($department === null) {
            $overrideQuery->whereNull('department');
        } else {
            $overrideQuery->where('department', $department);
        }

        $override = $overrideQuery->first();

        if (!$override) {
            $override = new ShippingOverride();
            $override->scope_type = $scopeType;
            $override->scope_id = $vendorId;
            $override->department = $department;
            $override->delivery_fee = 0;
            $override->delivery_surcharge = 0;
            $override->delivery_discount = 0;
        } else {
            $override->scope_type = $scopeType;
            $override->scope_id = $vendorId;
            $override->department = $department;
        }

        $metadata = $override->metadata ?? [];

        if (!is_array($metadata)) {
            $metadata = [];
        }

        $existingPayment = Arr::get($metadata, 'payment');

        if (!is_array($existingPayment)) {
            $existingPayment = [];
        }

        $metadata['payment'] = array_merge($existingPayment, $payload);

        $override->metadata = $metadata;
        if (auth()->check()) {
            $override->user_id = auth()->id();
        }

        $override->save();
    }

    protected function preparePaymentPayload(array $settings): array
    {
        return [
            'allow_pay_now' => $this->normalizeBoolValue($settings['allow_pay_now'] ?? false),
            'allow_pay_on_delivery' => $this->normalizeBoolValue($settings['allow_pay_on_delivery'] ?? false),
            'cod_fee' => array_key_exists('cod_fee', $settings) && $settings['cod_fee'] !== null
                ? round((float) $settings['cod_fee'], 2)
                : null,
        ];
    }

    protected function normalizeBoolValue($value): bool
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

    protected function normalizeFloatValue($value): ?float
    {
        if ($value === null || $value === '') {
            return null;
        }

        return round((float) $value, 2);
    }



    protected function resolveWeightTier(PricingPolicy $policy, string $size): PricingWeightTier
    {
        return $policy->weightTiers()->firstOrCreate(
            ['name' => $size],
            [
                'min_weight' => 0,
                'max_weight' => null,
                'base_price' => 0,
                'status' => true,
            ]
        );
    }

    protected function cleanupWeightTier(?PricingWeightTier $tier): void
    {
        if (!$tier) {
            return;
        }

        if ($tier->distanceRules()->exists()) {
            return;
        }


        if ($tier->policy && $tier->policy->weightTiers()->count() > 1) {
            return;
        }

        $tier->delete();

    }

    protected function snapshotRule(?DeliveryPrice $deliveryPrice): ?array
    {
        if (!$deliveryPrice) {
            return null;
        }

        return [
            'id' => $deliveryPrice->getKey(),
            'department' => $deliveryPrice->department,
            'size' => $deliveryPrice->size,
            'min_distance' => $deliveryPrice->min_distance,
            'max_distance' => $deliveryPrice->max_distance,
            'price' => $deliveryPrice->price,
            'currency' => $deliveryPrice->currency,
            'is_free_shipping' => $deliveryPrice->is_free_shipping,
            'status' => $deliveryPrice->status,
            'price_type' => $deliveryPrice->price_type,
            'sort_order' => $deliveryPrice->sort_order,
            'applies_to' => $deliveryPrice->applies_to,
            'notes' => $deliveryPrice->notes,
        ];
    }


    protected function snapshotTier(?PricingWeightTier $tier): ?array
    {
        if (!$tier) {
            return null;
        }

        return [
            'id' => $tier->getKey(),
            'name' => $tier->name,
            'min_weight' => $tier->min_weight,
            'max_weight' => $tier->max_weight,
            'base_price' => $tier->base_price,
            'status' => $tier->status,
            'price_per_km' => $tier->price_per_km,
            'flat_fee' => $tier->flat_fee,
            'sort_order' => $tier->sort_order,
            'notes' => $tier->notes,

        ];
    }



    protected function snapshotPolicy(?PricingPolicy $policy): ?array
    {
        if (!$policy) {
            return null;
        }

        return [
            'id' => $policy->getKey(),
            'name' => $policy->name,
            'mode' => $policy->mode,
            'currency' => $policy->currency,
            'department' => $policy->department,
            'free_shipping_enabled' => (bool) $policy->free_shipping_enabled,
            'free_shipping_threshold' => $policy->free_shipping_threshold,
            'min_order_total' => $policy->min_order_total,
            'max_order_total' => $policy->max_order_total,
            'notes' => $policy->notes ?? $policy->description,

        ];
    }



    protected function transformPolicy(?PricingPolicy $policy): ?array
    {
        if (!$policy) {
            return null;
        }

        return [
            'id' => $policy->getKey(),
            'name' => $policy->name,
            'code' => $policy->code,
            'status' => $policy->status,
            'mode' => $policy->mode ?? PricingPolicy::MODE_DISTANCE_ONLY,
            'currency' => $policy->currency,
            'department' => $policy->department,
            'free_shipping' => [
                'enabled' => (bool) $policy->free_shipping_enabled,
                'threshold' => $policy->free_shipping_threshold,
            ],


            'order_limits' => [
                'min' => $policy->min_order_total,
                'max' => $policy->max_order_total,
            ],
            'notes' => $policy->notes ?? $policy->description,
            'policy_rules' => $policy->distanceRules->map(function (PricingDistanceRule $rule) {
                return [
                    'id' => $rule->getKey(),
                    'min_distance' => $rule->min_distance,
                    'max_distance' => $rule->max_distance,
                    'price' => $rule->price,
                    'currency' => $rule->currency,
                    'is_free_shipping' => (bool) $rule->is_free_shipping,
                    'status' => (bool) $rule->status,
                    'price_type' => $rule->price_type,
                    'sort_order' => $rule->sort_order,
                    'applies_to' => $rule->applies_to,
                    'weight_tier_id' => $rule->pricing_weight_tier_id,
                    'notes' => $rule->notes,
                ];
            })->values()->all(),
            
            
            'weight_tiers' => $policy->weightTiers->map(function (PricingWeightTier $tier) {
                return [
                    'id' => $tier->getKey(),
                    'name' => $tier->name,
                    'min_weight' => $tier->min_weight,
                    'max_weight' => $tier->max_weight,
                    'base_price' => $tier->base_price,

                    'price_per_km' => $tier->price_per_km,
                    'flat_fee' => $tier->flat_fee,
                    'sort_order' => $tier->sort_order,
                    'notes' => $tier->notes,

                    'status' => (bool) $tier->status,
                    'distance_rules' => $tier->distanceRules->map(function (PricingDistanceRule $rule) {
                        return [
                            'id' => $rule->getKey(),
                            'min_distance' => $rule->min_distance,
                            'max_distance' => $rule->max_distance,
                            'price' => $rule->price,
                            'currency' => $rule->currency,
                            'is_free_shipping' => (bool) $rule->is_free_shipping,
                            'status' => (bool) $rule->status,

                            'price_type' => $rule->price_type,
                            'sort_order' => $rule->sort_order,
                            'applies_to' => $rule->applies_to,
                            'notes' => $rule->notes,



                        ];
                    })->values()->all(),
                ];
            })->values()->all(),
        ];
    }

    protected function ensureWeightRangeIsValid(PricingPolicy $policy, float $min, ?float $max, ?int $ignoreId = null): void
    {
        $conflict = $policy->weightTiers()
            ->when($ignoreId, fn ($query) => $query->where('id', '!=', $ignoreId))
            ->get()
            ->first(function (PricingWeightTier $tier) use ($min, $max) {
                return $this->rangesOverlap($min, $max, $tier->min_weight, $tier->max_weight);
            });

        if ($conflict) {
            throw ValidationException::withMessages([
                'min_weight' => 'يتداخل مجال الوزن مع الشريحة: ' . $conflict->name,
                'max_weight' => 'يتداخل مجال الوزن مع الشريحة: ' . $conflict->name,
            ]);
        }
    }


    

    protected function ensureDistanceRangeIsValid(?PricingWeightTier $tier, float $min, ?float $max, ?int $ignoreId = null): void
    { 
        if (!$tier) {
            return;
        }



        $conflict = $tier->distanceRules()
            ->when($ignoreId, fn ($query) => $query->where('id', '!=', $ignoreId))
            ->get()
            ->first(function (PricingDistanceRule $rule) use ($min, $max) {
                return $this->rangesOverlap($min, $max, $rule->min_distance, $rule->max_distance);
            });

        if ($conflict) {
            throw ValidationException::withMessages([
                'min_distance' => 'يتداخل مجال المسافة مع القاعدة رقم: ' . $conflict->getKey(),
                'max_distance' => 'يتداخل مجال المسافة مع القاعدة رقم: ' . $conflict->getKey(),
            ]);
        }
    }


    protected function ensurePolicyDistanceRangeIsValid(PricingPolicy $policy, float $min, ?float $max, ?int $ignoreId = null): void
    {
        $conflict = $policy->distanceRules()
            ->when($ignoreId, fn ($query) => $query->where('id', '!=', $ignoreId))
            ->get()
            ->first(function (PricingDistanceRule $rule) use ($min, $max) {
                return $this->rangesOverlap($min, $max, $rule->min_distance, $rule->max_distance);
            });

        if ($conflict) {
            throw ValidationException::withMessages([
                'min_distance' => 'يتداخل مجال المسافة مع القاعدة رقم: ' . $conflict->getKey(),
                'max_distance' => 'يتداخل مجال المسافة مع القاعدة رقم: ' . $conflict->getKey(),
            ]);
        }
    }


    private function rangesOverlap(float $minA, ?float $maxA, ?float $minB, ?float $maxB): bool
    {
        $effectiveMaxA = $maxA ?? INF;
        $effectiveMaxB = $maxB ?? INF;
        $effectiveMinB = $minB ?? 0.0;

        return $minA <= $effectiveMaxB && $effectiveMaxA >= $effectiveMinB;
    }

    private function nullableFloat(array $data, string $key): ?float
    {
        if (!array_key_exists($key, $data) || $data[$key] === null || $data[$key] === '') {
            return null;
        }

        return (float) $data[$key];
    }

}
