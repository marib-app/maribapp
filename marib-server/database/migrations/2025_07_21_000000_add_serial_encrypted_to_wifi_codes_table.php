<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('wifi_codes', function (Blueprint $table) {
            $table->string('serial_encrypted')->nullable()->after('password_encrypted');
        });
    }

    public function down(): void
    {
        Schema::table('wifi_codes', function (Blueprint $table) {
            $table->dropColumn('serial_encrypted');
        });
    }
};