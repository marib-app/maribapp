<?php

namespace Database\Factories;

use App\Models\SliderDefault;
use Illuminate\Database\Eloquent\Factories\Factory;

class SliderDefaultFactory extends Factory
{
    protected $model = SliderDefault::class;

    public function definition(): array
    {
        return [
            'interface_type' => 'homepage',
            'image_path'     => 'slider-defaults/' . $this->faker->unique()->uuid . '.jpg',
            'status'         => SliderDefault::STATUS_ACTIVE,
        ];
    }
}