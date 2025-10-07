<?php

namespace Database\Factories;

use App\Models\Item;
use App\Models\Order;
use App\Models\OrderItem;
use Illuminate\Database\Eloquent\Factories\Factory;

class OrderItemFactory extends Factory
{
    protected $model = OrderItem::class;

    public function definition(): array
    {
        $quantity = $this->faker->numberBetween(1, 5);
        $price = $this->faker->randomFloat(2, 10, 100);

        return [
            'order_id' => Order::factory(),
            'item_id' => Item::factory(),
            'item_name' => $this->faker->words(3, true),
            'price' => $price,
            'quantity' => $quantity,
            'subtotal' => $price * $quantity,
            'options' => null,
        ];
    }
}