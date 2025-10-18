<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('currency_rate_change_logs', function (Blueprint $table) {
            $table->id();
            $table->foreignId('currency_rate_id')->constrained()->cascadeOnDelete();
            $table->foreignId('governorate_id')->nullable()->constrained()->nullOnDelete();
            $table->string('change_type', 20);
            $table->json('previous_values')->nullable();
            $table->json('new_values')->nullable();
            $table->foreignId('changed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('changed_at')->useCurrent();
            $table->timestamps();

            $table->index(['currency_rate_id', 'governorate_id']);
            $table->index('changed_at');
            $table->index('change_type');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('currency_rate_change_logs');
    }
};