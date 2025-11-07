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
        Schema::create('store_settings', function (Blueprint $table) {
            $table->bigIncrements('id');
            $table->foreignId('store_id')->unique()->constrained('stores')->cascadeOnDelete();
            $table->string('closure_mode', 32)->default('full'); // full | browse_only
            $table->boolean('is_manually_closed')->default(false);
            $table->string('manual_closure_reason')->nullable();
            $table->timestamp('manual_closure_expires_at')->nullable();
            $table->decimal('min_order_amount', 12, 2)->nullable();
            $table->boolean('allow_pickup')->default(true);
            $table->boolean('allow_delivery')->default(true);
            $table->boolean('allow_manual_payments')->default(true);
            $table->boolean('allow_wallet')->default(false);
            $table->boolean('allow_cod')->default(false);
            $table->boolean('auto_accept_orders')->default(true);
            $table->unsignedSmallInteger('order_acceptance_buffer_minutes')->default(15);
            $table->decimal('delivery_radius_km', 8, 2)->nullable();
            $table->text('checkout_notice')->nullable();
            $table->json('preferences')->nullable();
            $table->timestamps();
        });

        Schema::create('store_working_hours', function (Blueprint $table) {
            $table->bigIncrements('id');
            $table->foreignId('store_id')->constrained('stores')->cascadeOnDelete();
            $table->unsignedTinyInteger('weekday');
            $table->boolean('is_open')->default(false);
            $table->time('opens_at')->nullable();
            $table->time('closes_at')->nullable();
            $table->timestamps();

            $table->unique(['store_id', 'weekday']);
        });

        Schema::create('store_policies', function (Blueprint $table) {
            $table->bigIncrements('id');
            $table->foreignId('store_id')->constrained('stores')->cascadeOnDelete();
            $table->string('policy_type', 32);
            $table->string('title')->nullable();
            $table->text('content');
            $table->boolean('is_required')->default(true);
            $table->boolean('is_active')->default(true);
            $table->unsignedSmallInteger('display_order')->default(0);
            $table->timestamps();

            $table->unique(['store_id', 'policy_type']);
        });

        Schema::create('store_staff', function (Blueprint $table) {
            $table->bigIncrements('id');
            $table->foreignId('store_id')->constrained('stores')->cascadeOnDelete();
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();
            $table->string('email')->index();
            $table->string('role', 32)->default('staff');
            $table->string('status', 32)->default('pending');
            $table->json('permissions')->nullable();
            $table->string('invitation_token', 64)->nullable()->unique();
            $table->foreignId('invited_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('accepted_at')->nullable();
            $table->timestamp('revoked_at')->nullable();
            $table->timestamps();

            $table->unique(['store_id', 'email']);
        });

        Schema::create('store_status_logs', function (Blueprint $table) {
            $table->bigIncrements('id');
            $table->foreignId('store_id')->constrained('stores')->cascadeOnDelete();
            $table->string('status', 32);
            $table->text('reason')->nullable();
            $table->json('context')->nullable();
            $table->foreignId('changed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
        });

        Schema::create('store_daily_metrics', function (Blueprint $table) {
            $table->bigIncrements('id');
            $table->foreignId('store_id')->constrained('stores')->cascadeOnDelete();
            $table->date('metric_date');
            $table->unsignedInteger('visits')->default(0);
            $table->unsignedInteger('product_views')->default(0);
            $table->unsignedInteger('add_to_cart')->default(0);
            $table->unsignedInteger('orders')->default(0);
            $table->decimal('revenue', 14, 2)->default(0);
            $table->decimal('conversion_rate', 6, 4)->default(0);
            $table->json('payload')->nullable();
            $table->timestamps();

            $table->unique(['store_id', 'metric_date']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('store_daily_metrics');
        Schema::dropIfExists('store_status_logs');
        Schema::dropIfExists('store_staff');
        Schema::dropIfExists('store_policies');
        Schema::dropIfExists('store_working_hours');
        Schema::dropIfExists('store_settings');
    }
};
