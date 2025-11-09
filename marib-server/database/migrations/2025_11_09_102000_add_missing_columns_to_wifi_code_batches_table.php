<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('wifi_code_batches', static function (Blueprint $table): void {
            if (! Schema::hasColumn('wifi_code_batches', 'label')) {
                $table->string('label')->nullable();
            }

            if (! Schema::hasColumn('wifi_code_batches', 'source_filename')) {
                $table->string('source_filename')->nullable();
            }

            if (! Schema::hasColumn('wifi_code_batches', 'checksum')) {
                $table->string('checksum', 64)->nullable()->index();
            }

            if (! Schema::hasColumn('wifi_code_batches', 'status')) {
                $table->string('status')->nullable()->index();
            }

            if (! Schema::hasColumn('wifi_code_batches', 'total_codes')) {
                $table->unsignedInteger('total_codes')->default(0);
            }

            if (! Schema::hasColumn('wifi_code_batches', 'available_codes')) {
                $table->unsignedInteger('available_codes')->default(0);
            }

            if (! Schema::hasColumn('wifi_code_batches', 'notes')) {
                $table->text('notes')->nullable();
            }

            if (! Schema::hasColumn('wifi_code_batches', 'meta')) {
                $table->json('meta')->nullable();
            }
        });
    }

    public function down(): void
    {
        Schema::table('wifi_code_batches', static function (Blueprint $table): void {
            foreach (['meta', 'notes', 'available_codes', 'total_codes', 'status', 'checksum', 'source_filename', 'label'] as $column) {
                if (Schema::hasColumn('wifi_code_batches', $column)) {
                    $table->dropColumn($column);
                }
            }
        });
    }
};
