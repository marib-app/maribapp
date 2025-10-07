<?php

namespace Database\Seeders;

use App\Models\FeatureSection;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Schema;

class FixFeatureSectionNullRootSeeder extends Seeder
{
    public function run(): void
    {
        if (! Schema::hasTable('feature_sections')) {
            return;
        }

        $sections = FeatureSection::query()
            ->select(['id', 'section_type', 'value'])
            ->whereIn('section_type', ['public', 'shein'])
            ->get();

        if ($sections->isEmpty()) {
            return;
        }

        $now = now();
        $updates = [];

        foreach ($sections as $section) {
            $rawValue = $section->value;

            if ($rawValue === null) {
                continue;
            }

            if (is_string($rawValue) && strtolower(trim($rawValue)) === 'null') {
                $updates[] = [
                    'id' => $section->id,
                    'value' => null,
                    'updated_at' => $now,
                ];
            }
        }

        if ($updates !== []) {
            FeatureSection::upsert($updates, ['id'], ['value', 'updated_at']);
            Cache::flush();
        }
    }
}