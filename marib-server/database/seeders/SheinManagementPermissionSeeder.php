<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Spatie\Permission\Models\Permission;

class SheinManagementPermissionSeeder extends Seeder
{
    /**
     * Run the database seeds.
     *
     * @return void
     */
    public function run()
    {
        // قائمة صلاحيات إدارة شي ان
        $permissionsList = [
            'shein-products' => ['list', 'create', 'update', 'delete'],
            'shein-orders' => ['list', 'create', 'update', 'delete']
        ];

        // إنشاء الصلاحيات
        foreach ($permissionsList as $module => $actions) {
            foreach ($actions as $action) {
                $permissionName = $module . '-' . $action;
                
                // التحقق من وجود الصلاحية قبل إنشائها
                if (!Permission::where('name', $permissionName)->exists()) {
                    Permission::create([
                        'name' => $permissionName,
                        'guard_name' => 'web'
                    ]);
                    
                    $this->command->info("تم إنشاء الصلاحية: {$permissionName}");
                } else {
                    $this->command->info("الصلاحية موجودة مسبقاً: {$permissionName}");
                }
            }
        }

        $this->command->info('تم إنشاء جميع صلاحيات إدارة شي ان بنجاح!');
    }
}