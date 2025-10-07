<?php

namespace Tests\Feature;

use App\Models\Package;
use App\Models\PaymentTransaction;
use App\Models\User;
use App\Models\UserPurchasedPackage;
use Carbon\Carbon;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class GetLimitsTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        Carbon::setTestNow(Carbon::create(2024, 1, 1));
    }

    protected function tearDown(): void
    {
        Carbon::setTestNow();

        parent::tearDown();
    }

    public function test_it_returns_limits_for_manual_unlimited_package(): void
    {
        $user = User::factory()->create();

        $package = $this->createPackage([
            'type' => 'item_listing',
            'duration' => 'unlimited',
            'item_limit' => 'unlimited',
        ]);

        UserPurchasedPackage::create([
            'user_id' => $user->id,
            'package_id' => $package->id,
            'start_date' => Carbon::today()->toDateString(),
            'end_date' => null,
            'total_limit' => null,
            'used_limit' => 0,
            'payment_transactions_id' => null,
        ]);

        $response = $this->requestLimits($user, 'item_listing');

        $response->assertOk();
        $response->assertJson([
            'error' => false,
            'data' => [
                'allowed' => true,
                'total' => null,
                'remaining' => null,
                'expires_at' => null,
            ],
        ]);
    }

    public function test_it_returns_limits_for_paid_package(): void
    {
        $user = User::factory()->create();

        $package = $this->createPackage([
            'type' => 'advertisement',
            'duration' => 15,
            'item_limit' => 10,
        ]);

        $transaction = PaymentTransaction::create([
            'user_id' => $user->id,
            'amount' => 49.99,
            'payment_gateway' => 'stripe',
            'order_id' => 'order-123',
            'payment_status' => 'succeed',
        ]);

        $expiryDate = Carbon::today()->addDays(15)->toDateString();

        UserPurchasedPackage::create([
            'user_id' => $user->id,
            'package_id' => $package->id,
            'start_date' => Carbon::today()->toDateString(),
            'end_date' => $expiryDate,
            'total_limit' => 10,
            'used_limit' => 3,
            'payment_transactions_id' => $transaction->id,
        ]);

        $response = $this->requestLimits($user, 'advertisement');

        $response->assertOk();
        $response->assertJson([
            'error' => false,
            'data' => [
                'allowed' => true,
                'total' => 10,
                'remaining' => 7,
                'expires_at' => $expiryDate,
            ],
        ]);
    }

    public function test_it_disallows_requests_when_no_package_exists(): void
    {
        $user = User::factory()->create();

        $response = $this->requestLimits($user, 'item_listing');

        $response->assertOk();
        $response->assertJson([
            'error' => false,
            'data' => [
                'allowed' => false,
                'total' => 0,
                'remaining' => 0,
                'expires_at' => null,
            ],
        ]);
    }

    public function test_it_disallows_requests_when_package_has_expired(): void
    {
        $user = User::factory()->create();

        $package = $this->createPackage([
            'type' => 'item_listing',
            'duration' => 7,
            'item_limit' => 5,
        ]);

        UserPurchasedPackage::create([
            'user_id' => $user->id,
            'package_id' => $package->id,
            'start_date' => Carbon::today()->subDays(10)->toDateString(),
            'end_date' => Carbon::today()->subDay()->toDateString(),
            'total_limit' => 5,
            'used_limit' => 1,
            'payment_transactions_id' => null,
        ]);

        $response = $this->requestLimits($user, 'item_listing');

        $response->assertOk();
        $response->assertJson([
            'error' => false,
            'data' => [
                'allowed' => false,
                'total' => 0,
                'remaining' => 0,
                'expires_at' => null,
            ],
        ]);
    }

    public function test_it_disallows_requests_when_quota_is_exhausted(): void
    {
        $user = User::factory()->create();

        $package = $this->createPackage([
            'type' => 'item_listing',
            'duration' => 30,
            'item_limit' => 5,
        ]);

        $expiryDate = Carbon::today()->addDays(30)->toDateString();

        UserPurchasedPackage::create([
            'user_id' => $user->id,
            'package_id' => $package->id,
            'start_date' => Carbon::today()->toDateString(),
            'end_date' => $expiryDate,
            'total_limit' => 5,
            'used_limit' => 5,
            'payment_transactions_id' => null,
        ]);

        $response = $this->requestLimits($user, 'item_listing');

        $response->assertOk();
        $response->assertJson([
            'error' => false,
            'data' => [
                'allowed' => false,
                'total' => 5,
                'remaining' => 0,
                'expires_at' => $expiryDate,
            ],
        ]);
    }

    private function requestLimits(User $user, string $packageType)
    {
        Sanctum::actingAs($user);

        return $this->withHeaders([
            'Authorization' => 'Bearer test-token',
        ])->getJson('/api/get-limits?package_type=' . $packageType);
    }

    private function createPackage(array $overrides = []): Package
    {
        return Package::create(array_merge([
            'name' => 'Sample Package',
            'price' => 100,
            'discount_in_percentage' => 0,
            'final_price' => 100,
            'duration' => 30,
            'item_limit' => 10,
            'type' => 'item_listing',
            'icon' => null,
            'description' => 'Sample package description',
            'status' => 1,
            'ios_product_id' => null,
        ], $overrides));
    }
}