<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        if (Schema::hasColumn('manual_payment_requests', 'service_request_id')) {
            return;
        }

        Schema::table('manual_payment_requests', function (Blueprint $table): void {
            $table->foreignId('service_request_id')
                ->nullable()
                ->after('payable_id')
                ->constrained('service_requests')
                ->nullOnDelete();
        });

        DB::table('manual_payment_requests')
            ->whereNull('service_request_id')
            ->whereIn('payable_type', [
                'App\\Models\\ServiceRequest',
                'service_request',
                'service_requests',
                '\\App\\Models\\ServiceRequest',
            ])
            ->update(['service_request_id' => DB::raw('payable_id')]);
    }

    public function down(): void
    {
        if (! Schema::hasColumn('manual_payment_requests', 'service_request_id')) {
            return;
        }

        Schema::table('manual_payment_requests', function (Blueprint $table): void {
            $table->dropForeign(['service_request_id']);
            $table->dropColumn('service_request_id');
        });
    }
};

