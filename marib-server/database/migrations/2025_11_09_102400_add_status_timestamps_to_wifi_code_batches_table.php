<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('wifi_code_batches', static function (Blueprint $table): void {
            if (! Schema::hasColumn('wifi_code_batches', 'validated_at')) {
                $table->timestamp('validated_at')->nullable();
            }

            if (! Schema::hasColumn('wifi_code_batches', 'activated_at')) {
                $table->timestamp('activated_at')->nullable();
            }
        });
    }

    public function down(): void
    {
        Schema::table('wifi_code_batches', static function (Blueprint $table): void {
            if (Schema::hasColumn('wifi_code_batches', 'activated_at')) {
                $table->dropColumn('activated_at');
            }

            if (Schema::hasColumn('wifi_code_batches', 'validated_at')) {
                $table->dropColumn('validated_at');
            }
        });
    }
};
