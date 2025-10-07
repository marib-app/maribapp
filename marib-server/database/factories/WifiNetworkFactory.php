<?php

namespace Database\Factories;

use App\Models\WifiNetwork;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

/**
 * @extends Factory<\App\Models\WifiNetwork>
 */
class WifiNetworkFactory extends Factory
{
    protected $model = WifiNetwork::class;

    public function definition(): array
    {
        $name = $this->faker->unique()->company();

        return [
            'user_id' => User::factory(),
            'name' => $name,
            'slug' => Str::slug($name . '-' . $this->faker->unique()->uuid()),
            'description' => $this->faker->sentence(),
            'commission_rate' => 0,
            'commission_flat' => 0,
            'is_active' => true,
            'meta' => [],
        ];
    }
}