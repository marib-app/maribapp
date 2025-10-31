<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

return new class extends Migration {
    public function up(): void
    {
        // لا شيء نفعله إذا جدول الشبكات غير موجود
        if (! Schema::hasTable('wifi_networks')) {
            return;
        }

        // تأكيد وجود العمود wallet_id كـ NULLABLE بدون الحاجة لـ doctrine/dbal
        if (! Schema::hasColumn('wifi_networks', 'wallet_id')) {
            Schema::table('wifi_networks', function (Blueprint $table) {
                $table->unsignedBigInteger('wallet_id')->nullable()->index();
            });
        } else {
            // إجبار العمود أن يكون NULLABLE وأنواعه صحيحة
            DB::statement("ALTER TABLE `wifi_networks` MODIFY `wallet_id` BIGINT UNSIGNED NULL");
        }

        // إن لم يوجد جدول المحافظ حالياً، نتوقف (حتى لا نفشل). يمكن إعادة تشغيل الهجرات لاحقاً لإضافة الـFK.
        if (! Schema::hasTable('wallet_accounts')) {
            return;
        }

        // إسقاط أي FK حالي على wallet_id (إن وُجد)
        $existingFk = DB::table('information_schema.KEY_COLUMN_USAGE')
            ->select('CONSTRAINT_NAME', 'REFERENCED_TABLE_NAME')
            ->whereRaw('TABLE_SCHEMA = DATABASE()')
            ->where('TABLE_NAME', 'wifi_networks')
            ->where('COLUMN_NAME', 'wallet_id')
            ->whereNotNull('REFERENCED_TABLE_NAME')
            ->first();

        if ($existingFk) {
            // لو الاسم مختلف، نحذفه أولاً
            DB::statement(sprintf(
                "ALTER TABLE `wifi_networks` DROP FOREIGN KEY `%s`",
                $existingFk->CONSTRAINT_NAME
            ));
        }

        // لا نضيف القيد إن كان موجوداً بنفس الاسم (حماية إضافية)
        $fkExistsByName = DB::table('information_schema.REFERENTIAL_CONSTRAINTS')
            ->whereRaw('CONSTRAINT_SCHEMA = DATABASE()')
            ->where('CONSTRAINT_NAME', 'wifi_networks_wallet_id_foreign')
            ->exists();

        if (! $fkExistsByName) {
            // إضافة FK مضبوط
            DB::statement("
                ALTER TABLE `wifi_networks`
                ADD CONSTRAINT `wifi_networks_wallet_id_foreign`
                FOREIGN KEY (`wallet_id`) REFERENCES `wallet_accounts`(`id`) ON DELETE SET NULL
            ");
        }
    }

    public function down(): void
    {
        if (! Schema::hasTable('wifi_networks')) {
            return;
        }

        // إسقاط FK إن وُجد
        $fkExistsByName = DB::table('information_schema.REFERENTIAL_CONSTRAINTS')
            ->whereRaw('CONSTRAINT_SCHEMA = DATABASE()')
            ->where('CONSTRAINT_NAME', 'wifi_networks_wallet_id_foreign')
            ->exists();

        if ($fkExistsByName) {
            DB::statement("ALTER TABLE `wifi_networks` DROP FOREIGN KEY `wifi_networks_wallet_id_foreign`");
        }

        // لا نحذف العمود (اختياري). إن رغبت:
        // Schema::table('wifi_networks', function (Blueprint $table) {
        //     $table->dropColumn('wallet_id');
        // });
    }
};
