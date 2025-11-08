<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        if (Schema::getConnection()->getDriverName() === 'sqlite') {
            return;
        }

        Schema::table('cart_items', function (Blueprint $table) {
            $table->foreignId('store_id')
                ->nullable()
                ->after('item_id')
                ->constrained()
                ->nullOnDelete();
        });

        DB::statement('
            UPDATE cart_items ci
            INNER JOIN items i ON i.id = ci.item_id
            SET ci.store_id = i.store_id
            WHERE ci.store_id IS NULL
        ');
    }

    public function down(): void
    {
        if (Schema::getConnection()->getDriverName() === 'sqlite') {
            return;
        }

        Schema::table('cart_items', function (Blueprint $table) {
            $table->dropConstrainedForeignId('store_id');
        });
    }
};
