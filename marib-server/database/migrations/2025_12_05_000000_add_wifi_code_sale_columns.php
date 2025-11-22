<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('wifi_codes')) {
            return;
        }

        Schema::table('wifi_codes', static function (Blueprint $table): void {
            if (! Schema::hasColumn('wifi_codes', 'sold_at')) {
                $table->dateTime('sold_at')->nullable()->after('expiry_date');
            }

            if (! Schema::hasColumn('wifi_codes', 'delivered_at')) {
                $table->dateTime('delivered_at')->nullable()->after('sold_at');
            }
        });
    }

    public function down(): void
    {
        if (! Schema::hasTable('wifi_codes')) {
            return;
        }

        Schema::table('wifi_codes', static function (Blueprint $table): void {
            if (Schema::hasColumn('wifi_codes', 'delivered_at')) {
                $table->dropColumn('delivered_at');
            }

            if (Schema::hasColumn('wifi_codes', 'sold_at')) {
                $table->dropColumn('sold_at');
            }
        });
    }
};
