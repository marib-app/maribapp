<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\FeaturedItems;
use App\Models\Item;
use App\Models\Package;
use App\Models\User;
use App\Models\UserPurchasedPackage;
use Carbon\Carbon;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class PackageUsageTest extends TestCase
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

    public function test_add_item_consumes_listing_quota_and_fails_when_exhausted(): void
    {
        Storage::fake(config('filesystems.default'));

        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $category = $this->createCategory();

        $package = $this->createPackage([
            'type' => 'item_listing',
            'duration' => 30,
            'item_limit' => 1,
        ]);

        $userPackage = UserPurchasedPackage::create([
            'user_id' => $user->id,
            'package_id' => $package->id,
            'start_date' => Carbon::today()->toDateString(),
            'end_date' => Carbon::today()->addDays(30)->toDateString(),
            'total_limit' => 1,
            'used_limit' => 0,
            'payment_transactions_id' => null,
        ]);

        $payload = [
            'name' => 'Test Item One',
            'slug' => 'test-item-one',
            'category_id' => $category->id,
            'price' => 99,
            'description' => 'Description',
            'latitude' => 12.3456,
            'longitude' => 65.4321,
            'address' => '123 Main Street',
            'contact' => '1234567890',
            'show_only_to_premium' => false,
            'video_link' => null,
            'image' => UploadedFile::fake()->image('item-one.jpg'),
            'country' => 'Country',
            'state' => 'State',
            'city' => 'City',
            'currency' => 'USD',
        ];

        $response = $this->withHeaders(['Accept' => 'application/json'])
            ->post('/api/add-item', $payload);

        $response->assertOk();
        $response->assertJsonPath('error', false);

        $userPackage->refresh();
        $this->assertSame(1, $userPackage->used_limit);

        $payload['slug'] = 'test-item-two';
        $payload['name'] = 'Test Item Two';
        $payload['image'] = UploadedFile::fake()->image('item-two.jpg');

        $secondResponse = $this->withHeaders(['Accept' => 'application/json'])
            ->post('/api/add-item', $payload);

        $secondResponse->assertStatus(200);
        $secondResponse->assertJsonPath('error', true);
        $secondResponse->assertJsonPath('message', 'No Active Package found for Item Creation');

        $userPackage->refresh();
        $this->assertSame(1, $userPackage->used_limit);
    }

    public function test_make_featured_item_consumes_advertisement_quota_and_fails_when_exhausted(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $category = $this->createCategory();

        $item = Item::create([
            'category_id' => $category->id,
            'name' => 'FEATURED ITEM',
            'price' => 150,
            'description' => 'Featured description',
            'latitude' => 11.1111,
            'longitude' => 22.2222,
            'address' => '456 Market Street',
            'contact' => '5555555555',
            'show_only_to_premium' => false,
            'video_link' => null,
            'status' => 'approved',
            'user_id' => $user->id,
            'image' => 'items/featured.jpg',
            'country' => 'Country',
            'state' => 'State',
            'city' => 'City',
            'area_id' => null,
            'all_category_ids' => null,
            'slug' => 'featured-item-' . Str::random(5),
            'sold_to' => null,
            'expiry_date' => Carbon::today()->addDays(10)->toDateString(),
            'currency' => 'USD',
        ]);

        $package = $this->createPackage([
            'type' => 'advertisement',
            'duration' => 10,
            'item_limit' => 1,
        ]);

        $userPackage = UserPurchasedPackage::create([
            'user_id' => $user->id,
            'package_id' => $package->id,
            'start_date' => Carbon::today()->toDateString(),
            'end_date' => Carbon::today()->addDays(10)->toDateString(),
            'total_limit' => 1,
            'used_limit' => 0,
            'payment_transactions_id' => null,
        ]);

        $response = $this->postJson('/api/make-item-featured', [
            'item_id' => $item->id,
        ]);

        $response->assertOk();
        $response->assertJsonPath('error', false);

        $userPackage->refresh();
        $this->assertSame(1, $userPackage->used_limit);

        $featured = FeaturedItems::first();
        $this->assertNotNull($featured);
        $this->assertSame($item->id, $featured->item_id);
        $this->assertSame($package->id, $featured->package_id);
        $this->assertSame($userPackage->id, $featured->user_purchased_package_id);

        $secondResponse = $this->postJson('/api/make-item-featured', [
            'item_id' => $item->id,
        ]);

        $secondResponse->assertStatus(200);
        $secondResponse->assertJsonPath('error', true);
        $secondResponse->assertJsonPath('message', 'No Active Package found for Featuring Item');

        $userPackage->refresh();
        $this->assertSame(1, $userPackage->used_limit);
    }

    public function test_renew_item_consumes_listing_quota_and_fails_when_exhausted(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $category = $this->createCategory();

        $item = Item::create([
            'category_id' => $category->id,
            'name' => 'RENEWABLE ITEM',
            'price' => 75,
            'description' => 'Renew description',
            'latitude' => 33.3333,
            'longitude' => 44.4444,
            'address' => '789 Central Avenue',
            'contact' => '9999999999',
            'show_only_to_premium' => false,
            'video_link' => null,
            'status' => 'approved',
            'user_id' => $user->id,
            'image' => 'items/renewable.jpg',
            'country' => 'Country',
            'state' => 'State',
            'city' => 'City',
            'area_id' => null,
            'all_category_ids' => null,
            'slug' => 'renewable-item-' . Str::random(5),
            'sold_to' => null,
            'expiry_date' => Carbon::today()->subDay()->toDateString(),
            'currency' => 'USD',
        ]);

        $package = $this->createPackage([
            'type' => 'item_listing',
            'duration' => 5,
            'item_limit' => 1,
        ]);

        $userPackage = UserPurchasedPackage::create([
            'user_id' => $user->id,
            'package_id' => $package->id,
            'start_date' => Carbon::today()->toDateString(),
            'end_date' => Carbon::today()->addDays(5)->toDateString(),
            'total_limit' => 1,
            'used_limit' => 0,
            'payment_transactions_id' => null,
        ]);

        $response = $this->postJson('/api/renew-item', [
            'item_id' => $item->id,
        ]);

        $response->assertOk();
        $response->assertJsonPath('error', false);

        $userPackage->refresh();
        $this->assertSame(1, $userPackage->used_limit);

        $item->refresh();
        $this->assertSame(
            Carbon::now()->addDays(5)->toDateString(),
            Carbon::parse($item->expiry_date)->toDateString()
        );

        $item->update([
            'expiry_date' => Carbon::today()->subDay()->toDateString(),
        ]);

        $secondResponse = $this->postJson('/api/renew-item', [
            'item_id' => $item->id,
        ]);

        $secondResponse->assertStatus(200);
        $secondResponse->assertJsonPath('error', true);
        $secondResponse->assertJsonPath('message', 'No Active Package found for Item Renewal');

        $userPackage->refresh();
        $this->assertSame(1, $userPackage->used_limit);
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

    private function createCategory(): Category
    {
        return Category::create([
            'name' => 'Category ' . Str::random(5),
            'parent_category_id' => null,
            'image' => null,
            'slug' => 'category-' . Str::random(5),
            'status' => 1,
            'description' => 'Category description',
        ]);
    }
}