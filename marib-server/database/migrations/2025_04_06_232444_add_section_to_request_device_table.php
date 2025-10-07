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
    
            if (! Schema::hasTable('request_device')) {
            return;
        }

    
    
        Schema::table('request_device', function (Blueprint $table) {
            $table->string('section')->default('computer')->after('id');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {

        if (! Schema::hasTable('request_device')) {
            return;
        }


        Schema::table('request_device', function (Blueprint $table) {
            $table->dropColumn('section');
        });
    }
};