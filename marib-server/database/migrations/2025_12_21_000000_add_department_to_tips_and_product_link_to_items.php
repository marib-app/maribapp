<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('tips', function (Blueprint $table) {
            if (! Schema::hasColumn('tips', 'department')) {
                $table->string('department')->nullable()->after('description');
            }
        });

        DB::table('tips')->whereNull('department')->update(['department' => 'store']);

        Schema::table('items', function (Blueprint $table) {
            if (! Schema::hasColumn('items', 'product_link')) {
                $table->string('product_link')->nullable()->after('description');
            }
        });
    }

    public function down(): void
    {
        Schema::table('tips', function (Blueprint $table) {
            if (Schema::hasColumn('tips', 'department')) {
                $table->dropColumn('department');
            }
        });

        Schema::table('items', function (Blueprint $table) {
            if (Schema::hasColumn('items', 'product_link')) {
                $table->dropColumn('product_link');
            }
        });
    }
};