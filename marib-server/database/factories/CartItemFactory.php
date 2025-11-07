<?php

namespace Database\Factories;

use App\Models\CartItem;
use App\Models\Item;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

class CartItemFactory extends Factory
{
    protected $model = CartItem::class;

    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'item_id' => Item::factory(),
            'store_id' => null,
            'variant_id' => null,
            'department' => 'general',
            'variant_key' => '',
            'quantity' => $this->faker->numberBetween(1, 3),
            'unit_price' => $this->faker->randomFloat(2, 10, 100),
            'unit_price_locked' => null,
            'currency' => 'YER',
            'attributes' => [],
            'stock_snapshot' => [],
        ];
    }
}
