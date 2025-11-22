<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('wifi_networks')) {
            return;
        }

        Schema::table('wifi_networks', static function (Blueprint $table): void {
            if (! Schema::hasColumn('wifi_networks', 'statistics')) {
                $table->json('statistics')->nullable()->after('settings');
            }
        });
    }

    public function down(): void
    {
        if (! Schema::hasTable('wifi_networks')) {
            return;
        }

        Schema::table('wifi_networks', static function (Blueprint $table): void {
            if (Schema::hasColumn('wifi_networks', 'statistics')) {
                $table->dropColumn('statistics');
            }
        });
    }
};
