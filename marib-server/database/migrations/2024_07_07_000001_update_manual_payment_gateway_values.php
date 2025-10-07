<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        if (!Schema::hasTable('payment_transactions')) {
            return;
        }

        DB::table('payment_transactions')
            ->whereIn('payment_gateway', ['Manual', 'manual'])
            ->update(['payment_gateway' => 'manual_bank']);
    }

    public function down(): void {
        if (!Schema::hasTable('payment_transactions')) {
            return;
        }

        DB::table('payment_transactions')
            ->where('payment_gateway', 'manual_bank')
            ->update(['payment_gateway' => 'Manual']);
    }
};