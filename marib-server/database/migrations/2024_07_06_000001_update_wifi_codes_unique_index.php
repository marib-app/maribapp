<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('wifi_codes', function (Blueprint $table) {
            $table->index('wifi_network_id');
            $table->dropUnique('wifi_codes_wifi_network_id_code_hash_unique');
            $table->unique('code_hash');
        });
    }

    public function down(): void
    {
        Schema::table('wifi_codes', function (Blueprint $table) {
            $table->dropUnique('wifi_codes_code_hash_unique');
            $table->unique(['wifi_network_id', 'code_hash']);
            $table->dropIndex('wifi_codes_wifi_network_id_index');
        });
    }
};