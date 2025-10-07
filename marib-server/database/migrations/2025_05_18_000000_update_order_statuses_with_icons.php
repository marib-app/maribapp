<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasColumn('order_statuses', 'icon')) {
            Schema::table('order_statuses', function (Blueprint $table): void {
                $table->string('icon')->nullable()->after('color');
            });
        }

        if (! Schema::hasColumn('order_statuses', 'is_reserve')) {
            Schema::table('order_statuses', function (Blueprint $table): void {
                $table->boolean('is_reserve')->default(false)->after('is_active');
            });
        }

        $now = now();

        $statuses = [
            'processing' => [
                'name' => 'قيد المعالجة',
                'color' => '#2196F3',
                'icon' => 'bi bi-gear',
                'description' => 'الطلب قيد المعالجة',
                'is_default' => true,
                'is_active' => true,
                'is_reserve' => false,
                'sort_order' => 1,
            ],
            'confirmed' => [
                'name' => 'تم التأكيد',
                'color' => '#3F51B5',
                'icon' => 'bi bi-check2-square',
                'description' => 'تم تأكيد الطلب من قبل التاجر',
                'is_default' => false,
                'is_active' => true,
                'is_reserve' => false,
                'sort_order' => 2,
            ],
            'pending' => [
                'name' => 'قيد الانتظار',
                'color' => '#607D8B',
                'icon' => 'bi bi-hourglass-split',
                'description' => 'تم استلام الطلب وينتظر المعالجة',
                'is_default' => false,
                'is_active' => true,
                'is_reserve' => false,
                'sort_order' => 3,
            ],
            'preparing' => [
                'name' => 'جارٍ التحضير',
                'color' => '#FFC107',
                'icon' => 'bi bi-box-seam',
                'description' => 'يتم تجهيز الطلب للشحن',
                'is_default' => false,
                'is_active' => true,
                'is_reserve' => false,
                'sort_order' => 4,
            ],
            'ready_for_delivery' => [
                'name' => 'جاهز للتسليم',
                'color' => '#00BCD4',
                'icon' => 'bi bi-clipboard-check',
                'description' => 'الطلب جاهز للتسليم إلى شركة الشحن',
                'is_default' => false,
                'is_active' => true,
                'is_reserve' => false,
                'sort_order' => 5,
            ],
            'out_for_delivery' => [
                'name' => 'خرج للتسليم',
                'color' => '#9C27B0',
                'icon' => 'bi bi-truck',
                'description' => 'الطلب خرج للتسليم',
                'is_default' => false,
                'is_active' => true,
                'is_reserve' => false,
                'sort_order' => 6,
            ],
            'delivered' => [
                'name' => 'تم التسليم',
                'color' => '#4CAF50',
                'icon' => 'bi bi-check-circle',
                'description' => 'تم تسليم الطلب بنجاح',
                'is_default' => false,
                'is_active' => true,
                'is_reserve' => false,
                'sort_order' => 7,
            ],
            'returned' => [
                'name' => 'تم الإرجاع',
                'color' => '#795548',
                'icon' => 'bi bi-arrow-counterclockwise',
                'description' => 'تم إعادة الطلب إلى نقطة الاستلام أو المستودع',
                'is_default' => false,
                'is_active' => false,
                'is_reserve' => true,
                'sort_order' => 8,
            ],
            'failed' => [
                'name' => 'فشل التسليم',
                'color' => '#FF5722',
                'icon' => 'bi bi-exclamation-octagon',
                'description' => 'تعذر إتمام عملية التسليم',
                'is_default' => false,
                'is_active' => true,
                'is_reserve' => false,
                'sort_order' => 9,
            ],
            'canceled' => [
                'name' => 'ملغي',
                'color' => '#F44336',
                'icon' => 'bi bi-x-circle',
                'description' => 'تم إلغاء الطلب',
                'is_default' => false,
                'is_active' => true,
                'is_reserve' => false,
                'sort_order' => 10,
            ],
            'on_hold' => [
                'name' => 'معلّق مؤقتًا',
                'color' => '#9E9E9E',
                'icon' => 'bi bi-pause-circle',
                'description' => 'تم تعليق الطلب مؤقتًا لحل مشكلة أو انتظار تحديث إضافي',
                'is_default' => false,
                'is_active' => false,
                'is_reserve' => true,
                'sort_order' => 11,
            ],
        ];

        foreach ($statuses as $code => $attributes) {
            $existing = DB::table('order_statuses')->where('code', $code)->first();

            $payload = array_merge(
                $attributes,
                [
                    'code' => $code,
                    'updated_at' => $now,
                ]
            );

            if ($existing) {
                DB::table('order_statuses')
                    ->where('id', $existing->id)
                    ->update($payload);
            } else {
                DB::table('order_statuses')->insert(array_merge($payload, [
                    'created_at' => $now,
                ]));
            }
        }
    }

    public function down(): void
    {
        if (Schema::hasColumn('order_statuses', 'icon')) {
            Schema::table('order_statuses', function (Blueprint $table): void {
                $table->dropColumn('icon');
            });
        }

        if (Schema::hasColumn('order_statuses', 'is_reserve')) {
            Schema::table('order_statuses', function (Blueprint $table): void {
                $table->dropColumn('is_reserve');
            });
        }

        DB::table('order_statuses')->whereIn('code', ['on_hold', 'returned'])->delete();
    }
};