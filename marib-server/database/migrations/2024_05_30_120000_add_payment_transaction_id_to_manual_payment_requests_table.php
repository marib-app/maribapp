<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        if (! Schema::hasTable('manual_payment_requests')) {
            return;
        }

        Schema::table('manual_payment_requests', static function (Blueprint $table): void {
            if (! Schema::hasColumn('manual_payment_requests', 'payment_transaction_id')) {
                $table->foreignId('payment_transaction_id')
                    ->nullable()
                    ->after('user_id')
                    ->constrained('payment_transactions')
                    ->nullOnDelete();
            }
        });
    }

    public function down(): void
    {
        if (! Schema::hasTable('manual_payment_requests')) {
            return;
        }

        Schema::table('manual_payment_requests', static function (Blueprint $table): void {
            if (Schema::hasColumn('manual_payment_requests', 'payment_transaction_id')) {
                $table->dropConstrainedForeignId('payment_transaction_id');
            }
        });
    }
};