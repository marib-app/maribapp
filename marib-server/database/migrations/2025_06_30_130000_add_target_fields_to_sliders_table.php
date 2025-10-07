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
        Schema::table('sliders', static function (Blueprint $table) {
            if (!Schema::hasColumn('sliders', 'target_type') && !Schema::hasColumn('sliders', 'target_id')) {
                $table->nullableMorphs('target');
            } else {
                if (!Schema::hasColumn('sliders', 'target_type')) {
                    $table->string('target_type')->nullable();
                }

                if (!Schema::hasColumn('sliders', 'target_id')) {
                    $table->unsignedBigInteger('target_id')->nullable();
                }
            }

            if (!Schema::hasColumn('sliders', 'action_type')) {
                $table->string('action_type', 100)->nullable();
            }

            if (!Schema::hasColumn('sliders', 'action_payload')) {
                $table->json('action_payload')->nullable();
            }
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('sliders', static function (Blueprint $table) {
            if (Schema::hasColumn('sliders', 'action_payload')) {
                $table->dropColumn('action_payload');
            }

            if (Schema::hasColumn('sliders', 'action_type')) {
                $table->dropColumn('action_type');
            }

            if (Schema::hasColumn('sliders', 'target_type') && Schema::hasColumn('sliders', 'target_id')) {
                $table->dropMorphs('target');
            } else {
                if (Schema::hasColumn('sliders', 'target_type')) {
                    $table->dropColumn('target_type');
                }

                if (Schema::hasColumn('sliders', 'target_id')) {
                    $table->dropColumn('target_id');
                }
            }
        });
    }
};