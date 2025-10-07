<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasColumn('pricing_weight_tiers', 'price_per_km')) {
            Schema::table('pricing_weight_tiers', function (Blueprint $table) {
                $table->decimal('price_per_km', 10, 2)->default(0)->after('status');
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasColumn('pricing_weight_tiers', 'price_per_km')) {
            Schema::table('pricing_weight_tiers', function (Blueprint $table) {
                $table->dropColumn('price_per_km');
            });
        }
    }
};