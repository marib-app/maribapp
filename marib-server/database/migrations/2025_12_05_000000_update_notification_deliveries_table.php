<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('notification_deliveries', function (Blueprint $table) {
            if (!Schema::hasColumn('notification_deliveries', 'type')) {
                $table->string('type', 64)->default('generic')->after('user_id');
            }
            $table->string('fingerprint', 128)->nullable()->after('type');
            $table->string('collapse_key', 64)->nullable()->after('fingerprint');
            $table->string('deeplink')->nullable()->after('collapse_key');
            $table->string('priority', 16)->default('normal')->after('status');
            $table->unsignedInteger('ttl')->default(3600)->after('priority');
            $table->json('device')->nullable()->after('clicked_at');
            $table->json('payload')->nullable()->after('meta');
        });

        Schema::table('notification_deliveries', function (Blueprint $table) {
            $table->unique('fingerprint', 'notification_deliveries_fingerprint_unique');
            $table->index(['user_id', 'created_at'], 'notification_deliveries_user_created_at');
            $table->index('type', 'notification_deliveries_type_index');
        });

        DB::table('notification_deliveries')
            ->whereNull('type')
            ->update(['type' => 'generic']);
    }

    public function down(): void
    {
        Schema::table('notification_deliveries', function (Blueprint $table) {
            $table->dropUnique('notification_deliveries_fingerprint_unique');
            $table->dropIndex('notification_deliveries_user_created_at');
            $table->dropIndex('notification_deliveries_type_index');
            $table->dropColumn([
                'fingerprint',
                'collapse_key',
                'deeplink',
                'priority',
                'ttl',
                'device',
                'payload',
            ]);

            if (Schema::hasColumn('notification_deliveries', 'type')) {
                $table->dropColumn('type');
            }
        });
    }
};
