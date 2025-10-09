<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('items', static function (Blueprint $table) {
            if (! Schema::hasColumn('items', 'discount_type')) {
                $table->string('discount_type', 32)->nullable()->after('price');
            }

            if (! Schema::hasColumn('items', 'discount_value')) {
                $table->decimal('discount_value', 12, 2)->nullable()->after('discount_type');
            }

            if (! Schema::hasColumn('items', 'discount_start')) {
                $table->timestamp('discount_start')->nullable()->after('discount_value');
            }

            if (! Schema::hasColumn('items', 'discount_end')) {
                $table->timestamp('discount_end')->nullable()->after('discount_start');
            }
        });
    }

    public function down(): void
    {
        Schema::table('items', static function (Blueprint $table) {
            if (Schema::hasColumn('items', 'discount_end')) {
                $table->dropColumn('discount_end');
            }
            if (Schema::hasColumn('items', 'discount_start')) {
                $table->dropColumn('discount_start');
            }
            if (Schema::hasColumn('items', 'discount_value')) {
                $table->dropColumn('discount_value');
            }
            if (Schema::hasColumn('items', 'discount_type')) {
                $table->dropColumn('discount_type');
            }
        });
    }
};