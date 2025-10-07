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
            if (! Schema::hasColumn('pricing_policies', 'vendor_id')) {
                $table->foreignId('vendor_id')
                    ->nullable()
                    ->after('department')
                    ->constrained('users')
                    ->nullOnDelete();
            }
        });
    }

    public function down(): void
    {
        if (! Schema::hasTable('pricing_policies')) {
            return;
        }

        Schema::table('pricing_policies', function (Blueprint $table) {
            if (Schema::hasColumn('pricing_policies', 'vendor_id')) {
                $table->dropConstrainedForeignId('vendor_id');
            }
        });
    }
};