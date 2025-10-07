<?php

namespace Database\Factories;

use App\Models\FeatureSection;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

class FeatureSectionFactory extends Factory
{
    protected $model = FeatureSection::class;

    public function definition(): array
    {
        $title = $this->faker->unique()->sentence(3);
        $slug = Str::slug($title, '_');
        $defaultSectionType = config('feature-section.allowed_section_types.0', 'public');

        return [
            'title' => ucfirst($title),
            'slug' => $slug,
            'sequence' => $this->faker->numberBetween(1, 100),
            'filter' => 'latest',
            'value' => null,
            'style' => 'style_1',
            'section_type' => $defaultSectionType,
            'min_price' => null,
            'max_price' => null,
            'description' => null,
            'is_active' => true,
        ];
    }
}