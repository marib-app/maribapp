<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('department_number_settings')) {
            return;
        }

        Schema::create('department_number_settings', function (Blueprint $table) {
            $table->id();
            $table->string('department');
            $table->boolean('legal_numbering_enabled')->default(false);
            $table->string('order_prefix')->nullable();
            $table->string('invoice_prefix')->nullable();
            $table->unsignedBigInteger('next_order_number')->default(1);
            $table->unsignedBigInteger('next_invoice_number')->default(1);
            $table->timestamps();

            $table->unique('department');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('department_number_settings');
    }
};