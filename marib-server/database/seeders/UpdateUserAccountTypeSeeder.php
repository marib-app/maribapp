<?php

namespace Database\Seeders;

use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;
use App\Models\User;
use Illuminate\Support\Facades\DB;

class UpdateUserAccountTypeSeeder extends Seeder
{
    /**
     * تشغيل عملية البذر.
     */
    public function run(): void
    {
        // تحديث المستخدمين الذين لديهم حقل seller_id في جدول الطلبات ليكونوا تجار (account_type = 2)
        $sellerIds = DB::table('orders')
            ->whereNotNull('seller_id')
            ->distinct()
            ->pluck('seller_id');

        if ($sellerIds->count() > 0) {
            User::whereIn('id', $sellerIds)
                ->update(['account_type' => 2]); // تعيين كتجار (sellers)
            
            $this->command->info('تم تحديث ' . $sellerIds->count() . ' مستخدم كتجار.');
        }

        // تحديث المستخدمين الذين لديهم طلبات كعملاء (account_type = 1)
        $customerIds = DB::table('orders')
            ->whereNotNull('user_id')
            ->distinct()
            ->pluck('user_id');

        if ($customerIds->count() > 0) {
            User::whereIn('id', $customerIds)
                ->whereNull('account_type') // تحديث فقط المستخدمين الذين لم يتم تعيينهم كتجار
                ->update(['account_type' => 1]); // تعيين كعملاء (customers)
            
            $this->command->info('تم تحديث ' . $customerIds->count() . ' مستخدم كعملاء.');
        }

        // يمكن إضافة منطق إضافي لتعيين المستخدمين الآخرين حسب الحاجة
    }
}
