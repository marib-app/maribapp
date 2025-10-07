<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Item;
use App\Models\User;
use App\Services\DepartmentReportService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Spatie\Permission\Models\Permission;
use Spatie\Permission\PermissionRegistrar;
use Tests\TestCase;

class UserReportDepartmentTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        app(PermissionRegistrar::class)->forgetCachedPermissions();
    }

    public function test_shein_report_is_assigned_and_listed_in_department_view(): void
    {
        $this->createCategoryWithId(4);
        $this->createCategoryWithId(5);

        $reporter = User::factory()->create();
        Sanctum::actingAs($reporter);

        $seller = User::factory()->create();
        $sheinItem = $this->createItem($seller->id, 4, 'shein-item');

        $response = $this->postJson('/api/add-reports', [
            'item_id' => $sheinItem->id,
            'other_message' => 'Problem with Shein item',
        ]);

        $response->assertOk();
        $response->assertJsonPath('error', false);

        $this->assertDatabaseHas('user_reports', [
            'item_id' => $sheinItem->id,
            'user_id' => $reporter->id,
            'department' => DepartmentReportService::DEPARTMENT_SHEIN,
        ]);

        $admin = $this->createAdminWithPermission();

        $this->actingAs($admin);

        $listingResponse = $this->getJson(route('report-reasons.user-reports.show', [
            'department' => DepartmentReportService::DEPARTMENT_SHEIN,
        ]));

        $listingResponse->assertOk();
        $listingResponse->assertJsonPath('total', 1);
        $listingResponse->assertJsonPath('rows.0.department', DepartmentReportService::DEPARTMENT_SHEIN);
    }

    public function test_computer_report_is_assigned_and_listed_in_department_view(): void
    {
        $this->createCategoryWithId(4);
        $this->createCategoryWithId(5);

        $reporter = User::factory()->create();
        Sanctum::actingAs($reporter);

        $seller = User::factory()->create();
        $computerItem = $this->createItem($seller->id, 5, 'computer-item');

        $response = $this->postJson('/api/add-reports', [
            'item_id' => $computerItem->id,
            'other_message' => 'Problem with Computer item',
        ]);

        $response->assertOk();
        $response->assertJsonPath('error', false);

        $this->assertDatabaseHas('user_reports', [
            'item_id' => $computerItem->id,
            'user_id' => $reporter->id,
            'department' => DepartmentReportService::DEPARTMENT_COMPUTER,
        ]);

        $admin = $this->createAdminWithPermission();

        $this->actingAs($admin);

        $listingResponse = $this->getJson(route('report-reasons.user-reports.show', [
            'department' => DepartmentReportService::DEPARTMENT_COMPUTER,
        ]));

        $listingResponse->assertOk();
        $listingResponse->assertJsonPath('total', 1);
        $listingResponse->assertJsonPath('rows.0.department', DepartmentReportService::DEPARTMENT_COMPUTER);
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
            'description' => 'Test category',
        ]);
    }

    private function createItem(int $sellerId, int $categoryId, string $slugPrefix): Item
    {
        return Item::create([
            'category_id' => $categoryId,
            'name' => Str::title($slugPrefix),
            'description' => 'Test description',
            'price' => 100,
            'image' => 'item.jpg',
            'latitude' => 0,
            'longitude' => 0,
            'address' => 'Test address',
            'contact' => '123456789',
            'show_only_to_premium' => false,
            'status' => 'approved',
            'country' => 'Country',
            'state' => 'State',
            'city' => 'City',
            'user_id' => $sellerId,
            'slug' => $slugPrefix . '-' . Str::random(6),
            'currency' => 'YER',
        ]);
    }

    private function createAdminWithPermission(): User
    {
        $admin = User::factory()->create();

        Permission::firstOrCreate([
            'name' => 'user-reports-list',
            'guard_name' => 'web',
        ]);

        $admin->givePermissionTo('user-reports-list');

        return $admin;
    }
}