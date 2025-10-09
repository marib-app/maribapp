<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('service_requests')) {
            return;
        }

        Schema::create('service_requests', static function (Blueprint $table): void {
            $table->id();
            $table->foreignId('service_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('status', 32)->default('review')->index();
            $table->string('payment_status', 32)->nullable()->index();
            $table->foreignId('payment_transaction_id')->nullable()->constrained()->nullOnDelete();
            $table->json('payload')->nullable();
            $table->text('note')->nullable();
            $table->text('rejected_reason')->nullable();
            $table->timestamps();
            $table->softDeletes();

            $table->index(['service_id', 'user_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('service_requests');
    }
};