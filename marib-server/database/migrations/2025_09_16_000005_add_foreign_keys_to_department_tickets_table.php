<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('department_tickets', function (Blueprint $table) {
            $table->foreign('chat_conversation_id')
                ->references('id')
                ->on('chat_conversations')
                ->nullOnDelete();

            $table->foreign('order_id')
                ->references('id')
                ->on('orders')
                ->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('department_tickets', function (Blueprint $table) {
            $table->dropForeign(['chat_conversation_id']);
            $table->dropForeign(['order_id']);
        });
    }
};