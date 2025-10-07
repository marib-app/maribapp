<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Spatie\Permission\Models\Permission;

class ComputerManagementPermissionSeeder extends Seeder
{
    /**
     * Run the database seeds.
     *
     * @return void
     */
    public function run()
    {
        // إنشاء صلاحيات إدارة الكمبيوتر
        $computerPermissions = [
            'computer-ads'      => '*', // إعلانات الكمبيوتر - جميع الصلاحيات
            'computer-requests' => '*', // طلبات الكمبيوتر - جميع الصلاحيات
        ];

        $permissionsList = $this->generatePermissionList($computerPermissions);

        $permissions = array_map(static function ($data) {
            return [
                'name'       => $data,
                'guard_name' => 'web'
            ];
        }, $permissionsList);
        
        Permission::upsert($permissions, ['name'], ['name']);
    }

    /**
     * Generate permission list based on configuration
     *
     * @param array $permissions
     * @return array
     */
    private function generatePermissionList($permissions)
    {
        $permissionList = [];
        foreach ($permissions as $name => $permission) {
            $defaultPermission = [
                $name . "-list",
                $name . "-create",
                $name . "-update",
                $name . "-delete"
            ];
            
            if (is_array($permission)) {
                // * OR only param either is required
                if (in_array("*", $permission, true)) {
                    $permissionList = array_merge($permissionList ?? [], $defaultPermission);
                } else if (array_key_exists("only", $permission)) {
                    foreach ($permission["only"] as $row) {
                        $permissionList[] = $name . "-" . strtolower($row);
                    }
                }

                if (array_key_exists("custom", $permission)) {
                    foreach ($permission["custom"] as $customPermission) {
                        $permissionList[] = $name . "-" . $customPermission;
                    }
                }
            } else {
                $permissionList = array_merge($permissionList ?? [], $defaultPermission);
            }
        }
        return $permissionList;
    }
}