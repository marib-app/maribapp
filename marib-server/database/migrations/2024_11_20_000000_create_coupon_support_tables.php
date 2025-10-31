<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    private function fkExists(string $table, string $fk): bool
    {
        $db = DB::getDatabaseName();
        return (bool) DB::selectOne(
            "SELECT 1 FROM information_schema.TABLE_CONSTRAINTS
             WHERE CONSTRAINT_SCHEMA=? AND TABLE_NAME=? AND CONSTRAINT_NAME=? AND CONSTRAINT_TYPE='FOREIGN KEY' LIMIT 1",
            [$db, $table, $fk]
        );
    }

    public function up(): void
    {
        /** coupons */
        if (!Schema::hasTable('coupons')) {
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
                if (!Schema::hasColumn('coupons', 'minimum_order_amount')) $table->decimal('minimum_order_amount', 12, 2)->nullable();
                if (!Schema::hasColumn('coupons', 'max_uses')) $table->unsignedInteger('max_uses')->nullable();
                if (!Schema::hasColumn('coupons', 'max_uses_per_user')) $table->unsignedInteger('max_uses_per_user')->nullable();
                if (!Schema::hasColumn('coupons', 'starts_at')) $table->timestamp('starts_at')->nullable();
                if (!Schema::hasColumn('coupons', 'ends_at')) $table->timestamp('ends_at')->nullable();
                if (!Schema::hasColumn('coupons', 'metadata')) $table->json('metadata')->nullable();
                if (!Schema::hasColumn('coupons', 'is_active')) $table->boolean('is_active')->default(true);
            });
        }

        /** coupon_usages */
        if (!Schema::hasTable('coupon_usages')) {
            Schema::create('coupon_usages', function (Blueprint $table) {
                $table->id();
                $table->foreignId('coupon_id')->constrained()->cascadeOnDelete();
                $table->foreignId('user_id')->constrained()->cascadeOnDelete();
                // لا تضف FK الآن لأن orders قد لا تكون موجودة بعد
                $table->unsignedBigInteger('order_id')->nullable()->index();
                $table->timestamp('used_at')->useCurrent();
                $table->timestamps();
                $table->index(['coupon_id', 'user_id']);
            });
        } else {
            Schema::table('coupon_usages', function (Blueprint $table) {
                if (!Schema::hasColumn('coupon_usages', 'order_id')) {
                    $table->unsignedBigInteger('order_id')->nullable()->index();
                }
                // تأكد من FKs coupon_id/user_id لو غابت (أسماء Laravel الافتراضية)
                if (!app(self::class)->fkExists('coupon_usages', 'coupon_usages_coupon_id_foreign')) {
                    $table->foreign('coupon_id', 'coupon_usages_coupon_id_foreign')->references('id')->on('coupons')->cascadeOnDelete();
                }
                if (!app(self::class)->fkExists('coupon_usages', 'coupon_usages_user_id_foreign')) {
                    $table->foreign('user_id', 'coupon_usages_user_id_foreign')->references('id')->on('users')->cascadeOnDelete();
                }
            });
        }

        // أضِف FK لـ order_id فقط إذا كانت orders موجودة الآن ولم يُضف القيد مسبقًا
        if (Schema::hasTable('orders') && Schema::hasTable('coupon_usages')) {
            if (!$this->fkExists('coupon_usages', 'coupon_usages_order_id_foreign')) {
                Schema::table('coupon_usages', function (Blueprint $table) {
                    $table->foreign('order_id', 'coupon_usages_order_id_foreign')
                          ->references('id')->on('orders')
                          ->nullOnDelete();
                });
            }
        }

        /** cart_coupon_selections */
        if (!Schema::hasTable('cart_coupon_selections')) {
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
        if (Schema::hasTable('coupon_usages')) {
            // أسقط FK order_id إن وُجد
            if ($this->fkExists('coupon_usages', 'coupon_usages_order_id_foreign')) {
                Schema::table('coupon_usages', function (Blueprint $table) {
                    $table->dropForeign('coupon_usages_order_id_foreign');
                });
            }
        }
        Schema::dropIfExists('cart_coupon_selections');
        Schema::dropIfExists('coupon_usages');
        Schema::dropIfExists('coupons');
    }
};
