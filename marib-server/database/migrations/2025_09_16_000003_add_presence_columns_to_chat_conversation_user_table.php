<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('chat_conversation_user', function (Blueprint $table) {
            if (!Schema::hasColumn('chat_conversation_user', 'is_online')) {
                $table->boolean('is_online')->default(false)->after('user_id');
            }

            if (!Schema::hasColumn('chat_conversation_user', 'last_seen_at')) {
                $table->timestamp('last_seen_at')->nullable()->after('is_online');
            }

            if (!Schema::hasColumn('chat_conversation_user', 'is_typing')) {
                $table->boolean('is_typing')->default(false)->after('last_seen_at');
            }

            if (!Schema::hasColumn('chat_conversation_user', 'last_typing_at')) {
                $table->timestamp('last_typing_at')->nullable()->after('is_typing');
            }
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('chat_conversation_user', function (Blueprint $table) {
            if (Schema::hasColumn('chat_conversation_user', 'last_typing_at')) {
                $table->dropColumn('last_typing_at');
            }

            if (Schema::hasColumn('chat_conversation_user', 'is_typing')) {
                $table->dropColumn('is_typing');
            }

            if (Schema::hasColumn('chat_conversation_user', 'last_seen_at')) {
                $table->dropColumn('last_seen_at');
            }

            if (Schema::hasColumn('chat_conversation_user', 'is_online')) {
                $table->dropColumn('is_online');
            }
        });
    }
};