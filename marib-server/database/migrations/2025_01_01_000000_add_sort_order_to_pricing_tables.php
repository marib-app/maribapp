<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasColumn('pricing_weight_tiers', 'sort_order')) {
            Schema::table('pricing_weight_tiers', function (Blueprint $table) {
                $table->integer('sort_order')->default(0);
            });

            $ids = DB::table('pricing_weight_tiers')->orderBy('id')->pluck('id');

            foreach ($ids as $index => $id) {
                DB::table('pricing_weight_tiers')
                    ->where('id', $id)
                    ->update(['sort_order' => $index + 1]);
            }
        }

        if (! Schema::hasColumn('pricing_distance_rules', 'sort_order')) {
            Schema::table('pricing_distance_rules', function (Blueprint $table) {
                $table->integer('sort_order')->default(0);
            });

            $ids = DB::table('pricing_distance_rules')->orderBy('id')->pluck('id');

            foreach ($ids as $index => $id) {
                DB::table('pricing_distance_rules')
                    ->where('id', $id)
                    ->update(['sort_order' => $index + 1]);
            }
        }
    }

    public function down(): void
    {
        if (Schema::hasColumn('pricing_weight_tiers', 'sort_order')) {
            Schema::table('pricing_weight_tiers', function (Blueprint $table) {
                $table->dropColumn('sort_order');
            });
        }

        if (Schema::hasColumn('pricing_distance_rules', 'sort_order')) {
            Schema::table('pricing_distance_rules', function (Blueprint $table) {
                $table->dropColumn('sort_order');
            });
        }
    }
};