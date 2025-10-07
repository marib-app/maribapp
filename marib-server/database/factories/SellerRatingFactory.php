<?php

namespace Database\Factories;

use App\Models\Item;
use App\Models\SellerRating;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

class SellerRatingFactory extends Factory
{
    protected $model = SellerRating::class;

    public function definition(): array
    {
        return [
            'review' => $this->faker->sentence(),
            'ratings' => $this->faker->numberBetween(1, 5),
            'seller_id' => User::factory(),
            'buyer_id' => User::factory(),
            'item_id' => Item::factory(),
            'report_status' => null,
            'report_reason' => null,
            'report_rejected_reason' => null,
        ];
    }
}