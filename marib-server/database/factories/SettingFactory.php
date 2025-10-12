<?php

namespace Database\Factories;

use App\Models\Setting;
use Illuminate\Database\Eloquent\Factories\Factory;

class SettingFactory extends Factory
{
    protected $model = Setting::class;

    public function definition(): array
    {
        return [
            'name' => $this->faker->unique()->slug(),
            'value' => $this->faker->sentence(),
            'type' => 'text',
        ];
    }

    public function booleanValue(bool $value = null): self
    {
        $bool = $value ?? $this->faker->boolean();

        return $this->state(fn () => [
            'value' => $bool ? '1' : '0',
            'type' => 'boolean',
        ]);
    }
}