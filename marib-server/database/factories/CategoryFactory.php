<?php

namespace Database\Factories;

use App\Models\Category;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

class CategoryFactory extends Factory
{
    protected $model = Category::class;

    public function definition(): array
    {
        $name = $this->faker->unique()->words(2, true);

        return [
            'sequence' => $this->faker->numberBetween(1, 100),
            'name' => ucfirst($name),
            'slug' => Str::slug($name) . '-' . Str::random(4),
            'image' => $this->faker->imageUrl(),
            'description' => $this->faker->sentence(),
            'status' => true,
        ];
    }
}