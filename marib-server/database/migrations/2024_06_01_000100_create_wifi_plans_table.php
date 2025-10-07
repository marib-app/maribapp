<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('wifi_plans', function (Blueprint $table) {
            $table->id();
            $table->foreignId('wifi_network_id')->constrained()->cascadeOnDelete();
            $table->string('name');
            $table->text('description')->nullable();
            $table->unsignedInteger('duration_minutes');
            $table->unsignedInteger('data_allowance_mb')->nullable();
            $table->unsignedInteger('validity_days')->nullable();
            $table->decimal('speed_mbps', 8, 2)->nullable();
            $table->decimal('price', 10, 2);
            $table->string('currency', 3)->default('SAR');
            $table->decimal('commission_rate_override', 5, 2)->nullable();
            $table->boolean('is_active')->default(true);
            $table->json('meta')->nullable();
            $table->timestamps();

            $table->index(['wifi_network_id', 'is_active']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('wifi_plans');
    }
};