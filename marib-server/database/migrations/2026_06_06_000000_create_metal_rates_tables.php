<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('metal_rates', function (Blueprint $table) {
            $table->id();
            $table->string('metal_type');
            $table->decimal('karat', 5, 2)->nullable();
            $table->decimal('buy_price', 12, 3);
            $table->decimal('sell_price', 12, 3);
            $table->string('source')->nullable();
            $table->timestamp('quoted_at')->nullable();
            $table->timestamps();

            $table->index(['metal_type']);
            $table->index(['metal_type', 'karat']);
        });

        Schema::create('metal_rate_updates', function (Blueprint $table) {
            $table->id();
            $table->foreignId('metal_rate_id')->constrained('metal_rates')->cascadeOnDelete();
            $table->decimal('buy_price', 12, 3);
            $table->decimal('sell_price', 12, 3);
            $table->string('source')->nullable();
            $table->timestamp('scheduled_for');
            $table->string('status')->default('pending');
            $table->timestamp('applied_at')->nullable();
            $table->timestamp('cancelled_at')->nullable();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();

            $table->index(['metal_rate_id', 'status']);
            $table->index(['status', 'scheduled_for']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('metal_rate_updates');
        Schema::dropIfExists('metal_rates');
    }
};