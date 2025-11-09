<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('wifi_plans', static function (Blueprint $table): void {
            if (! Schema::hasColumn('wifi_plans', 'duration_days')) {
                $table->unsignedSmallInteger('duration_days')->nullable();
            }

            if (! Schema::hasColumn('wifi_plans', 'data_cap_gb')) {
                $table->decimal('data_cap_gb', 10, 3)->nullable();
            }

            if (! Schema::hasColumn('wifi_plans', 'currency')) {
                $table->char('currency', 3)->nullable()->index();
            }

            if (! Schema::hasColumn('wifi_plans', 'price')) {
                $table->decimal('price', 12, 4)->default(0);
            }
        });
    }

    public function down(): void
    {
        Schema::table('wifi_plans', static function (Blueprint $table): void {
            if (Schema::hasColumn('wifi_plans', 'price')) {
                $table->dropColumn('price');
            }
            if (Schema::hasColumn('wifi_plans', 'currency')) {
                $table->dropColumn('currency');
            }
            if (Schema::hasColumn('wifi_plans', 'data_cap_gb')) {
                $table->dropColumn('data_cap_gb');
            }
            if (Schema::hasColumn('wifi_plans', 'duration_days')) {
                $table->dropColumn('duration_days');
            }
        });
    }
};
