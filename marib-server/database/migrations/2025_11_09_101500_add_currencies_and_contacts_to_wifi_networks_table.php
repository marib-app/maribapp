<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('wifi_networks', static function (Blueprint $table): void {
            if (! Schema::hasColumn('wifi_networks', 'currencies')) {
                $table->json('currencies')->nullable();
            }

            if (! Schema::hasColumn('wifi_networks', 'contacts')) {
                $table->json('contacts')->nullable();
            }
        });
    }

    public function down(): void
    {
        Schema::table('wifi_networks', static function (Blueprint $table): void {
            if (Schema::hasColumn('wifi_networks', 'contacts')) {
                $table->dropColumn('contacts');
            }
            if (Schema::hasColumn('wifi_networks', 'currencies')) {
                $table->dropColumn('currencies');
            }
        });
    }
};
