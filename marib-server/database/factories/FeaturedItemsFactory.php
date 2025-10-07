<?php

namespace Database\Factories;

use App\Models\FeaturedItems;
use App\Models\Item;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Carbon;

class FeaturedItemsFactory extends Factory
{
    protected $model = FeaturedItems::class;

    public function definition(): array
    {
        $start = Carbon::now()->subDays(1);
        $end = Carbon::now()->addDays(1);

        return [
            'item_id' => Item::factory(),
            'start_date' => $start,
            'end_date' => $end,
            'package_id' => null,
            'user_purchased_package_id' => null,
        ];
    }
}