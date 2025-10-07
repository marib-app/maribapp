<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    private const LEGACY_DEFAULT_FILTERS = [
        'featured_only',
        'most_rated',
        'price_high',
        'price_low',
        'price_range',
    ];

    public function up(): void
    {
        if (! Schema::hasTable('feature_sections')) {
            return;
        }

        if (! Schema::hasColumn('feature_sections', 'filter')) {
            return;
        }

        DB::table('feature_sections')
            ->whereIn('filter', self::LEGACY_DEFAULT_FILTERS)
            ->delete();
    }

    public function down(): void
    {
        // No action required. Legacy auto-generated records should not be restored.
    }
};