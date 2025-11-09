<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('wifi_codes', static function (Blueprint $table): void {
            if (! Schema::hasColumn('wifi_codes', 'code_encrypted')) {
                $table->text('code_encrypted')->nullable();
            }
            if (! Schema::hasColumn('wifi_codes', 'code_suffix')) {
                $table->string('code_suffix', 32)->nullable();
            }
            if (! Schema::hasColumn('wifi_codes', 'code_hash')) {
                $table->string('code_hash', 128)->nullable()->unique();
            }
            if (! Schema::hasColumn('wifi_codes', 'username_encrypted')) {
                $table->text('username_encrypted')->nullable();
            }
            if (! Schema::hasColumn('wifi_codes', 'password_encrypted')) {
                $table->text('password_encrypted')->nullable();
            }
            if (! Schema::hasColumn('wifi_codes', 'serial_no_encrypted')) {
                $table->text('serial_no_encrypted')->nullable();
            }
            if (! Schema::hasColumn('wifi_codes', 'expiry_date')) {
                $table->date('expiry_date')->nullable();
            }
            if (! Schema::hasColumn('wifi_codes', 'meta')) {
                $table->json('meta')->nullable();
            }
        });
    }

    public function down(): void
    {
        Schema::table('wifi_codes', static function (Blueprint $table): void {
            foreach ([
                'meta',
                'expiry_date',
                'serial_no_encrypted',
                'password_encrypted',
                'username_encrypted',
                'code_hash',
                'code_suffix',
                'code_encrypted',
            ] as $column) {
                if (Schema::hasColumn('wifi_codes', $column)) {
                    if ($column === 'code_hash') {
                        $table->dropUnique('wifi_codes_code_hash_unique');
                    }
                    $table->dropColumn($column);
                }
            }
        });
    }
};
