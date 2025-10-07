<?php

namespace Database\Factories;

use App\Models\Slider;
use Illuminate\Database\Eloquent\Factories\Factory;

class SliderFactory extends Factory
{
    protected $model = Slider::class;

    public function definition(): array
    {
        static $sequence = 1;

        return [
            'image'                       => 'uploads/sliders/' . $this->faker->uuid() . '.jpg',
            'sequence'                    => $sequence++,
            'third_party_link'            => $this->faker->optional()->url(),
            'interface_type'              => 'all',
            'priority'                    => 0,
            'weight'                      => 1,
            'share_of_voice'              => 0,
            'status'                      => Slider::STATUS_ACTIVE,
            'starts_at'                   => now()->subDay(),
            'ends_at'                     => now()->addDay(),
            'dayparting_json'             => null,
            'per_user_per_day_limit'      => null,
            'per_user_per_session_limit'  => null,
            'target_type'                 => null,
            'target_id'                   => null,
            'action_type'                 => null,
            'action_payload'              => null,

        ];
    }
}