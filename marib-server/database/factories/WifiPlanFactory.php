<?php

namespace Database\Factories;

use App\Models\WifiPlan;
use App\Models\WifiNetwork;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<\App\Models\WifiPlan>
 */
class WifiPlanFactory extends Factory
{
    protected $model = WifiPlan::class;

    public function definition(): array
    {
        return [
            'wifi_network_id' => WifiNetwork::factory(),
            'name' => $this->faker->words(3, true),
            'description' => $this->faker->sentence(),
            'duration_minutes' => $this->faker->numberBetween(30, 720),
            'data_allowance_mb' => null,
            'validity_days' => $this->faker->numberBetween(1, 30),
            'speed_mbps' => $this->faker->randomFloat(2, 1, 100),
            'price' => $this->faker->randomFloat(2, 5, 100),
            'currency' => 'SAR',
            'commission_rate_override' => null,
            'is_active' => true,
            'meta' => [],
        ];
    }
}