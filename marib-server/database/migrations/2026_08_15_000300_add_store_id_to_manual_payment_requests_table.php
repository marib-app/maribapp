<?php

use App\Models\Order;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        if (Schema::getConnection()->getDriverName() === 'sqlite') {
            return;
        }

        Schema::table('manual_payment_requests', function (Blueprint $table) {
            if (! Schema::hasColumn('manual_payment_requests', 'store_id')) {
                $table->foreignId('store_id')
                    ->nullable()
                    ->after('payable_id')
                    ->constrained('stores')
                    ->nullOnDelete();
            }
        });

        if (Schema::hasColumn('manual_payment_requests', 'payable_type')
            && Schema::hasColumn('manual_payment_requests', 'payable_id')
            && Schema::hasTable('orders')
        ) {
            $orderClass = addslashes(Order::class);

            DB::statement("
                UPDATE manual_payment_requests m
                JOIN orders o ON o.id = m.payable_id
                SET m.store_id = o.store_id
                WHERE m.payable_type = '{$orderClass}' AND m.store_id IS NULL
            ");
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        if (Schema::getConnection()->getDriverName() === 'sqlite') {
            return;
        }

        Schema::table('manual_payment_requests', function (Blueprint $table) {
            if (Schema::hasColumn('manual_payment_requests', 'store_id')) {
                $table->dropForeign(['store_id']);
                $table->dropColumn('store_id');
            }
        });
    }
};
