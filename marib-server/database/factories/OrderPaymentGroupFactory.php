<?php

namespace Database\Factories;

use App\Models\OrderPaymentGroup;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

class OrderPaymentGroupFactory extends Factory
{
    protected $model = OrderPaymentGroup::class;

    public function definition(): array
    {
        return [
            'name' => 'مجموعة ' . Str::upper(Str::random(5)),
            'note' => $this->faker->sentence(),
            'created_by' => User::factory(),
        ];
    }
}
