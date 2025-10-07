<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        // احذف العمود ثم أعد إنشاؤه بالقيم الجديدة
        Schema::table('notifications', function (Blueprint $table) {
            $table->dropColumn('send_to');
        });

        Schema::table('notifications', function (Blueprint $table) {
            $table->enum('send_to', ['all', 'selected', 'individual', 'business', 'real_estate']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        // ارجاع العمود للقيم القديمة
        Schema::table('notifications', function (Blueprint $table) {
            $table->dropColumn('send_to');
        });

        Schema::table('notifications', function (Blueprint $table) {
            $table->enum('send_to', ['all', 'selected']);
        });
    }
};
