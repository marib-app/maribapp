<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        // Only add the column if it doesn't already exist
        if (!Schema::hasColumn('users', 'additional_info')) {
            Schema::table('users', function (Blueprint $table) {
                // Check if additional_contacts column exists before referencing it
                if (Schema::hasColumn('users', 'additional_contacts')) {
                    $table->json('additional_info')->nullable()->after('additional_contacts');
                } else {
                    // If additional_contacts doesn't exist, add after mobile column
                    $table->json('additional_info')->nullable()->after('mobile');
                }
            });
        }
        
        // نقل البيانات من additional_contacts إلى additional_info مع إعادة التنظيم (فقط إذا كان العمود موجود)
        if (Schema::hasColumn('users', 'additional_contacts') && Schema::hasColumn('users', 'additional_info')) {
            DB::statement("
                UPDATE users 
                SET additional_info = additional_contacts 
                WHERE additional_contacts IS NOT NULL AND additional_info IS NULL
            ");
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('additional_info');
        });
    }
};