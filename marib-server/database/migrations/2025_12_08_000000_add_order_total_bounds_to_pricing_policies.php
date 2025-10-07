<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('pricing_policies')) {
            return;
        }

        Schema::table('pricing_policies', function (Blueprint $table) {
            if (! Schema::hasColumn('pricing_policies', 'min_order_total')) {
                $table->decimal('min_order_total', 10, 2)->nullable()->after('department');
            }

            if (! Schema::hasColumn('pricing_policies', 'max_order_total')) {
                $afterColumn = Schema::hasColumn('pricing_policies', 'min_order_total') ? 'min_order_total' : 'department';

                $table->decimal('max_order_total', 10, 2)->nullable()->after($afterColumn);
            }
        });
    }

    public function down(): void
    {
        if (! Schema::hasTable('pricing_policies')) {
            return;
        }

        Schema::table('pricing_policies', function (Blueprint $table) {
            if (Schema::hasColumn('pricing_policies', 'max_order_total')) {
                $table->dropColumn('max_order_total');
            }

            if (Schema::hasColumn('pricing_policies', 'min_order_total')) {
                $table->dropColumn('min_order_total');
            }
        });
    }
};