<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        Schema::table('services', function (Blueprint $table) {
            $table->json('service_fields_schema')->nullable()->after('has_custom_fields');
        });
    }
    public function down(): void {
        Schema::table('services', function (Blueprint $table) {
            $table->dropColumn('service_fields_schema');
        });
    }
};
