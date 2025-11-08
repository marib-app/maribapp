<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        $isSqlite = Schema::getConnection()->getDriverName() === 'sqlite';

        Schema::table('cart_items', function (Blueprint $table) use ($isSqlite) {
            if (! $isSqlite && Schema::hasColumn('cart_items', 'user_id')) {
                try {
                    $table->dropForeign(['user_id']);
                } catch (\Throwable $exception) {
                    // Foreign key already removed or never created; continue.
                }
            }

            if (! $isSqlite && Schema::hasColumn('cart_items', 'item_id')) {
                try {
                    $table->dropForeign(['item_id']);
                } catch (\Throwable $exception) {
                    // Foreign key already removed or never created; continue.
                }
            }

            if (
                Schema::hasColumn('cart_items', 'user_id') &&
                Schema::hasColumn('cart_items', 'item_id') &&
                Schema::hasColumn('cart_items', 'department')
            ) {

                try {
                    $table->dropUnique('cart_items_user_id_item_id_department_unique');
                } catch (\Throwable $exception) {
                    // Index already dropped or does not exist; continue.
                }
            }

            if (! Schema::hasColumn('cart_items', 'variant_id')) {
                $table->foreignId('variant_id')->nullable();
            }

            if (! Schema::hasColumn('cart_items', 'attributes')) {
                $table->json('attributes')->nullable();
            }

            if (! Schema::hasColumn('cart_items', 'unit_price_locked')) {
                $table->decimal('unit_price_locked', 12, 2)->nullable();
            }

            if (! Schema::hasColumn('cart_items', 'currency')) {
                $table->string('currency', 3)->nullable();
            }

            if (! Schema::hasColumn('cart_items', 'stock_snapshot')) {
                $table->json('stock_snapshot')->nullable();
            }
        });

        DB::table('cart_items')->orderBy('id')->chunkById(100, function ($rows) {
            foreach ($rows as $row) {
                $itemCurrency = DB::table('items')->where('id', $row->item_id)->value('currency');
                $lockedPrice = $row->unit_price_locked ?? $row->unit_price ?? 0;
                $currency = $row->currency ?? $itemCurrency ?? 'USD';

                DB::table('cart_items')->where('id', $row->id)->update([
                    'unit_price_locked' => $lockedPrice,
                    'currency' => $currency,
                ]);
            }
        });

        Schema::table('cart_items', function (Blueprint $table) {
            $table->unique(['user_id', 'item_id', 'variant_id', 'department'], 'cart_items_user_item_variant_department_unique');
            if (Schema::hasColumn('cart_items', 'user_id')) {
                $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
            }

            if (Schema::hasColumn('cart_items', 'item_id')) {
                $table->foreign('item_id')->references('id')->on('items')->cascadeOnDelete();
            }

        });
    }

    public function down(): void
    {
        $isSqlite = Schema::getConnection()->getDriverName() === 'sqlite';

        Schema::table('cart_items', function (Blueprint $table) use ($isSqlite) {
            if (! $isSqlite && Schema::hasColumn('cart_items', 'user_id')) {
                try {
                    $table->dropForeign(['user_id']);
                } catch (\Throwable $exception) {
                    // Foreign key already removed or never created; continue.
                }
            }

            if (! $isSqlite && Schema::hasColumn('cart_items', 'item_id')) {
                try {
                    $table->dropForeign(['item_id']);
                } catch (\Throwable $exception) {
                    // Foreign key already removed or never created; continue.
                }
            }

            try {
                $table->dropUnique('cart_items_user_item_variant_department_unique');
            } catch (\Throwable $exception) {
                // Index already removed; continue.
            }

            if (Schema::hasColumn('cart_items', 'stock_snapshot')) {
                $table->dropColumn('stock_snapshot');
            }

            if (Schema::hasColumn('cart_items', 'currency')) {
                $table->dropColumn('currency');
            }

            if (Schema::hasColumn('cart_items', 'unit_price_locked')) {
                $table->dropColumn('unit_price_locked');
            }

            if (Schema::hasColumn('cart_items', 'attributes')) {
                $table->dropColumn('attributes');
            }

            if (Schema::hasColumn('cart_items', 'variant_id')) {
                $table->dropColumn('variant_id');
            }

            $table->unique(['user_id', 'item_id', 'department'], 'cart_items_user_id_item_id_department_unique');

            if (Schema::hasColumn('cart_items', 'user_id')) {
                $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
            }

            if (Schema::hasColumn('cart_items', 'item_id')) {
                $table->foreign('item_id')->references('id')->on('items')->cascadeOnDelete();
            }
        
        });
    }
};
