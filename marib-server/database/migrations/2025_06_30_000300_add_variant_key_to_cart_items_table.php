<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        $isSqlite = Schema::getConnection()->getDriverName() === 'sqlite';

        Schema::table('cart_items', static function (Blueprint $table) {
            if (! Schema::hasColumn('cart_items', 'variant_key')) {
                $table->string('variant_key', 512)->default('')->after('variant_id');
            }
        });

        DB::table('cart_items')->update(['variant_key' => DB::raw("COALESCE(variant_key, '')")]);

        Schema::table('cart_items', static function (Blueprint $table) use ($isSqlite) {
            if (! $isSqlite && Schema::hasColumn('cart_items', 'user_id')) {
                try {
                    $table->dropForeign(['user_id']);
                } catch (\Throwable $exception) {
                    // ignore missing foreign key
                }
            }

            if (! $isSqlite && Schema::hasColumn('cart_items', 'item_id')) {
                try {
                    $table->dropForeign(['item_id']);
                } catch (\Throwable $exception) {
                    // ignore missing foreign key
                }
            }


            try {
                $table->dropUnique('cart_items_user_item_variant_department_unique');
            } catch (\Throwable $exception) {
                // ignore missing index
            }

            $table->unique(['user_id', 'item_id', 'variant_key', 'department'], 'cart_items_user_item_variantkey_department_unique');
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

        Schema::table('cart_items', static function (Blueprint $table) use ($isSqlite) {

            if (! $isSqlite && Schema::hasColumn('cart_items', 'user_id')) {
                try {
                    $table->dropForeign(['user_id']);
                } catch (\Throwable $exception) {
                    // ignore missing foreign key
                }
            }

            if (! $isSqlite && Schema::hasColumn('cart_items', 'item_id')) {
                try {
                    $table->dropForeign(['item_id']);
                } catch (\Throwable $exception) {
                    // ignore missing foreign key
                }
            }

            try {
                $table->dropUnique('cart_items_user_item_variantkey_department_unique');
            } catch (\Throwable $exception) {
                // ignore missing index
            }

            if (Schema::hasColumn('cart_items', 'variant_key')) {
                $table->dropColumn('variant_key');
            }

            $table->unique(['user_id', 'item_id', 'variant_id', 'department'], 'cart_items_user_item_variant_department_unique');

            if (Schema::hasColumn('cart_items', 'user_id')) {
                $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
            }

            if (Schema::hasColumn('cart_items', 'item_id')) {
                $table->foreign('item_id')->references('id')->on('items')->cascadeOnDelete();
            }

        });
    }
};
