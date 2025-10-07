<?php

namespace Database\Factories;

use App\Models\Order;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

class OrderFactory extends Factory
{
    protected $model = Order::class;

    public function definition(): array
    {
        $number = 'ORD-' . Str::upper(Str::random(8));
        $total = $this->faker->randomFloat(2, 100, 500);

        return [
            'user_id' => User::factory(),
            'order_number' => $number,
            'total_amount' => $total,
            'tax_amount' => 0,
            'discount_amount' => 0,
            'final_amount' => $total,
            'payment_method' => 'manual',
            'payment_status' => 'pending',
            'order_status' => 'processing',
            'department' => null,
        ];
    }

    public function shein(): self
    {
        return $this->state(fn () => [
            'department' => 'shein',
        ]);
    }
}