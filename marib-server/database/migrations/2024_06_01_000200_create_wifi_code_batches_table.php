<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('wifi_code_batches', function (Blueprint $table) {
            $table->id();
            $table->foreignId('wifi_network_id')->constrained()->cascadeOnDelete();
            $table->foreignId('wifi_plan_id')->nullable()->constrained()->cascadeOnDelete();
            $table->foreignId('uploaded_by')->constrained('users')->cascadeOnDelete();
            $table->string('original_filename')->nullable();
            $table->unsignedInteger('total_rows')->default(0);
            $table->unsignedInteger('accepted_rows')->default(0);
            $table->unsignedInteger('rejected_rows')->default(0);
            $table->string('status')->default('pending');
            $table->timestamp('processed_at')->nullable();
            $table->json('meta')->nullable();
            $table->timestamps();

            $table->index(['wifi_network_id', 'wifi_plan_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('wifi_code_batches');
    }
};