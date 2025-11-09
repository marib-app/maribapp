<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('wifi_networks', static function (Blueprint $table): void {
            if (! Schema::hasColumn('wifi_networks', 'settings')) {
                $table->json('settings')->nullable();
            }
        });
    }

    public function down(): void
    {
        Schema::table('wifi_networks', static function (Blueprint $table): void {
            if (Schema::hasColumn('wifi_networks', 'settings')) {
                $table->dropColumn('settings');
            }
        });
    }
};
