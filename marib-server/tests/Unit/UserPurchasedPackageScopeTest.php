<?php

namespace Tests\Unit;

use App\Models\Package;
use App\Models\User;
use App\Models\UserPurchasedPackage;
use Carbon\Carbon;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class UserPurchasedPackageScopeTest extends TestCase
{
    use RefreshDatabase;

    public function test_scope_only_active_includes_packages_through_end_date(): void
    {
        $user = User::factory()->create();
        $this->actingAs($user);

        $package = Package::create([
            'name' => 'Sample Package',
            'price' => 100,
            'discount_in_percentage' => 0,
            'final_price' => 100,
            'duration' => 30,
            'item_limit' => 10,
            'type' => 'item_listing',
            'icon' => 'icon.png',
            'description' => 'Sample package description',
            'status' => 1,
            'ios_product_id' => 'ios-product-id',
        ]);

        $activePackage = UserPurchasedPackage::create([
            'user_id' => $user->id,
            'package_id' => $package->id,
            'start_date' => Carbon::today()->toDateString(),
            'end_date' => Carbon::today()->toDateString(),
            'total_limit' => 10,
            'used_limit' => 0,
            'payment_transactions_id' => null,
        ]);

        $expiredPackage = UserPurchasedPackage::create([
            'user_id' => $user->id,
            'package_id' => $package->id,
            'start_date' => Carbon::today()->subDays(10)->toDateString(),
            'end_date' => Carbon::yesterday()->toDateString(),
            'total_limit' => 10,
            'used_limit' => 0,
            'payment_transactions_id' => null,
        ]);

        $results = UserPurchasedPackage::onlyActive()->get();

        $this->assertCount(1, $results);
        $this->assertTrue($results->contains($activePackage));
        $this->assertFalse($results->contains($expiredPackage));
    }
}