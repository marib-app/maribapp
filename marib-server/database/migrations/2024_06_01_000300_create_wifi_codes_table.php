<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('wifi_codes', function (Blueprint $table) {
            $table->id();
            $table->foreignId('wifi_network_id')->constrained()->cascadeOnDelete();
            $table->foreignId('wifi_plan_id')->nullable()->constrained()->cascadeOnDelete();
            $table->foreignId('wifi_code_batch_id')->constrained()->cascadeOnDelete();
            $table->string('code_encrypted');
            $table->string('code_hash');
            $table->string('username_encrypted')->nullable();
            $table->string('password_encrypted')->nullable();
            $table->timestamp('expires_at')->nullable();
            $table->string('status')->default('available');
            $table->foreignId('allocated_to_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('allocated_at')->nullable();
            $table->json('meta')->nullable();
            $table->timestamps();

            $table->unique(['wifi_network_id', 'code_hash']);
            $table->index(['wifi_plan_id', 'status', 'expires_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('wifi_codes');
    }
};