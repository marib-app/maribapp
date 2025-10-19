<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('metal_rates', function (Blueprint $table) {
            $table->string('icon_path')->nullable()->after('source');
            $table->string('icon_alt')->nullable()->after('icon_path');
            $table->foreignId('icon_uploaded_by')->nullable()->after('icon_alt')->constrained('users')->nullOnDelete();
            $table->timestamp('icon_uploaded_at')->nullable()->after('icon_uploaded_by');
            $table->foreignId('icon_removed_by')->nullable()->after('icon_uploaded_at')->constrained('users')->nullOnDelete();
            $table->timestamp('icon_removed_at')->nullable()->after('icon_removed_by');
        });
    }

    public function down(): void
    {
        Schema::table('metal_rates', function (Blueprint $table) {
            $table->dropColumn(['icon_removed_at']);
            $table->dropConstrainedForeignId('icon_removed_by');
            $table->dropColumn(['icon_uploaded_at']);
            $table->dropConstrainedForeignId('icon_uploaded_by');
            $table->dropColumn(['icon_alt']);
            $table->dropColumn(['icon_path']);
        });
    }
};