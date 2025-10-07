<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Spatie\Permission\Models\Permission;
use Spatie\Permission\Models\Role;

class ComprehensivePermissionSeeder extends Seeder
{
    /**
     * Run the database seeds.
     *
     * @return void
     */
    public function run()
    {
        // Chat Monitor Permissions
        $chatPermissions = [
            'chat-monitor-list',
        ];

        // Orders Management Permissions
        $ordersPermissions = [
            'orders-list',
            'orders-create',
            'orders-update',
            'orders-delete',
        ];

        // Delivery Prices Permissions
        $deliveryPermissions = [
            'delivery-prices-list',
            'delivery-prices-create',
            'delivery-prices-update',
            'delivery-prices-delete',
        ];

        // Reports Permissions
        $reportsPermissions = [
            'reports-orders',
            'reports-sales',
            'reports-customers',
            'reports-statuses',
        ];

        // Contact Us Permissions
        $contactPermissions = [
            'contact-us-list',
            'contact-us-update',
            'contact-us-delete',
        ];

        // Notifications Permissions
        $notificationPermissions = [
            'notifications-send',
        ];

        // Service Requests Permissions
        $serviceRequestPermissions = [
            'service-requests-list',
            'service-requests-create',
            'service-requests-update',
            'service-requests-delete',
        ];

        $serviceManagerPermissions = [
            'service-managers-manage',
        ];


        $walletPermissions = [
            'wallet-manage',
        ];

        // Combine all permissions
        $allPermissions = array_merge(
            $chatPermissions,
            $ordersPermissions,
            $deliveryPermissions,
            $reportsPermissions,
            $contactPermissions,
            $notificationPermissions,
            $serviceRequestPermissions,
            $serviceManagerPermissions,
            $walletPermissions
        );

        // Create permissions
        foreach ($allPermissions as $permission) {
            Permission::firstOrCreate(['name' => $permission]);
        }

        // Assign permissions to Super Admin role
        $superAdminRole = Role::where('name', 'Super Admin')->first();
        if ($superAdminRole) {
            $superAdminRole->givePermissionTo($allPermissions);
        }

        // Assign permissions to Admin role
        $adminRole = Role::where('name', 'Admin')->first();
        if ($adminRole) {
            $adminRole->givePermissionTo($allPermissions);
        }

        $this->command->info('Comprehensive permissions created and assigned successfully!');
    }
}