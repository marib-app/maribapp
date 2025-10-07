<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            if (! Schema::hasColumn('orders', 'deposit_minimum_amount')) {
                $table->decimal('deposit_minimum_amount', 12, 2)->default(0)->after('delivery_collected_at');
            }

            if (! Schema::hasColumn('orders', 'deposit_ratio')) {
                $table->decimal('deposit_ratio', 5, 4)->nullable()->after('deposit_minimum_amount');
            }

            if (! Schema::hasColumn('orders', 'deposit_amount_paid')) {
                $table->decimal('deposit_amount_paid', 12, 2)->default(0)->after('deposit_ratio');
            }

            if (! Schema::hasColumn('orders', 'deposit_remaining_balance')) {
                $table->decimal('deposit_remaining_balance', 12, 2)->default(0)->after('deposit_amount_paid');
            }

            if (! Schema::hasColumn('orders', 'deposit_includes_shipping')) {
                $table->boolean('deposit_includes_shipping')->default(false)->after('deposit_remaining_balance');
            }
        });

        Schema::table('order_items', function (Blueprint $table) {
            if (! Schema::hasColumn('order_items', 'deposit_minimum_amount')) {
                $table->decimal('deposit_minimum_amount', 12, 2)->default(0)->after('weight_kg');
            }

            if (! Schema::hasColumn('order_items', 'deposit_ratio')) {
                $table->decimal('deposit_ratio', 5, 4)->nullable()->after('deposit_minimum_amount');
            }

            if (! Schema::hasColumn('order_items', 'deposit_amount_paid')) {
                $table->decimal('deposit_amount_paid', 12, 2)->default(0)->after('deposit_ratio');
            }

            if (! Schema::hasColumn('order_items', 'deposit_remaining_balance')) {
                $table->decimal('deposit_remaining_balance', 12, 2)->default(0)->after('deposit_amount_paid');
            }

            if (! Schema::hasColumn('order_items', 'deposit_includes_shipping')) {
                $table->boolean('deposit_includes_shipping')->default(false)->after('deposit_remaining_balance');
            }
        });
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            if (Schema::hasColumn('orders', 'deposit_includes_shipping')) {
                $table->dropColumn('deposit_includes_shipping');
            }

            if (Schema::hasColumn('orders', 'deposit_remaining_balance')) {
                $table->dropColumn('deposit_remaining_balance');
            }

            if (Schema::hasColumn('orders', 'deposit_amount_paid')) {
                $table->dropColumn('deposit_amount_paid');
            }

            if (Schema::hasColumn('orders', 'deposit_ratio')) {
                $table->dropColumn('deposit_ratio');
            }

            if (Schema::hasColumn('orders', 'deposit_minimum_amount')) {
                $table->dropColumn('deposit_minimum_amount');
            }
        });

        Schema::table('order_items', function (Blueprint $table) {
            if (Schema::hasColumn('order_items', 'deposit_includes_shipping')) {
                $table->dropColumn('deposit_includes_shipping');
            }

            if (Schema::hasColumn('order_items', 'deposit_remaining_balance')) {
                $table->dropColumn('deposit_remaining_balance');
            }

            if (Schema::hasColumn('order_items', 'deposit_amount_paid')) {
                $table->dropColumn('deposit_amount_paid');
            }

            if (Schema::hasColumn('order_items', 'deposit_ratio')) {
                $table->dropColumn('deposit_ratio');
            }

            if (Schema::hasColumn('order_items', 'deposit_minimum_amount')) {
                $table->dropColumn('deposit_minimum_amount');
            }
        });
    }
};