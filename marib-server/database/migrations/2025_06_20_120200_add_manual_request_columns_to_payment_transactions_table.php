<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    /**
     * Run the migrations.
     */
    public function up(): void {
        Schema::table('payment_transactions', static function (Blueprint $table) {
            if (!Schema::hasColumn('payment_transactions', 'payable_type')) {
                $table->string('payable_type')->nullable()->after('order_id');
            }

            if (!Schema::hasColumn('payment_transactions', 'payable_id')) {
                $table->unsignedBigInteger('payable_id')->nullable()->after('payable_type');
            }

            if (!Schema::hasColumn('payment_transactions', 'manual_payment_request_id')) {
                $table->foreignId('manual_payment_request_id')
                    ->nullable()
                    ->after('payable_id')
                    ->constrained('manual_payment_requests')
                    ->nullOnDelete();
            }

            if (!Schema::hasColumn('payment_transactions', 'meta')) {
                $table->json('meta')->nullable()->after('payment_status');
            }
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void {
        Schema::table('payment_transactions', static function (Blueprint $table) {
            if (Schema::hasColumn('payment_transactions', 'manual_payment_request_id')) {
                $table->dropForeign(['manual_payment_request_id']);
                $table->dropColumn('manual_payment_request_id');
            }

            if (Schema::hasColumn('payment_transactions', 'payable_id')) {
                $table->dropColumn('payable_id');
            }

            if (Schema::hasColumn('payment_transactions', 'payable_type')) {
                $table->dropColumn('payable_type');
            }

            if (Schema::hasColumn('payment_transactions', 'meta')) {
                $table->dropColumn('meta');
            }
        });
    }
};