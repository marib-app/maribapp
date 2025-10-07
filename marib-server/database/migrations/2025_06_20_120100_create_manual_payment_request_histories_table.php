<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        Schema::create('manual_payment_request_histories', function (Blueprint $table) {
            $table->id();

            // أعمدة بدون constrained الافتراضي
            $table->unsignedBigInteger('manual_payment_request_id');
            $table->unsignedBigInteger('user_id')->nullable();

            $table->enum('status', ['pending', 'approved', 'rejected']);
            $table->text('note')->nullable();
            $table->json('meta')->nullable();
            $table->timestamps();

            // فهارس قصيرة
            $table->index('manual_payment_request_id', 'mprh_mpr_idx');
            $table->index('user_id', 'mprh_user_idx');

            // مفاتيح أجنبية بأسماء قصيرة
            $table->foreign('manual_payment_request_id', 'mprh_mpr_fk')
                  ->references('id')->on('manual_payment_requests')
                  ->cascadeOnDelete();

            $table->foreign('user_id', 'mprh_user_fk')
                  ->references('id')->on('users')
                  ->nullOnDelete();
        });
    }

    public function down(): void {
        Schema::dropIfExists('manual_payment_request_histories');
    }
};
