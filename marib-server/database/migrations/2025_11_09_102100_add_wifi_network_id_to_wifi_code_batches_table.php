<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('wifi_code_batches', static function (Blueprint $table): void {
            if (! Schema::hasColumn('wifi_code_batches', 'wifi_network_id')) {
                $table->foreignId('wifi_network_id')
                    ->after('wifi_plan_id')
                    ->nullable()
                    ->constrained('wifi_networks')
                    ->cascadeOnDelete();
            }
        });
    }

    public function down(): void
    {
        Schema::table('wifi_code_batches', static function (Blueprint $table): void {
            if (Schema::hasColumn('wifi_code_batches', 'wifi_network_id')) {
                $table->dropForeign(['wifi_network_id']);
                $table->dropColumn('wifi_network_id');
            }
        });
    }
};
