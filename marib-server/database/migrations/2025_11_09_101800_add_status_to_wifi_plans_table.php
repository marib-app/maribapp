<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('wifi_plans', static function (Blueprint $table): void {
            if (! Schema::hasColumn('wifi_plans', 'status')) {
                $table->string('status')->nullable()->index();
            }

            if (! Schema::hasColumn('wifi_plans', 'is_unlimited')) {
                $table->boolean('is_unlimited')->default(false);
            }

            if (! Schema::hasColumn('wifi_plans', 'sort_order')) {
                $table->unsignedInteger('sort_order')->default(0);
            }
        });
    }

    public function down(): void
    {
        Schema::table('wifi_plans', static function (Blueprint $table): void {
            if (Schema::hasColumn('wifi_plans', 'sort_order')) {
                $table->dropColumn('sort_order');
            }
            if (Schema::hasColumn('wifi_plans', 'is_unlimited')) {
                $table->dropColumn('is_unlimited');
            }
            if (Schema::hasColumn('wifi_plans', 'status')) {
                $table->dropColumn('status');
            }
        });
    }
};
