<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        if (! Schema::hasColumn('feature_sections', 'is_active')) {
            Schema::table('feature_sections', static function (Blueprint $table) {
                $column = $table->boolean('is_active')->default(true);

                if (Schema::hasColumn('feature_sections', 'description')) {
                    $column->after('description');
                } else {
                    $column->after('max_price');
                }
            });
        }

        self::dropIndexIfExists('feature_sections', 'feature_sections_slug_unique', true);
        self::dropIndexIfExists('feature_sections', 'feature_sections_section_type_index');

        if (Schema::hasColumn('feature_sections', 'section_type') && Schema::hasColumn('feature_sections', 'slug')) {
            Schema::table('feature_sections', static function (Blueprint $table) {
                $table->unique(['section_type', 'slug'], 'feature_sections_section_type_slug_unique');
                $table->index(['section_type', 'slug'], 'feature_sections_section_type_slug_index');
            });
        }

        Cache::flush();
    }

    public function down(): void {
        self::dropIndexIfExists('feature_sections', 'feature_sections_section_type_slug_unique', true);
        self::dropIndexIfExists('feature_sections', 'feature_sections_section_type_slug_index');

        if (Schema::hasColumn('feature_sections', 'slug')) {
            Schema::table('feature_sections', static function (Blueprint $table) {
                $table->unique('slug');
            });
        }

        if (Schema::hasColumn('feature_sections', 'section_type')) {
            Schema::table('feature_sections', static function (Blueprint $table) {
                $table->index('section_type');
            });
        }

        if (Schema::hasColumn('feature_sections', 'is_active')) {
            Schema::table('feature_sections', static function (Blueprint $table) {
                $table->dropColumn('is_active');
            });
        }
    }

    private static function dropIndexIfExists(string $table, string $indexName, bool $isUnique = false): void {
        $schemaManager = Schema::getConnection()->getDoctrineSchemaManager();
        $indexes = $schemaManager->listTableIndexes($table);

        if (! array_key_exists($indexName, $indexes)) {
            return;
        }

        Schema::table($table, static function (Blueprint $table) use ($indexName, $isUnique) {
            if ($isUnique) {
                $table->dropUnique($indexName);
            } else {
                $table->dropIndex($indexName);
            }
        });
    }
};