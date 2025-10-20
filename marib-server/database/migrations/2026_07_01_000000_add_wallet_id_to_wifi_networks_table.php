<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('wifi_networks') || Schema::hasColumn('wifi_networks', 'wallet_id')) {
            return;
        }

        $placeAfterNotes = Schema::hasColumn('wifi_networks', 'notes');
        $walletAccountsTableExists = Schema::hasTable('wallet_accounts');

        Schema::table('wifi_networks', function (Blueprint $table) use ($placeAfterNotes, $walletAccountsTableExists) {
            $column = $table->foreignId('wallet_id')->nullable();

            if ($placeAfterNotes) {
                $column->after('notes');
            }

            if ($walletAccountsTableExists) {
                $column->constrained('wallet_accounts')->nullOnDelete();
            }
        });
    }

    public function down(): void
    {
        if (! Schema::hasTable('wifi_networks') || ! Schema::hasColumn('wifi_networks', 'wallet_id')) {
            return;
        }

        $foreignKeyName = DB::table('information_schema.KEY_COLUMN_USAGE')
            ->where('TABLE_SCHEMA', DB::getDatabaseName())
            ->where('TABLE_NAME', 'wifi_networks')
            ->where('COLUMN_NAME', 'wallet_id')
            ->whereNotNull('REFERENCED_TABLE_NAME')
            ->value('CONSTRAINT_NAME');

        if ($foreignKeyName) {
            Schema::table('wifi_networks', function (Blueprint $table) use ($foreignKeyName) {
                $table->dropForeign($foreignKeyName);
            });
        }

        Schema::table('wifi_networks', function (Blueprint $table) {
            $table->dropColumn('wallet_id');
        });
    }
};