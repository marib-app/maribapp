<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('storefront_ui_settings', function (Blueprint $table) {
            if (!Schema::hasColumn('storefront_ui_settings', 'new_offers_items')) {
                $table->json('new_offers_items')->nullable()->after('promotion_slots');
            }
            if (!Schema::hasColumn('storefront_ui_settings', 'discount_items')) {
                $table->json('discount_items')->nullable()->after('new_offers_items');
            }
        });
    }

    public function down(): void
    {
        Schema::table('storefront_ui_settings', function (Blueprint $table) {
            if (Schema::hasColumn('storefront_ui_settings', 'new_offers_items')) {
                $table->dropColumn('new_offers_items');
            }
            if (Schema::hasColumn('storefront_ui_settings', 'discount_items')) {
                $table->dropColumn('discount_items');
            }
        });
    }
};
