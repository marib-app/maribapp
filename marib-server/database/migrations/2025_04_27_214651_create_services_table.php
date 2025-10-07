<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('services', function (Blueprint $table) {
      
            $table->id();
            $table->foreignId('category_id')->references('id')->on('categories')->onDelete('restrict');
            $table->string('title', 512);
            $table->text('description')->nullable();
            $table->string('image', 512);
            $table->string('icon', 512)->nullable();
            $table->boolean('status')->default(true);
            $table->boolean('is_main')->default(false);
            $table->string('service_type')->nullable();
            $table->string('tags')->nullable();
            $table->integer('views')->default(0);
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('services');
    }
};
