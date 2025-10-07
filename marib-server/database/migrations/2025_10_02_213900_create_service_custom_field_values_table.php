<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('service_custom_field_values', function (Blueprint $table) {
            $table->id();
            $table->foreignId('service_id')->constrained('services')->cascadeOnDelete();
            $table->foreignId('service_custom_field_id')->constrained('service_custom_fields')->cascadeOnDelete();
            $table->text('value')->nullable();
            $table->timestamps();
            $table->unique(['service_id', 'service_custom_field_id'], 'svc_field_values_unique');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('service_custom_field_values');
    }
};