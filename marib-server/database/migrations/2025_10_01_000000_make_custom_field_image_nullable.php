<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('custom_fields', function (Blueprint $table) {
            $table->string('image')->nullable()->change();
        });
    }

    public function down(): void
    {
        DB::table('custom_fields')
            ->whereNull('image')
            ->update(['image' => '']);

        Schema::table('custom_fields', function (Blueprint $table) {
            $table->string('image')->nullable(false)->change();
        });
    }
};