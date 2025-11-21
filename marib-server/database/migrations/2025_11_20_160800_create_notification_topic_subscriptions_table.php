<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('notification_topic_subscriptions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('topic', 64);
            $table->timestamps();

            $table->unique(['user_id', 'topic']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('notification_topic_subscriptions');
    }
};
