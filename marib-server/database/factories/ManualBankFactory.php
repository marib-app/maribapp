<?php

namespace Database\Factories;

use App\Models\ManualBank;
use Illuminate\Database\Eloquent\Factories\Factory;

class ManualBankFactory extends Factory
{
    protected $model = ManualBank::class;

    public function definition(): array
    {
        return [
            'name' => $this->faker->company(),
            'logo_path' => 'banks/' . $this->faker->uuid() . '.png',
            'beneficiary_name' => $this->faker->name(),
            'note' => $this->faker->sentence(),
            'display_order' => $this->faker->numberBetween(1, 100),
            'status' => true,
        ];
    }
}