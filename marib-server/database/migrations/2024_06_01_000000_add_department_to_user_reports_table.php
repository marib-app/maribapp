<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('user_reports', static function (Blueprint $table) {
            $table->string('department')->nullable()->after('item_id');
            $table->index('department');
        });
    }

    public function down(): void
    {
        Schema::table('user_reports', static function (Blueprint $table) {
            $table->dropIndex('user_reports_department_index');
            $table->dropColumn('department');
        });
    }
};