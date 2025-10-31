<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasColumn('items', 'review_link')) {
            if (Schema::hasColumn('items', 'product_link')) {
                Schema::table('items', function (Blueprint $table) {
                    $table->string('review_link')->nullable()->after('product_link');
                });
            } else {
                Schema::table('items', function (Blueprint $table) {
                    $table->string('review_link')->nullable(); // بدون after
                });
            }
        }
    }

    public function down(): void
    {
        if (Schema::hasColumn('items', 'review_link')) {
            Schema::table('items', function (Blueprint $table) {
                $table->dropColumn('review_link');
            });
        }
    }
};
