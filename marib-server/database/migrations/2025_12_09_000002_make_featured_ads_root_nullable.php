<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        if (! Schema::hasTable('featured_ads_configs')) {
            return;
        }

        // Allow null to support interface-only configs without forcing a category id.
        DB::statement('ALTER TABLE featured_ads_configs MODIFY root_category_id BIGINT UNSIGNED NULL');
    }

    public function down(): void
    {
        if (! Schema::hasTable('featured_ads_configs')) {
            return;
        }

        // Revert to NOT NULL with default 0 to keep migration safe.
        DB::statement('ALTER TABLE featured_ads_configs MODIFY root_category_id BIGINT UNSIGNED NOT NULL DEFAULT 0');
    }
};
