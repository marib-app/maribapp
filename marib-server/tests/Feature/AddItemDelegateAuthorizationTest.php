<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Package;
use App\Models\User;
use App\Models\UserPurchasedPackage;
use App\Services\DelegateAuthorizationService;
use App\Services\DepartmentReportService;
use Carbon\Carbon;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Spatie\Permission\Models\Role;
use Spatie\Permission\PermissionRegistrar;
use Tests\TestCase;

class AddItemDelegateAuthorizationTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        Carbon::setTestNow(Carbon::create(2024, 1, 1));

        app(PermissionRegistrar::class)->forgetCachedPermissions();

        foreach (['User', 'Admin', 'Super Admin'] as $role) {
            Role::firstOrCreate(['name' => $role, 'guard_name' => 'web']);
        }
    }

    protected function tearDown(): void
    {
        Carbon::setTestNow();

        parent::tearDown();
    }

    public function test_delegate_can_create_item_in_assigned_section(): void
    {
        Storage::fake(config('filesystems.default'));

        $category = $this->createCategoryWithId(4);

        $user = User::factory()->create();
        $user->assignRole('User');

        $this->assignListingPackageTo($user);

        app(DelegateAuthorizationService::class)->storeDelegatesForSection(
            DepartmentReportService::DEPARTMENT_SHEIN,
            [$user->id]
        );

        Sanctum::actingAs($user);

        $response = $this->postJson('/api/add-item', $this->validPayload($category->id));

        $response->assertOk();
        $response->assertJsonPath('error', false);

        $this->assertDatabaseHas('items', [
            'category_id' => $category->id,
            'user_id' => $user->id,
        ]);
    }

    public function test_non_delegate_is_rejected_from_restricted_section(): void
    {
        Storage::fake(config('filesystems.default'));

        $category = $this->createCategoryWithId(4);

        $delegate = User::factory()->create();
        $delegate->assignRole('User');

        app(DelegateAuthorizationService::class)->storeDelegatesForSection(
            DepartmentReportService::DEPARTMENT_SHEIN,
            [$delegate->id]
        );

        $user = User::factory()->create();
        $user->assignRole('User');
        $this->assignListingPackageTo($user);

        Sanctum::actingAs($user);

        $response = $this->postJson('/api/add-item', $this->validPayload($category->id));

        $response->assertStatus(200);
        $response->assertJsonPath('error', true);
        $response->assertJsonPath('message', 'غير مصرح لك بالنشر في هذا القسم.');

        $this->assertDatabaseCount('items', 0);
    }

    public function test_super_admin_can_post_in_any_section(): void
    {
        Storage::fake(config('filesystems.default'));

        $category = $this->createCategoryWithId(5);

        $admin = User::factory()->create();
        $admin->assignRole('Super Admin');
        $this->assignListingPackageTo($admin);

        Sanctum::actingAs($admin);

        $response = $this->postJson('/api/add-item', $this->validPayload($category->id));

        $response->assertOk();
        $response->assertJsonPath('error', false);

        $this->assertDatabaseHas('items', [
            'category_id' => $category->id,
            'user_id' => $admin->id,
        ]);
    }

    private function validPayload(int $categoryId): array
    {
        return [
            'name' => 'Delegate Item',
            'slug' => 'delegate-item-' . uniqid(),
            'category_id' => $categoryId,
            'price' => 150,
            'description' => 'Description',
            'latitude' => 12.3456,
            'longitude' => 65.4321,
            'address' => '123 Main Street',
            'contact' => '1234567890',
            'show_only_to_premium' => false,
            'video_link' => null,
            'image' => UploadedFile::fake()->image('item.jpg'),
            'country' => 'Country',
            'state' => 'State',
            'city' => 'City',
            'currency' => 'USD',
        ];
    }

    private function assignListingPackageTo(User $user): void
    {
        $package = Package::create([
            'name' => 'Listing Package',
            'price' => 100,
            'discount_in_percentage' => 0,
            'final_price' => 100,
            'duration' => 30,
            'item_limit' => 10,
            'type' => 'item_listing',
            'icon' => null,
            'description' => 'Package description',
            'status' => 1,
            'ios_product_id' => null,
        ]);

        UserPurchasedPackage::create([
            'user_id' => $user->id,
            'package_id' => $package->id,
            'start_date' => Carbon::today()->toDateString(),
            'end_date' => Carbon::today()->addDays(30)->toDateString(),
            'total_limit' => 10,
            'used_limit' => 0,
            'payment_transactions_id' => null,
        ]);
    }

    private function createCategoryWithId(int $id): Category
    {
        return Category::create([
            'id' => $id,
            'name' => 'Category ' . $id,
            'parent_category_id' => null,
            'image' => null,
            'slug' => 'category-' . $id,
            'status' => 1,
            'description' => 'Category description',
        ]);
    }
}