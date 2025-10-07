<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            if (! Schema::hasColumn('orders', 'department')) {
                $table->string('department')->nullable()->after('seller_id');
            }

            if (! Schema::hasColumn('orders', 'invoice_no')) {
                $table->string('invoice_no')->nullable()->after('order_number');
            }

            if (! Schema::hasColumn('orders', 'address_snapshot')) {
                $table->json('address_snapshot')->nullable()->after('billing_address');
            }

            if (! Schema::hasColumn('orders', 'delivery_payment_timing')) {
                $table->string('delivery_payment_timing')->nullable()->after('delivery_price_breakdown');
            }

            if (! Schema::hasColumn('orders', 'delivery_payment_status')) {
                $table->string('delivery_payment_status')->nullable()->after('delivery_payment_timing');
            }

            if (! Schema::hasColumn('orders', 'delivery_online_payable')) {
                $table->decimal('delivery_online_payable', 10, 2)->default(0)->after('delivery_payment_status');
            }

            if (! Schema::hasColumn('orders', 'delivery_cod_fee')) {
                $table->decimal('delivery_cod_fee', 10, 2)->default(0)->after('delivery_online_payable');
            }

            if (! Schema::hasColumn('orders', 'delivery_cod_due')) {
                $table->decimal('delivery_cod_due', 10, 2)->default(0)->after('delivery_cod_fee');
            }

            if (! Schema::hasColumn('orders', 'status_history')) {
                $table->json('status_history')->nullable()->after('status_timestamps');
            }
        });

        Schema::table('order_items', function (Blueprint $table) {
            if (! Schema::hasColumn('order_items', 'variant_id')) {
                $table->unsignedBigInteger('variant_id')->nullable()->after('item_id');
                $table->index('variant_id');
            }

            if (! Schema::hasColumn('order_items', 'attributes')) {
                $table->json('attributes')->nullable()->after('options');
            }

            if (! Schema::hasColumn('order_items', 'weight_kg')) {
                $table->decimal('weight_kg', 12, 3)->default(0)->after('weight_grams');
            }
        });
    }

    public function down(): void
    {
        Schema::table('order_items', function (Blueprint $table) {
            if (Schema::hasColumn('order_items', 'weight_kg')) {
                $table->dropColumn('weight_kg');
            }

            if (Schema::hasColumn('order_items', 'attributes')) {
                $table->dropColumn('attributes');
            }

            if (Schema::hasColumn('order_items', 'variant_id')) {
                try {
                    $table->dropIndex('order_items_variant_id_index');
                } catch (\Throwable $exception) {
                    // Index already removed or never created.
                }

                $table->dropColumn('variant_id');
            }
        });

        Schema::table('orders', function (Blueprint $table) {
            if (Schema::hasColumn('orders', 'status_history')) {
                $table->dropColumn('status_history');
            }

            if (Schema::hasColumn('orders', 'delivery_cod_due')) {
                $table->dropColumn('delivery_cod_due');
            }

            if (Schema::hasColumn('orders', 'delivery_cod_fee')) {
                $table->dropColumn('delivery_cod_fee');
            }

            if (Schema::hasColumn('orders', 'delivery_online_payable')) {
                $table->dropColumn('delivery_online_payable');
            }

            if (Schema::hasColumn('orders', 'delivery_payment_status')) {
                $table->dropColumn('delivery_payment_status');
            }

            if (Schema::hasColumn('orders', 'delivery_payment_timing')) {
                $table->dropColumn('delivery_payment_timing');
            }

            if (Schema::hasColumn('orders', 'address_snapshot')) {
                $table->dropColumn('address_snapshot');
            }

            if (Schema::hasColumn('orders', 'invoice_no')) {
                $table->dropColumn('invoice_no');
            }

            if (Schema::hasColumn('orders', 'department')) {
                $table->dropColumn('department');
            }
        });
    }
};