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
        Schema::create('delivery_prices', function (Blueprint $table) {
            $table->id();
            $table->string('size'); // Small, Medium, Large, etc.
            $table->decimal('min_distance', 10, 2); // Minimum distance in kilometers
            $table->decimal('max_distance', 10, 2); // Maximum distance in kilometers
            $table->decimal('price', 10, 2); // Price for this size and distance range
            $table->boolean('status')->default(true);
            $table->timestamps();
            $table->softDeletes();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('delivery_prices');
    }
}; 