<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('pricing_distance_rules')) {
            return;
        }

        if (! Schema::hasColumn('pricing_distance_rules', 'notes')) {
            Schema::table('pricing_distance_rules', function (Blueprint $table) {
                $table->text('notes')->nullable()->after('sort_order');
            });
        }
    }

    public function down(): void
    {
        if (! Schema::hasTable('pricing_distance_rules')) {
            return;
        }

        if (Schema::hasColumn('pricing_distance_rules', 'notes')) {
            Schema::table('pricing_distance_rules', function (Blueprint $table) {
                $table->dropColumn('notes');
            });
        }
    }
};