<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    /**
     * Run the migrations.
     */
    public function up(): void {
        Schema::table('feature_sections', static function (Blueprint $table) {
            if (!Schema::hasColumn('feature_sections', 'section_type')) {
                $table->string('section_type')->default('homepage')->after('style');
                $table->index('section_type');
            }
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void {
        if (Schema::hasColumn('feature_sections', 'section_type')) {
            Schema::table('feature_sections', static function (Blueprint $table) {
                $table->dropIndex('feature_sections_section_type_index');
                $table->dropColumn('section_type');
            });
        }
    }
};