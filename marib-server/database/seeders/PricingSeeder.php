<?php

namespace Database\Seeders;

use App\Models\Pricing\PricingPolicy;
use App\Models\Pricing\PricingDistanceRule;


use Illuminate\Database\Seeder;

class PricingSeeder extends Seeder
{
    public function run(): void
    {
        $currency = strtoupper(config('app.currency', 'SAR'));

        $policy = PricingPolicy::firstOrCreate(
            ['code' => 'default-shipping-policy'],
            [
                'name' => 'سياسة التسعير الافتراضية',
                'mode' => PricingPolicy::MODE_DISTANCE_ONLY,
                'status' => PricingPolicy::STATUS_ACTIVE,
                'is_default' => true,
                'currency' => $currency,
                'free_shipping_enabled' => true,
                'free_shipping_threshold' => 0,
                'department' => null,
                'min_order_total' => null,
                'max_order_total' => null,
                'notes' => null,

            ]
        );

        if ($policy->weightTiers()->doesntExist()) {
            $tier = $policy->weightTiers()->create([
                'name' => 'افتراضي',
                'min_weight' => 0,
                'max_weight' => null,
                'base_price' => 0,

                'price_per_km' => 0,
                'flat_fee' => 0,
                'sort_order' => 1,
                'notes' => null,

                'status' => true,
            ]);

            $tier->distanceRules()->create([
                'min_distance' => 0,
                'max_distance' => 5,
                'price' => 0,
                'currency' => $currency,
                'is_free_shipping' => true,
                'status' => true,

                'price_type' => PricingDistanceRule::PRICE_TYPE_FLAT,
                'sort_order' => 1,
                'applies_to' => PricingDistanceRule::APPLIES_TO_WEIGHT_TIER,

            ]);
        }
    }
}