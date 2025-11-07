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
        Schema::table('store_gateway_accounts', function (Blueprint $table) {
            if (! Schema::hasColumn('store_gateway_accounts', 'store_id')) {
                $table->foreignId('store_id')
                    ->nullable()
                    ->after('store_gateway_id')
                    ->constrained('stores')
                    ->cascadeOnDelete();
            }
        });

        Schema::table('items', function (Blueprint $table) {
            if (! Schema::hasColumn('items', 'store_id')) {
                $table->foreignId('store_id')
                    ->nullable()
                    ->after('user_id')
                    ->constrained('stores')
                    ->nullOnDelete();
                $table->index('store_id');
            }
        });

        Schema::table('orders', function (Blueprint $table) {
            if (! Schema::hasColumn('orders', 'store_id')) {
                $table->foreignId('store_id')
                    ->nullable()
                    ->after('seller_id')
                    ->constrained('stores')
                    ->nullOnDelete();
                $table->index('store_id');
            }
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            if (Schema::hasColumn('orders', 'store_id')) {
                $table->dropForeign(['store_id']);
                $table->dropColumn('store_id');
            }
        });

        Schema::table('items', function (Blueprint $table) {
            if (Schema::hasColumn('items', 'store_id')) {
                $table->dropForeign(['store_id']);
                $table->dropIndex(['store_id']);
                $table->dropColumn('store_id');
            }
        });

        Schema::table('store_gateway_accounts', function (Blueprint $table) {
            if (Schema::hasColumn('store_gateway_accounts', 'store_id')) {
                $table->dropForeign(['store_id']);
                $table->dropColumn('store_id');
            }
        });
    }
};
