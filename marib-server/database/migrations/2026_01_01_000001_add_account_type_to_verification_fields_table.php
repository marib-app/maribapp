<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('verification_fields', static function (Blueprint $table) {
            if (!Schema::hasColumn('verification_fields', 'account_type')) {
                $table->enum('account_type', ['individual', 'commercial', 'realestate'])
                    ->default('individual')
                    ->after('type');
            }
        });
    }

    public function down(): void
    {
        Schema::table('verification_fields', static function (Blueprint $table) {
            if (Schema::hasColumn('verification_fields', 'account_type')) {
                $table->dropColumn('account_type');
            }
        });
    }
};
