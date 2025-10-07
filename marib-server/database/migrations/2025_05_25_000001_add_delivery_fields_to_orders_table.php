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
        Schema::table('orders', function (Blueprint $table) {
            $table->decimal('delivery_distance', 10, 2)->nullable()->after('notes');
            $table->string('delivery_size')->nullable()->after('delivery_distance');
            $table->decimal('delivery_price', 10, 2)->nullable()->after('delivery_size');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->dropColumn(['delivery_distance', 'delivery_size', 'delivery_price']);
        });
    }
}; 