<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Service;
use App\Models\ServiceRequest;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Spatie\Permission\Models\Permission;
use Spatie\Permission\Models\Role;
use Spatie\Permission\PermissionRegistrar;
use Tests\TestCase;

class ServiceManagerAuthorizationTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        app(PermissionRegistrar::class)->forgetCachedPermissions();

        foreach (['Super Admin', 'Admin', 'User'] as $role) {
            Role::firstOrCreate(['name' => $role, 'guard_name' => 'web']);
        }

        foreach ([
            'service-list',
            'service-edit',
            'service-delete',
            'service-managers-manage',
            'service-requests-list',
        ] as $permission) {
            Permission::firstOrCreate(['name' => $permission, 'guard_name' => 'web']);
        }
    }

    public function test_non_manager_cannot_view_other_service(): void
    {
        $category = $this->createCategory();
        $service = $this->createService($category);

        $user = User::factory()->create(['account_type' => User::ACCOUNT_TYPE_CUSTOMER]);
        $user->givePermissionTo('service-list');

        $response = $this->actingAs($user)->get(route('services.show', $service));

        $response->assertForbidden();
    }

    public function test_manager_can_view_assigned_service(): void
    {
        $category = $this->createCategory();
        $service = $this->createService($category);

        $user = User::factory()->create(['account_type' => User::ACCOUNT_TYPE_CUSTOMER]);
        $user->givePermissionTo('service-list');

        $category->managers()->attach($user->id);

        $response = $this->actingAs($user)->get(route('services.show', $service));

        $response->assertOk();
        $response->assertSeeText($service->title);
    }

    public function test_service_listing_returns_only_managed_services(): void
    {
        $category = $this->createCategory();
        $otherCategory = $this->createCategory(name: 'Other Category', slug: 'other-category');

        $managedService = $this->createService($category, 'Managed Service');
        $otherService = $this->createService($otherCategory, 'Hidden Service');

        $user = User::factory()->create(['account_type' => User::ACCOUNT_TYPE_CUSTOMER]);
        $user->givePermissionTo('service-list');

        $category->managers()->attach($user->id);

        $response = $this->actingAs($user)->get(route('services.list', ['limit' => 'all']));

        $response->assertOk();
        $response->assertJsonPath('total', 1);
        $response->assertJsonCount(1, 'rows');
        $response->assertJsonPath('rows.0.id', $managedService->id);
        $response->assertJsonMissing(['id' => $otherService->id]);
    }

    public function test_service_requests_filtered_for_manager(): void
    {
        $category = $this->createCategory();
        $otherCategory = $this->createCategory(name: 'Hidden Category', slug: 'hidden-category');


        $managedService = $this->createService($category, 'Managed Service');
        $otherService = $this->createService($otherCategory, 'Hidden Service');

        $manager = User::factory()->create(['account_type' => User::ACCOUNT_TYPE_CUSTOMER]);
        $manager->givePermissionTo(['service-list', 'service-requests-list']);
        $category->managers()->attach($manager->id);

        $customer = User::factory()->create(['account_type' => User::ACCOUNT_TYPE_CUSTOMER]);

        $managedRequest = $this->createServiceRequest($managedService, $customer);
        $this->createServiceRequest($otherService, $customer);

        $response = $this->actingAs($manager)->get(route('service.requests.datatable', ['limit' => 'all']));

        $response->assertOk();
        $response->assertJsonPath('total', 1);
        $response->assertJsonCount(1, 'rows');
        $response->assertJsonPath('rows.0.id', $managedRequest->id);
    }

    public function test_api_blocks_access_to_unmanaged_service(): void
    {
        $category = $this->createCategory();
        $service = $this->createService($category);

        $user = User::factory()->create(['account_type' => User::ACCOUNT_TYPE_CUSTOMER]);
        Sanctum::actingAs($user);

        $response = $this->getJson('/api/services/' . $service->id);

        $response->assertStatus(403);
        $response->assertJson(['error' => true]);
    }

    public function test_admin_can_assign_and_remove_managers(): void
    {
        $category = $this->createCategory();
        $service = $this->createService($category);

        $admin = User::factory()->create();
        $admin->assignRole('Super Admin');
        $admin->givePermissionTo(['service-list', 'service-managers-manage']);

        $firstManager = User::factory()->create(['account_type' => User::ACCOUNT_TYPE_CUSTOMER]);
        $secondManager = User::factory()->create(['account_type' => User::ACCOUNT_TYPE_CUSTOMER]);

        $this->actingAs($admin)->post(route('category.managers.update', $category), [
            'managers' => [$firstManager->id, $secondManager->id],
        ]);

        $this->assertDatabaseHas('category_managers', [
            'category_id' => $category->id,
            'user_id' => $firstManager->id,
        ]);
        $this->assertDatabaseHas('category_managers', [
            'category_id' => $category->id,
            'user_id' => $secondManager->id,
        ]);

        $this->actingAs($admin)->post(route('category.managers.update', $category), [
            'managers' => [],
        ]);

        $this->assertDatabaseMissing('category_managers', [
            'category_id' => $category->id,
            'user_id' => $firstManager->id,
        ]);
        $this->assertDatabaseMissing('category_managers', [
            'category_id' => $category->id,
            'user_id' => $secondManager->id,
        ]);
    }

    private function createCategory(string $name = 'Services Category', string $slug = 'services-category'): Category
    {
        return Category::create([
            'name' => $name,
            'image' => 'categories/example.jpg',
            'status' => true,
            'slug' => $slug,
        ]);
    }

    private function createService(Category $category, string $title = 'Test Service'): Service
    {
        return Service::create([
            'category_id' => $category->id,
            'title' => $title,
            'slug' => Str::slug($title) . '-' . uniqid(),
            'description' => 'Service description',
            'status' => true,
            'is_main' => true,
            'service_type' => 'standard',
            'views' => 0,
            'is_paid' => false,
            'has_custom_fields' => false,
            'direct_to_user' => false,
        ]);
    }

    private function createServiceRequest(Service $service, User $customer): ServiceRequest
    {
        $request = new ServiceRequest();
        $request->service_id = $service->id;
        $request->user_id = $customer->id;
        $request->status = 'review';
        $request->payload = ['field' => 'value'];
        $request->save();

        return $request;
    }
}
