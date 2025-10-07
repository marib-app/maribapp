<?php

namespace Database\Factories;

use App\Models\Slider;
use App\Models\SliderMetric;
use Illuminate\Database\Eloquent\Factories\Factory;

class SliderMetricFactory extends Factory
{
    protected $model = SliderMetric::class;

    public function definition(): array
    {
        return [
            'slider_id'  => Slider::factory(),
            'user_id'    => null,
            'session_id' => $this->faker->optional()->uuid(),
            'event_type' => $this->faker->randomElement(['impression', 'click']),
            'occurred_at'=> $this->faker->dateTimeBetween('-7 days', 'now'),
        ];
    }
}