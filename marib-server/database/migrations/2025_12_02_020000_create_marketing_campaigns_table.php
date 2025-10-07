<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        Schema::create('marketing_campaigns', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->string('slug')->unique();
            $table->string('status')->default('draft');
            $table->string('trigger_type')->default('manual');
            $table->string('event_key')->nullable();
            $table->timestamp('scheduled_at')->nullable();
            $table->string('timezone')->nullable();
            $table->string('notification_title');
            $table->text('notification_body');
            $table->string('cta_label')->nullable();
            $table->string('cta_destination')->nullable();
            $table->json('metadata')->nullable();
            $table->timestamp('last_dispatched_at')->nullable();
            $table->timestamps();
            $table->softDeletes();
        });
    }

    public function down(): void {
        Schema::dropIfExists('marketing_campaigns');
    }
};