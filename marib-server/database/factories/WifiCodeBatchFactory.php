<?php

namespace Database\Factories;

use App\Models\WifiCodeBatch;
use App\Models\WifiNetwork;
use App\Models\WifiPlan;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

/**
 * @extends Factory<\App\Models\WifiCodeBatch>
 */
class WifiCodeBatchFactory extends Factory
{
    protected $model = WifiCodeBatch::class;

    public function definition(): array
    {
        return [
            'wifi_network_id' => WifiNetwork::factory(),
            'wifi_plan_id' => WifiPlan::factory(),
            'uploaded_by' => User::factory(),
            'original_filename' => Str::slug($this->faker->words(2, true)) . '.csv',
            'total_rows' => 1,
            'accepted_rows' => 1,
            'rejected_rows' => 0,
            'status' => WifiCodeBatch::STATUS_PROCESSED,
            'processed_at' => now(),
            'meta' => [],
        ];
    }
}