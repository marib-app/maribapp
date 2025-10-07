<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        Schema::create('services_custom_fields', function (Blueprint $table) {
            $table->id();
            $table->foreignId('service_id')->constrained()->cascadeOnDelete();
            $table->foreignId('custom_field_id')->constrained()->restrictOnDelete();
            $table->boolean('is_required')->default(false);
            $table->unsignedSmallInteger('sequence')->default(1);
            $table->timestamps();

            $table->unique(['service_id','custom_field_id']);
        });
    }

    public function down(): void {
        Schema::dropIfExists('services_custom_fields');
    }
};
