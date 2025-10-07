<?php

namespace Database\Factories;

use App\Models\Address;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Address>
 */
class AddressFactory extends Factory
{
    protected $model = Address::class;

    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'label' => $this->faker->word(),
            'phone' => $this->faker->phoneNumber(),
            'latitude' => $this->faker->latitude(),
            'longitude' => $this->faker->longitude(),
            'area_id' => null,
            'distance_km' => $this->faker->randomFloat(3, 0, 50),


            'street' => $this->faker->streetName(),
            'building' => $this->faker->buildingNumber(),
            'note' => $this->faker->sentence(),
            'is_default' => false,
        ];
    }
}