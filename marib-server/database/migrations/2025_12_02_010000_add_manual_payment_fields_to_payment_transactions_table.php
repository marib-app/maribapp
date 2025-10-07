<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        Schema::table('payment_transactions', function (Blueprint $table) {
            // FK باسم قصير
            if (!Schema::hasColumn('payment_transactions', 'manual_payment_request_id')) {
                $table->unsignedBigInteger('manual_payment_request_id')->nullable()->after('user_id');
                $table->foreign('manual_payment_request_id', 'pt_mpr_fk')
                      ->references('id')->on('manual_payment_requests')
                      ->nullOnDelete();
            }

            if (!Schema::hasColumn('payment_transactions', 'currency')) {
                $table->string('currency', 8)->nullable()->after('amount');
            }

            if (!Schema::hasColumn('payment_transactions', 'receipt_path')) {
                // لا تعتمد على payment_signature غير الموجود
                $after = Schema::hasColumn('payment_transactions','currency') ? 'currency' : null;
                $col = $table->string('receipt_path', 2048)->nullable();
                if ($after) $col->after($after);
            }
        });
    }

    public function down(): void {
        Schema::table('payment_transactions', function (Blueprint $table) {
            if (Schema::hasColumn('payment_transactions', 'receipt_path')) {
                $table->dropColumn('receipt_path');
            }
            if (Schema::hasColumn('payment_transactions', 'currency')) {
                $table->dropColumn('currency');
            }
            if (Schema::hasColumn('payment_transactions', 'manual_payment_request_id')) {
                // نفس اسم الـ FK المختصر
                $table->dropForeign('pt_mpr_fk');
                $table->dropColumn('manual_payment_request_id');
            }
        });
    }
};
