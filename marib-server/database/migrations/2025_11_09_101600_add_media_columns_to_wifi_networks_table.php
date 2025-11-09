<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('wifi_networks', static function (Blueprint $table): void {
            if (! Schema::hasColumn('wifi_networks', 'icon_path')) {
                $table->string('icon_path')->nullable();
            }

            if (! Schema::hasColumn('wifi_networks', 'login_screenshot_path')) {
                $table->string('login_screenshot_path')->nullable();
            }
        });
    }

    public function down(): void
    {
        Schema::table('wifi_networks', static function (Blueprint $table): void {
            if (Schema::hasColumn('wifi_networks', 'login_screenshot_path')) {
                $table->dropColumn('login_screenshot_path');
            }

            if (Schema::hasColumn('wifi_networks', 'icon_path')) {
                $table->dropColumn('icon_path');
            }
        });
    }
};
