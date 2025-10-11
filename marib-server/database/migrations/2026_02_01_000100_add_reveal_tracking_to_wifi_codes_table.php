<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('wifi_codes', function (Blueprint $table) {
            if (!Schema::hasColumn('wifi_codes', 'revealed_at')) {
                $table->timestamp('revealed_at')->nullable()->after('allocated_at');
            }
            if (!Schema::hasColumn('wifi_codes', 'reveal_count')) {
                $table->unsignedInteger('reveal_count')->default(0)->after('revealed_at');
            }
        });

        if (!Schema::hasTable('wifi_code_reveal_logs')) {
            Schema::create('wifi_code_reveal_logs', function (Blueprint $table) {
                $table->id();
                $table->foreignId('wifi_code_id')->constrained('wifi_codes')->cascadeOnDelete();
                $table->foreignId('user_id')->constrained()->cascadeOnDelete();
                $table->string('action', 50);
                $table->string('ip_address', 45)->nullable();
                $table->string('user_agent')->nullable();
                $table->json('meta')->nullable();
                $table->timestamps();
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasTable('wifi_code_reveal_logs')) {
            Schema::dropIfExists('wifi_code_reveal_logs');
        }

        Schema::table('wifi_codes', function (Blueprint $table) {
            if (Schema::hasColumn('wifi_codes', 'reveal_count')) {
                $table->dropColumn('reveal_count');
            }
            if (Schema::hasColumn('wifi_codes', 'revealed_at')) {
                $table->dropColumn('revealed_at');
            }
        });
    }
};