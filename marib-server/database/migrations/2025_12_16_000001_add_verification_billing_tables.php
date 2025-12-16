<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('verification_plans', static function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->enum('account_type', ['individual', 'commercial', 'realestate'])->default('individual');
            $table->integer('duration_days')->nullable(); // null = مفتوح
            $table->decimal('price', 10, 2)->default(0);
            $table->string('currency', 10)->default('SAR');
            $table->boolean('is_active')->default(true);
            $table->timestamps();
        });

        Schema::create('verification_payments', static function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('verification_request_id')->nullable()->constrained('verification_requests')->nullOnDelete();
            $table->foreignId('verification_plan_id')->nullable()->constrained('verification_plans')->nullOnDelete();
            $table->decimal('amount', 10, 2)->default(0);
            $table->string('currency', 10)->default('SAR');
            $table->string('status')->default('pending'); // pending/paid/failed/refunded
            $table->dateTime('starts_at')->nullable();
            $table->dateTime('expires_at')->nullable();
            $table->json('meta')->nullable();
            $table->timestamps();
        });

        Schema::table('verification_requests', static function (Blueprint $table) {
            $table->decimal('price', 10, 2)->nullable()->after('rejection_reason');
            $table->string('currency', 10)->nullable()->after('price');
            $table->integer('duration_days')->nullable()->after('currency');
            $table->dateTime('approved_at')->nullable()->after('duration_days');
            $table->dateTime('expires_at')->nullable()->after('approved_at');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('verification_requests', static function (Blueprint $table) {
            $table->dropColumn(['price', 'currency', 'duration_days', 'approved_at', 'expires_at']);
        });

        Schema::dropIfExists('verification_payments');
        Schema::dropIfExists('verification_plans');
    }
};
