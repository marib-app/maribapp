<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        // إسقاط أي FK قديم على wallet_id
        $fk = DB::table('information_schema.KEY_COLUMN_USAGE')
            ->select('CONSTRAINT_NAME')
            ->whereRaw('TABLE_SCHEMA = DATABASE()')
            ->where('TABLE_NAME','wifi_networks')
            ->where('COLUMN_NAME','wallet_id')
            ->whereNotNull('REFERENCED_TABLE_NAME')
            ->value('CONSTRAINT_NAME');

        if ($fk) {
            DB::unprepared("ALTER TABLE `wifi_networks` DROP FOREIGN KEY `{$fk}`");
        }

        Schema::table('wifi_networks', function (Blueprint $table) {
            $table->unsignedBigInteger('wallet_id')->nullable()->change();
        });

        DB::unprepared("ALTER TABLE `wifi_networks`
            ADD CONSTRAINT `wifi_networks_wallet_id_foreign`
            FOREIGN KEY (`wallet_id`) REFERENCES `wallet_accounts`(`id`) ON DELETE SET NULL");
    }

    public function down(): void {
        DB::unprepared("ALTER TABLE `wifi_networks` DROP FOREIGN KEY `wifi_networks_wallet_id_foreign`");
    }
};
