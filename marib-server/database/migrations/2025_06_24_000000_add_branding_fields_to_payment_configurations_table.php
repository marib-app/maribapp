<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('payment_configurations', static function (Blueprint $table) {
            $table->string('display_name')->nullable()->after('payment_method');
            $table->text('note')->nullable()->after('currency_code');
            $table->string('logo_path')->nullable()->after('note');
        });
    }

    public function down(): void
    {
        Schema::table('payment_configurations', static function (Blueprint $table) {
            $table->dropColumn(['display_name', 'note', 'logo_path']);
        });
    }
};