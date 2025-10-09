<?php

namespace Database\Factories;

use App\Models\Language;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

class LanguageFactory extends Factory
{
    protected $model = Language::class;

    public function definition(): array
    {
        $name = $this->faker->unique()->languageCode();
        $englishName = $this->faker->unique()->words(2, true);

        return [
            'name' => Str::title($name),
            'name_in_english' => Str::title($englishName),
            'code' => strtolower($name) . '_' . Str::lower(Str::random(2)),
            'rtl' => false,
            'image' => 'languages/' . Str::uuid() . '.png',
        ];
    }
}