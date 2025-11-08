<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

return new class extends Migration {
    public function up(): void
    {
        if (Schema::getConnection()->getDriverName() === 'sqlite') {
            return;
        }

        $constraints = DB::table('information_schema.KEY_COLUMN_USAGE')
            ->select('CONSTRAINT_NAME', 'COLUMN_NAME')
            ->where('TABLE_SCHEMA', DB::raw('DATABASE()'))
            ->where('TABLE_NAME', 'featured_items')
            ->whereIn('COLUMN_NAME', ['package_id', 'user_purchased_package_id'])
            ->whereNotNull('REFERENCED_TABLE_NAME')
            ->get();

        foreach ($constraints as $constraint) {
            DB::statement(sprintf(
                'ALTER TABLE `featured_items` DROP FOREIGN KEY `%s`',
                $constraint->CONSTRAINT_NAME
            ));
        }

        

        Schema::table('featured_items', static function (Blueprint $table) {
            $table->unsignedBigInteger('package_id')->nullable()->change();
            $table->unsignedBigInteger('user_purchased_package_id')->nullable()->change();
        });

        Schema::table('featured_items', static function (Blueprint $table) {
            $table->foreign('package_id')
                ->references('id')
                ->on('packages')
                ->nullOnDelete();

            $table->foreign('user_purchased_package_id')
                ->references('id')
                ->on('user_purchased_packages')
                ->nullOnDelete();
        });
    }

    public function down(): void
    {
        if (Schema::getConnection()->getDriverName() === 'sqlite') {
            return;
        }

        Schema::table('featured_items', static function (Blueprint $table) {
            $table->dropForeign(['package_id']);
            $table->dropForeign(['user_purchased_package_id']);
        });

        Schema::table('featured_items', static function (Blueprint $table) {
            $table->unsignedBigInteger('package_id')->nullable(false)->change();
            $table->unsignedBigInteger('user_purchased_package_id')->nullable(false)->change();
        });

        Schema::table('featured_items', static function (Blueprint $table) {
            $table->foreign('package_id')
                ->references('id')
                ->on('packages')
                ->cascadeOnDelete();

            $table->foreign('user_purchased_package_id')
                ->references('id')
                ->on('user_purchased_packages')
                ->cascadeOnDelete();
        });
    }
};
