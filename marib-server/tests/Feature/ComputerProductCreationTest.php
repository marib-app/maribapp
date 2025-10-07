<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Item;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Spatie\Permission\Models\Permission;
use Tests\TestCase;

class ComputerProductCreationTest extends TestCase
{
    use RefreshDatabase;

    public function test_it_stores_interface_type_for_computer_products(): void
    {
        Storage::fake('public');

        Permission::create([
            'name' => 'computer-ads-create',
            'guard_name' => 'web',
        ]);

        $user = User::factory()->create();
        $user->givePermissionTo('computer-ads-create');

        Category::query()->insert([
            'id' => 5,
            'name' => 'Computers',
            'slug' => 'computers',
            'image' => 'categories/default.png',
            'status' => 1,
            'description' => null,
            'parent_category_id' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $response = $this->actingAs($user)
            ->post(route('item.computer.products.store'), [
                'name' => 'Laptop',
                'description' => 'Powerful machine',
                'price' => 1500,
                'currency' => 'YER',
                'category_id' => 5,
                'image' => UploadedFile::fake()->image('laptop.jpg'),
                'interface_type' => 'computer_section',
            ]);

        $response->assertRedirect(route('item.computer.products'));

        $item = Item::query()->first();

        $this->assertNotNull($item);
        $this->assertSame('computer_section', $item->interface_type);
    }
}