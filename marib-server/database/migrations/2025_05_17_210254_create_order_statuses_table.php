<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('order_statuses', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->string('code')->unique();
            $table->string('color')->default('#000000');
            $table->text('description')->nullable();
            $table->boolean('is_default')->default(false);
            $table->boolean('is_active')->default(true);
            $table->integer('sort_order')->default(0);
            $table->timestamps();
        });

        // إضافة حالات افتراضية للطلبات
        DB::table('order_statuses')->insert([




            [
                'name' => 'قيد الانتظار',
                'code' => 'pending',
                'color' => '#607D8B',
                'description' => 'تم استلام الطلب وينتظر المعالجة',
                'is_default' => false,
                'is_active' => true,
                'sort_order' => 3,
                'created_at' => now(),
                'updated_at' => now(),
            ],
            [
                'name' => 'تم التأكيد',
                'code' => 'confirmed',
                'color' => '#3F51B5',
                'description' => 'تم تأكيد الطلب من قبل التاجر',
                'is_default' => false,
                'is_active' => true,
                'sort_order' => 2,
                'created_at' => now(),
                'updated_at' => now(),
            ],



            [
                'name' => 'قيد المعالجة',
                'code' => 'processing',
                'color' => '#2196F3',
                'description' => 'الطلب قيد المعالجة',
                'is_default' => true,
                'is_active' => true,
                'sort_order' => 1,
                'created_at' => now(),
                'updated_at' => now()
            ],
            [
                'name' => 'جارٍ التحضير',
                'code' => 'preparing',
                'color' => '#FFC107',
                'description' => 'الطلب جارٍ التحضير',
                'is_default' => false,
                'is_active' => true,
                'sort_order' => 4,
                'created_at' => now(),
                'updated_at' => now(),


            ],
            [




                
            ],
            [
                'name' => 'جاهز للتسليم',
                'code' => 'ready_for_delivery',
                'color' => '#00BCD4',
                'description' => 'الطلب جاهز للتسليم إلى شركة الشحن',
                'is_default' => false,
                'is_active' => true,
                'sort_order' => 5,
                'created_at' => now(),
                'updated_at' => now(),


                'name' => 'خرج للتسليم',
                'code' => 'out_for_delivery',
                'color' => '#9C27B0',
                'description' => 'الطلب خرج للتسليم',
                'is_default' => false,
                'is_active' => true,
                'sort_order' => 6,
                'created_at' => now(),
                'updated_at' => now(),
            ],
            [
                'name' => 'تم التسليم',
                'code' => 'delivered',
                'color' => '#4CAF50',
                'description' => 'تم تسليم الطلب',
                'is_default' => false,
                'is_active' => true,
                'sort_order' => 7,
                'created_at' => now(),
                'updated_at' => now(),
            ],
            [
                'name' => 'فشل التسليم',
                'code' => 'failed',
                'color' => '#FF5722',
                'description' => 'فشل تسليم الطلب',
                'is_default' => false,
                'is_active' => true,
                'sort_order' => 8,
                'created_at' => now(),
                'updated_at' => now(),
            ],
            [
                'name' => 'ملغي',
                'code' => 'canceled',
                'color' => '#F44336',
                'description' => 'تم إلغاء الطلب',
                'is_default' => false,
                'is_active' => true,
                'sort_order' => 9,
                'created_at' => now(),
                'updated_at' => now(),
            ],
        ]);
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('order_statuses');
    }
};
