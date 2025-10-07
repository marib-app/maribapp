<?php

namespace Tests\Feature;
use App\Models\Item;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Database\Eloquent\Factories\Sequence;
use Spatie\Permission\Models\Permission;
use Tests\TestCase;

class ItemControllerShowTest extends TestCase
{
    use RefreshDatabase;

    public function test_show_allows_access_with_legacy_permission_when_section_missing(): void
    {
        Permission::create([
            'name' => 'item-list',
            'guard_name' => 'web',
        ]);

        $user = User::factory()->create([
            'type' => 'email',
            'fcm_id' => 'test-fcm-token',
            'firebase_id' => 'test-firebase-id',
        ]);

        $user->givePermissionTo('item-list');

        $response = $this->actingAs($user)->getJson(route('item.show', ['item' => 1]));

        $response
            ->assertOk()
            ->assertJson([
                'total' => 0,
            ])
            ->assertJsonStructure([
                'total',
                'rows',
            ]);
    }
    public function test_list_data_shows_all_items_when_status_filter_is_all(): void
    {
        Permission::create([
            'name' => 'item-list',
            'guard_name' => 'web',
        ]);

        $user = User::factory()->create([
            'type' => 'email',
            'fcm_id' => 'test-fcm-token',
            'firebase_id' => 'test-firebase-id',
        ]);

        $user->givePermissionTo('item-list');

        Item::factory()->count(3)->state(new Sequence(
            ['status' => 'approved'],
            ['status' => 'review'],
            ['status' => 'rejected'],
        ))->create();

        $response = $this->actingAs($user)->getJson(route('item.list', [
            'status' => 'all',
        ]));

        $response
            ->assertOk()
            ->assertJson([
                'total' => 3,
            ]);

        $this->assertCount(3, $response->json('rows'));
    }
}