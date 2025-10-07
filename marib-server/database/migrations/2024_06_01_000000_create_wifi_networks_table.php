<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('wifi_networks', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('name');
            $table->string('slug')->unique();


            $table->text('description')->nullable();
            $table->string('location_name')->nullable();
            $table->decimal('latitude', 10, 7)->nullable();
            $table->decimal('longitude', 10, 7)->nullable();
            $table->decimal('commission_rate', 5, 2)->default(0);
            $table->decimal('commission_flat', 10, 2)->default(0);
            $table->string('logo_path')->nullable();
            $table->string('login_screenshot_path')->nullable();
            $table->decimal('coverage_radius_km', 6, 2)->nullable();
            $table->json('contacts')->nullable();
            $table->text('notes')->nullable();
            $table->foreignId('wallet_id')->nullable()->constrained('wallet_accounts')->nullOnDelete();
            $table->boolean('is_active')->default(true);
            $table->json('meta')->nullable();
            $table->timestamps();

            $table->index(['is_active', 'latitude', 'longitude']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('wifi_networks');
    }
};