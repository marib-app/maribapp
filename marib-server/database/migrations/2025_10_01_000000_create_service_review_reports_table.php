<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('service_review_reports', function (Blueprint $table) {
            $table->id();
            $table->foreignId('service_review_id')->constrained('service_reviews')->cascadeOnDelete();
            $table->foreignId('reporter_id')->constrained('users')->cascadeOnDelete();
            $table->string('reason')->nullable();
            $table->text('message')->nullable();
            $table->string('status')->default('pending');
            $table->timestamps();

            $table->unique(['service_review_id', 'reporter_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('service_review_reports');
    }
};