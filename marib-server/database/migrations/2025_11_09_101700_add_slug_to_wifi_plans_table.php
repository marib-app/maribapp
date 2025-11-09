<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('wifi_plans', static function (Blueprint $table): void {
            if (! Schema::hasColumn('wifi_plans', 'slug')) {
                $table->string('slug')->nullable()->unique();
            }
        });
    }

    public function down(): void
    {
        Schema::table('wifi_plans', static function (Blueprint $table): void {
            if (Schema::hasColumn('wifi_plans', 'slug')) {
                $table->dropUnique('wifi_plans_slug_unique');
                $table->dropColumn('slug');
            }
        });
    }
};
