<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            // حذف العمود القديم additional_contacts (فقط إذا كان موجود)
            if (Schema::hasColumn('users', 'additional_contacts')) {
                $table->dropColumn('additional_contacts');
            }
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            // إعادة إضافة العمود القديم في حالة rollback
            $table->json('additional_contacts')->nullable();
        });
    }
};