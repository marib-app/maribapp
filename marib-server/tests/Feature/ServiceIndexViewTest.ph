<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Service;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Spatie\Permission\Models\Permission;
use Tests\TestCase;

class ServiceIndexViewTest extends TestCase
{
    use RefreshDatabase;

    public function test_services_rendered_as_cards_for_authorized_user(): void
    {
        $user = User::factory()->create();

        $user->update(['account_type' => User::ACCOUNT_TYPE_CUSTOMER]);

        Permission::create(['name' => 'service-list', 'guard_name' => 'web']);
        $user->givePermissionTo('service-list');

        $category = Category::create([
            'name' => 'Government Services',
            'image' => 'categories/example.jpg',
            'status' => true,
        ]);

        $service = Service::create([
            'category_id' => $category->id,
            'title' => 'Business License Renewal',
            'slug' => 'business-license-renewal',
            'description' => 'Submit and track renewal requests.',
            'image' => 'services/example.jpg',
            'status' => true,
            'is_main' => true,
            'service_type' => 'standard',
            'views' => 42,
            'is_paid' => false,
            'has_custom_fields' => false,
            'direct_to_user' => false,
        ]);

        $category->managers()->attach($user->id);


        $response = $this->actingAs($user)->get(route('services.index'));

        $response->assertOk();
        $response->assertSee('service-card', false);
        $response->assertSee('data-service-id="' . $service->id . '"', false);
        $response->assertSeeText($service->title);
    }
}