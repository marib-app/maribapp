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
        Schema::create('stores', function (Blueprint $table) {
            $table->bigIncrements('id');
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('name');
            $table->text('description')->nullable();
            $table->string('slug')->unique();
            $table->string('status', 32)->default('pending')->index();
            $table->timestamp('status_changed_at')->nullable();
            $table->text('rejection_reason')->nullable();
            $table->string('financial_policy_type', 32)->default('commission');
            $table->json('financial_policy_payload')->nullable();
            $table->string('contact_email')->nullable();
            $table->string('contact_phone', 32)->nullable();
            $table->string('contact_whatsapp', 32)->nullable();
            $table->string('location_address')->nullable();
            $table->decimal('location_latitude', 10, 7)->nullable();
            $table->decimal('location_longitude', 10, 7)->nullable();
            $table->string('location_city')->nullable();
            $table->string('location_state')->nullable();
            $table->string('location_country', 2)->nullable();
            $table->text('location_notes')->nullable();
            $table->string('logo_path')->nullable();
            $table->string('banner_path')->nullable();
            $table->string('timezone', 64)->nullable();
            $table->timestamp('approved_at')->nullable();
            $table->foreignId('approved_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('suspended_at')->nullable();
            $table->foreignId('suspended_by')->nullable()->constrained('users')->nullOnDelete();
            $table->json('meta')->nullable();
            $table->softDeletes();
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('stores');
    }
};
