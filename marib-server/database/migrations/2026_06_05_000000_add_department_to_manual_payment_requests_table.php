<?php

use App\Models\ManualPaymentRequest;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('manual_payment_requests')) {
            return;
        }

        // 1) إضافة العمود بشكل آمن (بدون AFTER إذا currency غير موجود)
        if (! Schema::hasColumn('manual_payment_requests', 'department')) {
            Schema::table('manual_payment_requests', function (Blueprint $table) {
                if (Schema::hasColumn('manual_payment_requests', 'currency')) {
                    $table->string('department')->nullable()->after('currency');
                } else {
                    $table->string('department')->nullable();
                }
            });

            // أنشئ فهرس باسم ثابت لتجنُّب التضارب
            try {
                DB::statement('ALTER TABLE `manual_payment_requests` ADD INDEX `mpr_department_idx` (`department`)');
            } catch (\Throwable $e) {
                // إذا كان موجودًا باسم افتراضي تجاهل
            }
        }

        // لا تعبئة بدون العمود أو بدون جدول الطلبات
        if (! Schema::hasColumn('manual_payment_requests', 'department') || ! Schema::hasTable('orders')) {
            return;
        }

        // 2) تطبيع payable_type المستهدَف (الطلبات) + تعبئة department من orders
        $trimChars = " \t\n\r\0\x0B\"'";
        $tokens = [];

        if (method_exists(ManualPaymentRequest::class, 'orderPayableTypeTokens')) {
            $tokens = collect(ManualPaymentRequest::orderPayableTypeTokens())
                ->map(fn ($t) => strtolower(trim((string) $t, $trimChars)))
                ->filter(fn ($t) => $t !== '')
                ->unique()
                ->values()
                ->all();
        }

        // احتياط: صيغ شائعة إن لم تتوفر الدالة في الموديل
        if (empty($tokens)) {
            $tokens = ['app\\models\\order', 'order'];
        }

        DB::table('manual_payment_requests')
            ->select(['id', 'payable_type', 'payable_id'])
            ->whereNull('department')
            ->whereNotNull('payable_id')
            ->orderBy('id')
            ->chunkById(200, function ($rows) use ($tokens, $trimChars) {
                // اجمع معرفات الطلبات المستهدفة
                $orderIds = collect($rows)
                    ->filter(function ($row) use ($tokens, $trimChars) {
                        if (! is_string($row->payable_type)) return false;
                        $norm = strtolower(trim($row->payable_type, $trimChars));
                        return $norm !== '' && in_array($norm, $tokens, true);
                    })
                    ->pluck('payable_id')
                    ->filter()
                    ->unique()
                    ->values()
                    ->all();

                if ($orderIds === []) {
                    return;
                }

                $departments = DB::table('orders')
                    ->whereIn('id', $orderIds)
                    ->pluck('department', 'id');

                foreach ($rows as $row) {
                    if (! is_string($row->payable_type)) continue;
                    $norm = strtolower(trim($row->payable_type, $trimChars));
                    if ($norm === '' || ! in_array($norm, $tokens, true)) continue;

                    $dept = $departments[$row->payable_id] ?? null;
                    if (! is_string($dept) || trim($dept) === '') continue;

                    DB::table('manual_payment_requests')
                        ->where('id', $row->id)
                        ->update(['department' => $dept]);
                }
            });
    }

    public function down(): void
    {
        if (! Schema::hasTable('manual_payment_requests') || ! Schema::hasColumn('manual_payment_requests', 'department')) {
            return;
        }

        // احذف أي فهرس على العمود (سواء الاسم ثابت أو الافتراضي)
        try {
            DB::statement('ALTER TABLE `manual_payment_requests` DROP INDEX `mpr_department_idx`');
        } catch (\Throwable $e) {
            // تجاهل إن لم يوجد
        }

        try {
            // الاسم الافتراضي الذي يولّده Laravel
            DB::statement('ALTER TABLE `manual_payment_requests` DROP INDEX `manual_payment_requests_department_index`');
        } catch (\Throwable $e) {
            // تجاهل إن لم يوجد
        }

        Schema::table('manual_payment_requests', function (Blueprint $table) {
            $table->dropColumn('department');
        });
    }
};
