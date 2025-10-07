<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Spatie\Permission\Models\Permission;

class CurrencyPermissionSeeder extends Seeder
{
    /**
     * Run the database seeds.
     *
     * @return void
     */
    public function run()
    {
        $permissions = [
            [
                'name' => 'currency-rate-list',
                'guard_name' => 'web'
            ],
            [
                'name' => 'currency-rate-create',
                'guard_name' => 'web'
            ],
            [
                'name' => 'currency-rate-edit',
                'guard_name' => 'web'
            ],
            [
                'name' => 'currency-rate-delete',
                'guard_name' => 'web'
            ]
        ];

        Permission::upsert($permissions, ['name'], ['name']);
    }
} 