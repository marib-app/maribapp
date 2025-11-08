<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        if (! Schema::hasColumn('feature_sections', 'data_source')) {
            Schema::table('feature_sections', static function (Blueprint $table): void {
                $table->string('data_source', 32)
                    ->default('dynamic')
                    ->after('filter');
            });
        }

        if (! Schema::hasTable('feature_section_items')) {
            Schema::create('feature_section_items', static function (Blueprint $table): void {
                $table->id();
                $table->foreignId('feature_section_id')
                    ->constrained()
                    ->cascadeOnDelete();
                $table->foreignId('item_id')
                    ->constrained()
                    ->cascadeOnDelete();
                $table->unsignedInteger('position')->default(0);
                $table->timestamps();

                $table->unique(['feature_section_id', 'item_id'], 'feature_section_items_unique_item');
                $table->index(['feature_section_id', 'position'], 'feature_section_items_position_index');
            });
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('feature_section_items');

        if (Schema::hasColumn('feature_sections', 'data_source')) {
            Schema::table('feature_sections', static function (Blueprint $table): void {
                $table->dropColumn('data_source');
            });
        }
    }
};
