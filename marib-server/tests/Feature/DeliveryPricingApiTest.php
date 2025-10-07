<?php

namespace Tests\Feature;

use App\Models\Pricing\PricingPolicy;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Tests\TestCase;

class DeliveryPricingApiTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        Cache::flush();
    }

    public function test_can_fetch_active_delivery_policy(): void
    {
        $policy = PricingPolicy::create([
            'name' => 'سياسة افتراضية',
            'code' => 'default-policy',
            'status' => PricingPolicy::STATUS_ACTIVE,
            'is_default' => true,
            'currency' => 'SAR',
            'free_shipping_enabled' => true,
            'free_shipping_threshold' => 150,
            'department' => null,
        ]);

        $tier = $policy->weightTiers()->create([
            'name' => 'صغير',
            'min_weight' => 0,
            'max_weight' => 5,
            'base_price' => 10,
            'status' => true,
        ]);

        $tier->distanceRules()->create([
            'min_distance' => 0,
            'max_distance' => 15,
            'price' => 20,
            'currency' => 'SAR',
            'is_free_shipping' => false,
            'status' => true,
        ]);

        $response = $this->getJson('/api/delivery-prices');

        $response->assertOk()
            ->assertJson([
                'status' => true,
                'data' => [
                    'policy' => [
                        'id' => $policy->id,
                        'free_shipping' => [
                            'enabled' => true,
                            'threshold' => 150.0,
                        ],
                    ],
                ],
            ]);

        $this->assertNotEmpty($response->json('data.weight_tiers'));
        $this->assertSame($tier->id, $response->json('data.weight_tiers.0.id'));
        $this->assertSame(20.0, $response->json('data.weight_tiers.0.distance_rules.0.price'));
    }

    public function test_calculate_delivery_price_in_weight_and_distance_mode(): void
    {
        $policy = $this->createPolicy();

        $response = $this->postJson('/api/delivery-prices/calculate', [
            'mode' => 'weight_distance',
            'distance' => 8,
            'weight' => 3,
        ]);

        $response->assertOk()
            ->assertJson([
                'status' => true,
                'data' => [
                    'total' => 25.0,
                    'free_shipping_applied' => false,
                ],
            ]);

        $this->assertSame('distance_rule', $response->json('data.breakdown.0.type'));
    }

    public function test_returns_error_when_weight_tier_not_found(): void
    {
        $this->createPolicy();

        $response = $this->postJson('/api/delivery-prices/calculate', [
            'mode' => 'weight_distance',
            'distance' => 5,
            'weight' => 12,
        ]);

        $response->assertStatus(404)
            ->assertJson([
                'status' => false,
                'message' => 'لم يتم العثور على شريحة وزن مطابقة.',
            ]);
    }

    public function test_returns_error_when_distance_rule_not_found(): void
    {
        $policy = $this->createPolicy();

        $response = $this->postJson('/api/delivery-prices/calculate', [
            'mode' => 'weight_distance',
            'distance' => 50,
            'weight' => 2,
        ]);

        $response->assertStatus(404)
            ->assertJson([
                'status' => false,
                'message' => 'لم يتم العثور على قاعدة مسافة مطابقة.',
            ]);
    }

    public function test_applies_free_shipping_threshold(): void
    {
        $policy = $this->createPolicy([
            'free_shipping_enabled' => true,
            'free_shipping_threshold' => 100,
        ]);

        $response = $this->postJson('/api/delivery-prices/calculate', [
            'mode' => 'weight_distance',
            'distance' => 6,
            'weight' => 2,
            'order_total' => 150,
        ]);

        $response->assertOk()
            ->assertJson([
                'status' => true,
                'data' => [
                    'total' => 0.0,
                    'free_shipping_applied' => true,
                ],
            ]);

        $this->assertSame('free_shipping_threshold', $response->json('data.breakdown.0.type'));
    }

    private function createPolicy(array $overrides = []): PricingPolicy
    {
        $policy = PricingPolicy::create(array_merge([
            'name' => 'سياسة الاختبار',
            'code' => 'policy-'.uniqid(),
            'status' => PricingPolicy::STATUS_ACTIVE,
            'is_default' => false,
            'currency' => 'SAR',
            'free_shipping_enabled' => false,
            'free_shipping_threshold' => null,
            'department' => null,
        ], $overrides));

        $tier = $policy->weightTiers()->create([
            'name' => 'افتراضي',
            'min_weight' => 0,
            'max_weight' => 10,
            'base_price' => 0,
            'status' => true,
        ]);

        $tier->distanceRules()->create([
            'min_distance' => 0,
            'max_distance' => 20,
            'price' => 25,
            'currency' => 'SAR',
            'is_free_shipping' => false,
            'status' => true,
        ]);

        return $policy;
    }
}