<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Pricing\PricingDistanceRule;
use App\Models\Pricing\PricingPolicy;
use App\Models\Pricing\PricingWeightTier;
use App\Services\DepartmentReportService;
use App\Services\Pricing\ActivePricingPolicyCache;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\Rule;

class DeliveryPriceCalculatorController extends Controller
{
    public function __construct(private readonly DepartmentReportService $departmentReportService)
    {
    }

    public function __invoke(Request $request): JsonResponse
    {
        $departments = $this->departmentReportService->availableDepartments();

        $validator = Validator::make(
            $request->all(),
            [
                'distance' => ['nullable', 'numeric', 'min:0', 'required_without:distance_km'],
                'distance_km' => ['nullable', 'numeric', 'min:0', 'required_without:distance'],
                'mode' => ['nullable', Rule::in([PricingPolicy::MODE_DISTANCE_ONLY, PricingPolicy::MODE_WEIGHT_DISTANCE])],
                'weight' => ['nullable', 'numeric', 'min:0'],
                'weight_kg' => ['nullable', 'numeric', 'min:0'],
                'order_total' => ['nullable', 'numeric', 'min:0'],
                'department' => ['nullable', 'string', Rule::in(array_keys($departments))],
            ],
            [
                'distance.required_without' => 'يرجى تحديد المسافة المطلوبة.',
                'distance.numeric' => 'قيمة المسافة يجب أن تكون رقمية.',
                'distance.min' => 'قيمة المسافة يجب ألا تكون سالبة.',
                'distance_km.required_without' => 'يرجى تحديد المسافة المطلوبة.',
                'distance_km.numeric' => 'قيمة المسافة يجب أن تكون رقمية.',
                'distance_km.min' => 'قيمة المسافة يجب ألا تكون سالبة.',
                'mode.in' => 'وضع التسعير المحدد غير صالح.',
                'weight.numeric' => 'قيمة الوزن يجب أن تكون رقمية.',
                'weight.min' => 'قيمة الوزن يجب ألا تكون سالبة.',
                'weight_kg.numeric' => 'قيمة الوزن يجب أن تكون رقمية.',
                'weight_kg.min' => 'قيمة الوزن يجب ألا تكون سالبة.',
                'order_total.numeric' => 'قيمة الطلب يجب أن تكون رقمية.',
                'order_total.min' => 'قيمة الطلب يجب ألا تكون سالبة.',
                'department.in' => 'القسم المحدد غير مدعوم.',
            ]
        );

        if ($validator->fails()) {
            return response()->json([
                'status' => false,
                'message' => $validator->errors()->first(),
            ], 422);
        }

        $validated = $validator->validated();

        try {
            $department = $validated['department'] ?? null;
            $policy = ActivePricingPolicyCache::get($department);

            if (! $policy) {
                return response()->json([
                    'status' => false,
                    'message' => 'لم يتم العثور على سياسة تسعير نشطة.',
                ], 404);
            }

            $mode = $validated['mode'] ?? $policy->mode ?? PricingPolicy::MODE_DISTANCE_ONLY;

            $distanceValue = $validated['distance_km'] ?? $validated['distance'] ?? null;
            $distance = $distanceValue !== null ? (float) $distanceValue : null;

            if ($distance === null) {
                return response()->json([
                    'status' => false,
                    'message' => 'يرجى تحديد المسافة المطلوبة.',
                ], 422);
            }

            $weightValue = $validated['weight_kg'] ?? $validated['weight'] ?? null;
            $weight = $weightValue !== null ? (float) $weightValue : null;

            $orderTotal = array_key_exists('order_total', $validated) ? (float) $validated['order_total'] : 0.0;

            if ($mode === PricingPolicy::MODE_WEIGHT_DISTANCE && $weight === null) {
                return response()->json([
                    'status' => false,
                    'message' => 'يجب تحديد الوزن عند اختيار وضع الوزن + المسافة.',
                ], 422);
            }

            $policy->loadMissing(['weightTiers.distanceRules']);

            if ($policy->min_order_total !== null && $orderTotal < $policy->min_order_total) {
                return response()->json([
                    'status' => false,
                    'message' => 'قيمة الطلب أقل من الحد الأدنى المسموح به لهذه السياسة.',
                ], 422);
            }

            if ($policy->max_order_total !== null && $orderTotal > $policy->max_order_total) {
                return response()->json([
                    'status' => false,
                    'message' => 'قيمة الطلب تتجاوز الحد الأقصى المسموح به لهذه السياسة.',
                ], 422);
            }

            $breakdown = [];
            $freeShippingApplied = false;
            $currency = $policy->currency;
            $total = 0.0;
            $rule = null;
            $tier = null;

            $qualifiesForFreeShipping = $policy->free_shipping_enabled
                && $policy->free_shipping_threshold !== null
                && $orderTotal >= $policy->free_shipping_threshold;

            if ($mode === PricingPolicy::MODE_DISTANCE_ONLY) {
                $policy->loadMissing(['distanceRules']);

                $rule = $policy->distanceRules->first(function (PricingDistanceRule $rule) use ($distance) {
                    $min = $rule->min_distance ?? 0;
                    $max = $rule->max_distance;

                    if (! $rule->status) {
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

                if (! $rule) {
                    return response()->json([
                        'status' => false,
                        'message' => 'لم يتم العثور على قاعدة مسافة مطابقة للسياسة.',
                    ], 404);
                }

                $currency = $rule->currency ?? $policy->currency;
                $priceType = $rule->price_type ?? PricingDistanceRule::PRICE_TYPE_FLAT;

                if (! in_array($priceType, [PricingDistanceRule::PRICE_TYPE_FLAT, PricingDistanceRule::PRICE_TYPE_PER_KM], true)) {
                    return response()->json([
                        'status' => false,
                        'message' => 'نوع تسعير المسافة المحدد غير مدعوم.',
                    ], 422);
                }

                if ($qualifiesForFreeShipping) {
                    $freeShippingApplied = true;
                    $total = 0.0;
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
                    $total = 0.0;
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
                    }

                    $total = $distancePrice;
                }
            } else {
                $tier = $policy->weightTiers->first(function (PricingWeightTier $tier) use ($weight) {
                    if (! $tier->status) {
                        return false;
                    }

                    $min = $tier->min_weight ?? 0;
                    $max = $tier->max_weight;

                    if ($weight < $min) {
                        return false;
                    }

                    if ($max !== null && $weight > $max) {
                        return false;
                    }

                    return true;
                });

                if (! $tier) {
                    return response()->json([
                        'status' => false,
                        'message' => 'لم يتم العثور على شريحة وزن مطابقة.',
                    ], 404);
                }

                $rule = $tier->distanceRules->first(function (PricingDistanceRule $rule) use ($distance) {
                    if (! $rule->status) {
                        return false;
                    }

                    $min = $rule->min_distance ?? 0;
                    $max = $rule->max_distance;

                    if ($distance < $min) {
                        return false;
                    }

                    if ($max !== null && $distance > $max) {
                        return false;
                    }

                    return true;
                });

                if (! $rule) {
                    return response()->json([
                        'status' => false,
                        'message' => 'لم يتم العثور على قاعدة مسافة مطابقة.',
                    ], 404);
                }

                $currency = $rule->currency ?? $policy->currency;
                $basePrice = (float) ($tier->base_price ?? 0.0);
                $flatFee = (float) ($tier->flat_fee ?? 0.0);

                if ($qualifiesForFreeShipping) {
                    $freeShippingApplied = true;
                    $total = 0.0;
                    $breakdown[] = [
                        'type' => 'free_shipping_threshold',
                        'description' => 'تم تطبيق الشحن المجاني لتجاوز الحد الأدنى لقيمة الطلب.',
                        'amount' => 0.0,
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
                    $total = 0.0;
                    $breakdown[] = [
                        'type' => 'free_shipping_rule',
                        'description' => 'هذه المسافة مؤهلة للشحن المجاني.',
                        'amount' => 0.0,
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
                    if ($basePrice > 0) {
                        $breakdown[] = [
                            'type' => 'weight_tier_base',
                            'description' => 'رسوم أساسية لشريحة الوزن المختارة.',
                            'amount' => $basePrice,
                            'components' => [
                                [
                                    'label' => 'رسوم ثابتة',
                                    'value' => $basePrice,
                                ],
                            ],
                        ];
                    }

                    if ($flatFee > 0) {
                        $breakdown[] = [
                            'type' => 'weight_tier_flat_fee',
                            'description' => 'رسوم ثابتة لشريحة الوزن المختارة.',
                            'amount' => $flatFee,
                            'components' => [
                                [
                                    'label' => 'رسوم ثابتة',
                                    'value' => $flatFee,
                                ],
                            ],
                        ];
                    }

                    $priceType = $rule->price_type ?? PricingDistanceRule::PRICE_TYPE_FLAT;

                    if (! in_array($priceType, [PricingDistanceRule::PRICE_TYPE_FLAT, PricingDistanceRule::PRICE_TYPE_PER_KM], true)) {
                        return response()->json([
                            'status' => false,
                            'message' => 'نوع تسعير المسافة المحدد غير مدعوم.',
                        ], 422);
                    }

                    if ($priceType === PricingDistanceRule::PRICE_TYPE_PER_KM) {
                        $perKmRate = (float) ($rule->price ?? 0.0);

                        if ($perKmRate <= 0.0) {
                            $perKmRate = (float) ($tier->price_per_km ?? 0.0);
                        }

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
                    }

                    $total = $basePrice + $flatFee + $distancePrice;
                }
            }

            return response()->json([
                'status' => true,
                'message' => 'تم حساب سعر التوصيل بنجاح.',
                'data' => array_merge([
                    'total' => (float) $total,
                    'currency' => $currency,
                    'free_shipping_applied' => $freeShippingApplied,
                    'policy_id' => $policy->id,
                    'distance_rule_id' => $rule?->id,
                    'mode' => $mode,
                    'distance_km' => $distance,
                    'distance' => $distance,
                    'weight_kg' => $weight,
                    'weight' => $weight,
                    'order_total' => $orderTotal,
                    'department' => $department,
                    'breakdown' => array_values($breakdown),
                ], isset($tier) && $tier ? ['weight_tier_id' => $tier->id] : []),
            ]);
        } catch (\Throwable $th) {
            Log::error('فشل حساب تكلفة التوصيل عبر الواجهة البرمجية.', [
                'payload' => $validated,
                'error' => $th->getMessage(),
            ]);

            return response()->json([
                'status' => false,
                'message' => 'حدث خطأ غير متوقع أثناء حساب سعر التوصيل.',
            ], 500);
        }
    }
}