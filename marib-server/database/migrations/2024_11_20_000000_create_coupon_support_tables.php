<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('coupons')) {
            Schema::create('coupons', function (Blueprint $table) {
                $table->id();
                $table->string('code')->unique();
                $table->string('name')->nullable();
                $table->text('description')->nullable();
                $table->enum('discount_type', ['fixed', 'percentage'])->default('fixed');
                $table->decimal('discount_value', 12, 2);
                $table->decimal('minimum_order_amount', 12, 2)->nullable();
                $table->unsignedInteger('max_uses')->nullable();
                $table->unsignedInteger('max_uses_per_user')->nullable();
                $table->timestamp('starts_at')->nullable();
                $table->timestamp('ends_at')->nullable();
                $table->json('metadata')->nullable();
                $table->boolean('is_active')->default(true);
                $table->timestamps();
                $table->softDeletes();
            });
        } else {
            Schema::table('coupons', function (Blueprint $table) {
                if (! Schema::hasColumn('coupons', 'minimum_order_amount')) {
                    $table->decimal('minimum_order_amount', 12, 2)->nullable()->after('discount_value');
                }

                if (! Schema::hasColumn('coupons', 'max_uses')) {
                    $table->unsignedInteger('max_uses')->nullable()->after('minimum_order_amount');
                }

                if (! Schema::hasColumn('coupons', 'max_uses_per_user')) {
                    $table->unsignedInteger('max_uses_per_user')->nullable()->after('max_uses');
                }

                if (! Schema::hasColumn('coupons', 'starts_at')) {
                    $table->timestamp('starts_at')->nullable()->after('max_uses_per_user');
                }

                if (! Schema::hasColumn('coupons', 'ends_at')) {
                    $table->timestamp('ends_at')->nullable()->after('starts_at');
                }

                if (! Schema::hasColumn('coupons', 'metadata')) {
                    $table->json('metadata')->nullable()->after('ends_at');
                }

                if (! Schema::hasColumn('coupons', 'is_active')) {
                    $table->boolean('is_active')->default(true)->after('metadata');
                }
            });
        }

        if (! Schema::hasTable('coupon_usages')) {
            Schema::create('coupon_usages', function (Blueprint $table) {
                $table->id();
                $table->foreignId('coupon_id')->constrained()->cascadeOnDelete();
                $table->foreignId('user_id')->constrained()->cascadeOnDelete();
                $table->foreignId('order_id')->nullable()->constrained()->nullOnDelete();
                $table->timestamp('used_at')->useCurrent();
                $table->timestamps();

                $table->index(['coupon_id', 'user_id']);
            });
        }

        if (! Schema::hasTable('cart_coupon_selections')) {
            Schema::create('cart_coupon_selections', function (Blueprint $table) {
                $table->id();
                $table->foreignId('user_id')->constrained()->cascadeOnDelete();
                $table->foreignId('coupon_id')->constrained()->cascadeOnDelete();
                $table->string('department')->nullable();
                $table->timestamp('applied_at')->nullable();
                $table->json('metadata')->nullable();
                $table->timestamps();

                $table->unique('user_id');
                $table->index(['coupon_id', 'department']);
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('cart_coupon_selections');
        Schema::dropIfExists('coupon_usages');

        Schema::dropIfExists('coupons');
    }
};