<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    private function resolveDefaultSectionType(): string
    {
        $configured = config('feature-section.allowed_section_types', []);

        if (is_array($configured) && isset($configured[0])) {
            $candidate = (string) $configured[0];

            if (trim($candidate) !== '') {
                return $candidate;
            }
        }

        return 'public';
    }

    public function up(): void
    {
        $default = $this->resolveDefaultSectionType();

        Schema::table('feature_sections', function (Blueprint $table) use ($default) {
            $table->string('section_type')->default($default)->change();
        });

        DB::table('feature_sections')
            ->where('section_type', 'homepage')
            ->update(['section_type' => $default]);

        if (Schema::hasTable('sliders')) {
            DB::table('sliders')
                ->where('interface_type', 'homepage')
                ->update(['interface_type' => $default]);
        }
    }

    public function down(): void
    {
        Schema::table('feature_sections', function (Blueprint $table) {
            $table->string('section_type')->default('homepage')->change();
        });

        if (Schema::hasTable('sliders')) {
            DB::table('sliders')
                ->whereNull('interface_type')
                ->update(['interface_type' => 'homepage']);
        }
    }
};