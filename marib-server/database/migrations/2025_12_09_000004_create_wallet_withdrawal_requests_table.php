<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('wallet_withdrawal_requests', static function (Blueprint $table) {
            $table->id();
            $table->foreignId('wallet_account_id')->constrained()->cascadeOnDelete();
            $table->foreignId('wallet_transaction_id')->constrained()->cascadeOnDelete();
            $table->foreignId('resolution_transaction_id')->nullable()->constrained('wallet_transactions')->nullOnDelete();
            $table->string('status');
            $table->decimal('amount', 18, 2);
            $table->string('preferred_method');
            $table->string('wallet_reference')->unique();
            $table->string('notes', 500)->nullable();
            $table->string('review_notes', 500)->nullable();
            $table->json('meta')->nullable();
            $table->foreignId('reviewed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('reviewed_at')->nullable();
            $table->timestamps();

            $table->index('status');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('wallet_withdrawal_requests');
    }
};