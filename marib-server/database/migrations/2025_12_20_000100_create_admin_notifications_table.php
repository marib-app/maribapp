<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        if (Schema::hasTable('admin_notifications')) {
            return;
        }

        Schema::create('admin_notifications', static function (Blueprint $table) {
            $table->id();
            $table->string('type', 100);
            $table->unsignedBigInteger('entity_id');
            $table->string('title');
            $table->string('status', 32)->default('pending');
            $table->string('link', 512)->nullable();
            $table->json('meta')->nullable();
            $table->timestamp('created_at')->useCurrent();
            $table->timestamp('admin_seen_at')->nullable();

            $table->unique(['type', 'entity_id']);
            $table->index('type');
            $table->index(['status', 'admin_seen_at']);
            $table->index(['type', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('admin_notifications');
    }
};