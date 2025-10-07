<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('department_tickets')) {
            Schema::create('department_tickets', function (Blueprint $table) {
                $table->id();
                $table->string('department')->index();
                $table->string('subject');
                $table->text('description')->nullable();
                $table->string('status')->default('open');
                $table->unsignedBigInteger('chat_conversation_id')->nullable();
                $table->unsignedBigInteger('order_id')->nullable();
                $table->foreignId('item_id')->nullable()->constrained('items')->nullOnDelete();
                $table->foreignId('reporter_id')->constrained('users')->cascadeOnDelete();
                $table->foreignId('assigned_to')->nullable()->constrained('users')->nullOnDelete();
                $table->timestamp('resolved_at')->nullable();
                $table->timestamps();
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('department_tickets');
    }
};