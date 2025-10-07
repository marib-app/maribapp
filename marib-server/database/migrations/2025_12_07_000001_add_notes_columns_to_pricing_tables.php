<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('pricing_policies') && ! Schema::hasColumn('pricing_policies', 'notes')) {
            Schema::table('pricing_policies', function (Blueprint $table) {
                $notesColumn = $table->text('notes')->nullable();

                if (Schema::hasColumn('pricing_policies', 'max_order_total')) {
                    $notesColumn->after('max_order_total');
                } elseif (Schema::hasColumn('pricing_policies', 'min_order_total')) {
                    $notesColumn->after('min_order_total');
                } elseif (Schema::hasColumn('pricing_policies', 'free_shipping_threshold')) {
                    $notesColumn->after('free_shipping_threshold');
                }
            });
        }

        if (Schema::hasTable('pricing_weight_tiers') && ! Schema::hasColumn('pricing_weight_tiers', 'notes')) {
            Schema::table('pricing_weight_tiers', function (Blueprint $table) {
                $notesColumn = $table->text('notes')->nullable();

                if (Schema::hasColumn('pricing_weight_tiers', 'sort_order')) {
                    $notesColumn->after('sort_order');
                } elseif (Schema::hasColumn('pricing_weight_tiers', 'flat_fee')) {
                    $notesColumn->after('flat_fee');
                } elseif (Schema::hasColumn('pricing_weight_tiers', 'price_per_km')) {
                    $notesColumn->after('price_per_km');
                }
            });
        }

        if (Schema::hasTable('pricing_distance_rules') && ! Schema::hasColumn('pricing_distance_rules', 'notes')) {
            Schema::table('pricing_distance_rules', function (Blueprint $table) {
                $notesColumn = $table->text('notes')->nullable();

                if (Schema::hasColumn('pricing_distance_rules', 'sort_order')) {
                    $notesColumn->after('sort_order');
                } elseif (Schema::hasColumn('pricing_distance_rules', 'price_type')) {
                    $notesColumn->after('price_type');
                }
            });
        }
    }

    public function down(): void
    {
        // Intentionally left blank: columns are part of the expected schema and should
        // remain in place even if this migration is rolled back.
    }
};