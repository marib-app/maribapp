<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up()
    {
        Schema::table('users', function (Blueprint $table) {
            // تعريف أنواع الحسابات:
            // 1 = عميل (customer)
            // 2 = تاجر (seller)
            // 3 = مسوق (marketer)
            // null = غير محدد
            $table->tinyInteger('account_type')->nullable()->after('email');
        });
    }
    

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('account_type');
        });
    }
};
