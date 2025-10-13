<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Spatie\Permission\Models\Permission;

class MetalRatePermissionSeeder extends Seeder
{
    public function run(): void
    {
        $permissions = [
            ['name' => 'metal-rate-list', 'guard_name' => 'web'],
            ['name' => 'metal-rate-create', 'guard_name' => 'web'],
            ['name' => 'metal-rate-edit', 'guard_name' => 'web'],
            ['name' => 'metal-rate-delete', 'guard_name' => 'web'],
            ['name' => 'metal-rate-schedule', 'guard_name' => 'web'],
        ];

        Permission::upsert($permissions, ['name'], ['name']);
    }
}