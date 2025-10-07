<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            if (!Schema::hasColumn('orders', 'coupon_code')) {
                $table->string('coupon_code')->nullable()->after('discount_amount');
            }

            if (!Schema::hasColumn('orders', 'coupon_id')) {
                $table->foreignId('coupon_id')->nullable()->after('coupon_code')->constrained('coupons')->nullOnDelete();
            }

            if (!Schema::hasColumn('orders', 'cart_snapshot')) {
                $table->json('cart_snapshot')->nullable()->after('notes');
            }

            if (!Schema::hasColumn('orders', 'pricing_snapshot')) {
                $table->json('pricing_snapshot')->nullable()->after('cart_snapshot');
            }

            if (!Schema::hasColumn('orders', 'status_timestamps')) {
                $table->json('status_timestamps')->nullable()->after('pricing_snapshot');
            }

            if (!Schema::hasColumn('orders', 'payment_reference')) {
                $table->string('payment_reference')->nullable()->after('payment_method');
            }

            if (!Schema::hasColumn('orders', 'payment_payload')) {
                $table->json('payment_payload')->nullable()->after('payment_reference');
            }

            if (!Schema::hasColumn('orders', 'payment_due_at')) {
                $table->timestamp('payment_due_at')->nullable()->after('payment_payload');
            }

            if (!Schema::hasColumn('orders', 'payment_collected_at')) {
                $table->timestamp('payment_collected_at')->nullable()->after('payment_due_at');
            }

            if (!Schema::hasColumn('orders', 'delivery_fee')) {
                $table->decimal('delivery_fee', 10, 2)->default(0)->after('delivery_price');
            }

            if (!Schema::hasColumn('orders', 'delivery_surcharge')) {
                $table->decimal('delivery_surcharge', 10, 2)->default(0)->after('delivery_fee');
            }

            if (!Schema::hasColumn('orders', 'delivery_discount')) {
                $table->decimal('delivery_discount', 10, 2)->default(0)->after('delivery_surcharge');
            }

            if (!Schema::hasColumn('orders', 'delivery_total')) {
                $table->decimal('delivery_total', 10, 2)->default(0)->after('delivery_discount');
            }

            if (!Schema::hasColumn('orders', 'delivery_collected_amount')) {
                $table->decimal('delivery_collected_amount', 10, 2)->default(0)->after('delivery_total');
            }

            if (!Schema::hasColumn('orders', 'delivery_collected_at')) {
                $table->timestamp('delivery_collected_at')->nullable()->after('delivery_collected_amount');
            }

            if (!Schema::hasColumn('orders', 'last_quoted_at')) {
                $table->timestamp('last_quoted_at')->nullable()->after('delivery_collected_at');
            }
        });
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            if (Schema::hasColumn('orders', 'last_quoted_at')) {
                $table->dropColumn('last_quoted_at');
            }

            if (Schema::hasColumn('orders', 'delivery_collected_at')) {
                $table->dropColumn('delivery_collected_at');
            }

            if (Schema::hasColumn('orders', 'delivery_collected_amount')) {
                $table->dropColumn('delivery_collected_amount');
            }

            if (Schema::hasColumn('orders', 'delivery_total')) {
                $table->dropColumn('delivery_total');
            }

            if (Schema::hasColumn('orders', 'delivery_discount')) {
                $table->dropColumn('delivery_discount');
            }

            if (Schema::hasColumn('orders', 'delivery_surcharge')) {
                $table->dropColumn('delivery_surcharge');
            }

            if (Schema::hasColumn('orders', 'delivery_fee')) {
                $table->dropColumn('delivery_fee');
            }

            if (Schema::hasColumn('orders', 'payment_collected_at')) {
                $table->dropColumn('payment_collected_at');
            }

            if (Schema::hasColumn('orders', 'payment_due_at')) {
                $table->dropColumn('payment_due_at');
            }

            if (Schema::hasColumn('orders', 'payment_payload')) {
                $table->dropColumn('payment_payload');
            }

            if (Schema::hasColumn('orders', 'payment_reference')) {
                $table->dropColumn('payment_reference');
            }

            if (Schema::hasColumn('orders', 'status_timestamps')) {
                $table->dropColumn('status_timestamps');
            }

            if (Schema::hasColumn('orders', 'pricing_snapshot')) {
                $table->dropColumn('pricing_snapshot');
            }

            if (Schema::hasColumn('orders', 'cart_snapshot')) {
                $table->dropColumn('cart_snapshot');
            }

            if (Schema::hasColumn('orders', 'coupon_id')) {
                $table->dropConstrainedForeignId('coupon_id');
            }

            if (Schema::hasColumn('orders', 'coupon_code')) {
                $table->dropColumn('coupon_code');
            }
        });
    }
};