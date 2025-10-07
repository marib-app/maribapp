<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('order_items', function (Blueprint $table) {
            if (!Schema::hasColumn('order_items', 'item_snapshot')) {
                $table->json('item_snapshot')->nullable()->after('options');
            }

            if (!Schema::hasColumn('order_items', 'pricing_snapshot')) {
                $table->json('pricing_snapshot')->nullable()->after('item_snapshot');
            }

            if (!Schema::hasColumn('order_items', 'weight_grams')) {
                $table->decimal('weight_grams', 12, 3)->default(0)->after('pricing_snapshot');
            }
        });
    }

    public function down(): void
    {
        Schema::table('order_items', function (Blueprint $table) {
            if (Schema::hasColumn('order_items', 'weight_grams')) {
                $table->dropColumn('weight_grams');
            }

            if (Schema::hasColumn('order_items', 'pricing_snapshot')) {
                $table->dropColumn('pricing_snapshot');
            }

            if (Schema::hasColumn('order_items', 'item_snapshot')) {
                $table->dropColumn('item_snapshot');
            }
        });
    }
};