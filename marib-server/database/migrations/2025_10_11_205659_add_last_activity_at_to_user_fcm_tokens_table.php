<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        Schema::table('user_fcm_tokens', static function (Blueprint $table) {
            $table->timestamp('last_activity_at')->nullable()->after('platform_type');
        });
    }

    public function down(): void {
        Schema::table('user_fcm_tokens', static function (Blueprint $table) {
            $table->dropColumn('last_activity_at');
        });
    }
};