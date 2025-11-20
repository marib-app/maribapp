<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('action_requests', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('kind', 32);
            $table->string('entity', 32)->nullable();
            $table->string('entity_id', 64)->nullable();
            $table->decimal('amount', 18, 2)->nullable();
            $table->string('currency', 3)->nullable();
            $table->string('status', 16)->default('pending');
            $table->timestamp('due_at')->nullable();
            $table->timestamp('expires_at')->nullable();
            $table->json('meta')->nullable();
            $table->string('hmac_token', 128);
            $table->timestamp('used_at')->nullable();
            $table->string('used_ip', 45)->nullable();
            $table->string('used_device', 128)->nullable();
            $table->timestamps();

            $table->index(['user_id', 'status', 'due_at']);
            $table->index(['entity', 'entity_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('action_requests');
    }
};
