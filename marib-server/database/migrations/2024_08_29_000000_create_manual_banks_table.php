<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        Schema::create('manual_banks', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->string('logo_path')->nullable();
            $table->string('beneficiary_name')->nullable();
            $table->text('note')->nullable();
            $table->unsignedInteger('display_order')->default(0);
            $table->boolean('status')->default(false);
            $table->timestamps();
        });
    }

    public function down(): void {
        Schema::dropIfExists('manual_banks');
    }
};