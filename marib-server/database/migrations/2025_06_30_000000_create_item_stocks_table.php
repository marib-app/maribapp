<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('item_stocks', static function (Blueprint $table) {
            $table->id();
            $table->foreignId('item_id')->constrained('items')->cascadeOnDelete();
            $table->string('variant_key', 512)->default('');
            $table->unsignedInteger('stock')->default(0);
            $table->unsignedInteger('reserved_stock')->default(0);
            $table->timestamps();

            $table->unique(['item_id', 'variant_key']);
            $table->index(['variant_key']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('item_stocks');
    }
};