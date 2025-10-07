<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Service;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ServiceOwnerManagementTest extends TestCase
{
    use RefreshDatabase;

    private Category $category;

    protected function setUp(): void
    {
        parent::setUp();

        $this->category = Category::create([
            'name' => 'Owner Managed Category',
            'image' => 'categories/example.jpg',
            'status' => true,
            'slug' => 'owner-managed-category',
        ]);
    }

    public function test_owner_can_list_and_update_their_service(): void
    {
        $owner = User::factory()->create(['account_type' => User::ACCOUNT_TYPE_CUSTOMER]);
        $service = $this->createOwnedService($owner);

        Sanctum::actingAs($owner);

        $listResponse = $this->getJson('/api/my-services');
        $listResponse->assertOk();
        $listResponse->assertJsonPath('error', false);
        $listResponse->assertJsonCount(1, 'data');
        $listResponse->assertJsonPath('data.0.id', $service->id);
        $listResponse->assertJsonPath('data.0.owner.id', $owner->id);

        $newExpiry = now()->addDays(10)->format('Y-m-d');

        $updateResponse = $this->patchJson('/api/my-services/' . $service->id, [
            'status' => false,
            'expiry_date' => $newExpiry,
        ]);

        $updateResponse->assertOk();
        $updateResponse->assertJsonPath('error', false);
        $updateResponse->assertJsonPath('data.status', false);
        $updateResponse->assertJsonPath('data.expiry_date', $newExpiry);
        $updateResponse->assertJsonPath('data.owner.id', $owner->id);

        $this->assertDatabaseHas('services', [
            'id' => $service->id,
            'owner_id' => $owner->id,
            'status' => false,
            'expiry_date' => $newExpiry,
        ]);
    }

    public function test_only_owner_can_manage_service(): void
    {
        $owner = User::factory()->create(['account_type' => User::ACCOUNT_TYPE_CUSTOMER]);
        $other = User::factory()->create(['account_type' => User::ACCOUNT_TYPE_CUSTOMER]);
        $service = $this->createOwnedService($owner);

        Sanctum::actingAs($other);

        $this->patchJson('/api/my-services/' . $service->id, ['status' => true])
            ->assertStatus(403)
            ->assertJson(['error' => true]);

        $this->deleteJson('/api/my-services/' . $service->id)
            ->assertStatus(403)
            ->assertJson(['error' => true]);

        Sanctum::actingAs($owner);

        $deleteResponse = $this->deleteJson('/api/my-services/' . $service->id);
        $deleteResponse->assertOk();
        $deleteResponse->assertJsonPath('error', false);

        $this->assertDatabaseMissing('services', ['id' => $service->id]);
    }

    private function createOwnedService(User $owner): Service
    {
        $title = 'Owner Service ' . Str::random(4);

        return Service::create([
            'category_id' => $this->category->id,
            'owner_id' => $owner->id,
            'title' => $title,
            'slug' => Str::slug($title) . '-' . uniqid(),
            'description' => 'Service managed by owner',
            'status' => true,
            'is_main' => false,
            'service_type' => 'standard',
            'views' => 0,
            'is_paid' => false,
            'has_custom_fields' => false,
            'direct_to_user' => false,
            'image' => 'services/example.jpg',
        ]);
    }
}