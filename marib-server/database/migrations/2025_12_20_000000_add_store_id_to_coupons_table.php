<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('coupons')) {
            return;
        }

        if (Schema::hasColumn('coupons', 'store_id')) {
            return;
        }

        Schema::table('coupons', function (Blueprint $table) {
            $table->foreignId('store_id')
                ->after('id')
                ->nullable()
                ->constrained()
                ->nullOnDelete();
        });
    }

    public function down(): void
    {
        if (! Schema::hasTable('coupons')) {
            return;
        }

        if (! Schema::hasColumn('coupons', 'store_id')) {
            return;
        }

        Schema::table('coupons', function (Blueprint $table) {
            $table->dropConstrainedForeignId('store_id');
        });
    }
};
