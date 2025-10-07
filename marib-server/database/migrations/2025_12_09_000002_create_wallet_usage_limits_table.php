<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('wallet_usage_limits', static function (Blueprint $table) {
            $table->id();
            $table->foreignId('wallet_account_id')->constrained()->cascadeOnDelete();
            $table->enum('period', ['daily', 'monthly']);
            $table->date('period_start');
            $table->decimal('total_credit', 18, 2)->default(0);
            $table->decimal('total_debit', 18, 2)->default(0);
            $table->timestamps();

            $table->unique(['wallet_account_id', 'period', 'period_start'], 'wallet_usage_limits_unique_period');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('wallet_usage_limits');
    }
};