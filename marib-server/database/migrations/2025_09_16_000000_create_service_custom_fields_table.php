<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('service_custom_fields', function (Blueprint $table) {
            $table->id();
            $table->foreignId('service_id')->constrained()->cascadeOnDelete();
            $table->string('name');
            $table->string('handle')->nullable();
            $table->string('type');
            $table->boolean('is_required')->default(false);
            $table->text('note')->nullable();
            $table->string('image')->nullable();
            $table->text('values')->nullable();
            $table->integer('min_length')->nullable();
            $table->integer('max_length')->nullable();
            $table->double('min_value')->nullable();
            $table->double('max_value')->nullable();
            $table->unsignedSmallInteger('sequence')->default(1);
            $table->boolean('status')->default(true);
            $table->json('meta')->nullable();
            $table->timestamps();

            $table->index(['service_id', 'sequence']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('service_custom_fields');
    }
};