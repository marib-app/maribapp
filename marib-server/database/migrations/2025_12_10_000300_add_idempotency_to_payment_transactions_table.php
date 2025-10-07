<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('payment_transactions', function (Blueprint $table) {
            if (!Schema::hasColumn('payment_transactions', 'idempotency_key')) {
                $table->string('idempotency_key')->nullable()->after('order_id');
                $table->unique(['payment_gateway', 'idempotency_key'], 'payment_transactions_gateway_idempotency_unique');
            }
        });
    }

    public function down(): void
    {
        Schema::table('payment_transactions', function (Blueprint $table) {
            if (Schema::hasColumn('payment_transactions', 'idempotency_key')) {
                $table->dropUnique('payment_transactions_gateway_idempotency_unique');
                $table->dropColumn('idempotency_key');
            }
        });
    }
};