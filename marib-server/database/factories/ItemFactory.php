<?php

namespace Database\Factories;

use App\Models\Category;
use App\Models\Item;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

class ItemFactory extends Factory
{
    protected $model = Item::class;

    public function definition(): array
    {
        $name = $this->faker->unique()->words(3, true);

        return [
            'category_id' => Category::factory(),
            'name' => ucfirst($name),
            'slug' => Str::slug($name) . '-' . Str::random(4),
            'price' => $this->faker->randomFloat(2, 10, 500),
            'description' => $this->faker->paragraph(),
            'latitude' => $this->faker->latitude(),
            'longitude' => $this->faker->longitude(),
            'address' => $this->faker->address(),
            'contact' => $this->faker->phoneNumber(),
            'show_only_to_premium' => false,
            'status' => 'approved',
            'video_link' => null,
            'product_link' => $this->faker->url(),
            'clicks' => 0,


            'city' => $this->faker->city(),
            'state' => $this->faker->word(),
            'country' => $this->faker->country(),
            'user_id' => User::factory(),
            'image' => $this->faker->imageUrl(),
            'all_category_ids' => null,
            'currency' => 'YER',
            'interface_type' => 'app',
        ];
    }
}
