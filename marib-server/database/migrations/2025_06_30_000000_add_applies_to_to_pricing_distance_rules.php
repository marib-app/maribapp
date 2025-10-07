<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('pricing_distance_rules')) {
            return;
        }

        if (! Schema::hasColumn('pricing_distance_rules', 'price_type')) {
            Schema::table('pricing_distance_rules', function (Blueprint $table) {
                $table->string('price_type', 50)->default('flat')->after('price');
            });
        }

        if (! Schema::hasColumn('pricing_distance_rules', 'applies_to')) {
            $afterColumn = Schema::hasColumn('pricing_distance_rules', 'price_type') ? 'price_type' : 'price';

            Schema::table('pricing_distance_rules', function (Blueprint $table) use ($afterColumn) {
                $table->string('applies_to', 50)->default('weight_tier')->after($afterColumn);
            });
        }

        if (Schema::hasColumn('pricing_distance_rules', 'price_type')) {
            DB::table('pricing_distance_rules')
                ->whereNull('price_type')
                ->orWhere('price_type', '')
                ->update(['price_type' => 'flat']);
        }

        if (Schema::hasColumn('pricing_distance_rules', 'applies_to')) {
            DB::table('pricing_distance_rules')
                ->whereNull('applies_to')
                ->orWhere('applies_to', '')
                ->update(['applies_to' => 'weight_tier']);
        }
    }

    public function down(): void
    {
        if (! Schema::hasTable('pricing_distance_rules')) {
            return;
        }

        if (Schema::hasColumn('pricing_distance_rules', 'applies_to')) {
            Schema::table('pricing_distance_rules', function (Blueprint $table) {
                $table->dropColumn('applies_to');
            });
        }

        if (Schema::hasColumn('pricing_distance_rules', 'price_type')) {
            Schema::table('pricing_distance_rules', function (Blueprint $table) {
                $table->dropColumn('price_type');
            });
        }
    }
};