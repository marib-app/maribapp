<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('notification_preferences', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('type', 64);
            $table->boolean('enabled')->default(true);
            $table->boolean('sound')->default(true);
            $table->json('quiet_hours')->nullable();
            $table->string('frequency', 16)->default('instant');
            $table->string('channel', 32)->default('push');
            $table->timestamps();

            $table->unique(['user_id', 'type']);
            $table->index(['type', 'enabled']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('notification_preferences');
    }
};
