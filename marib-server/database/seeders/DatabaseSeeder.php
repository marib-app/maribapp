<?php

namespace Database\Seeders;

// use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    /**
     * Seed the application's database.
     *
     * @return void
     */
    public function run()
    {
        $this->call([
            // ReferralSystemSeeder::class,
            GovernorateSeeder::class,
            RequestDeviceSeeder::class,
            UpdateUserAccountTypeSeeder::class,
            InstallationSeeder::class,
            SystemUpgradeSeeder::class,
            OrdersTestDataSeeder::class,
            CurrencyPermissionSeeder::class,
            ChatMonitorPermissionSeeder::class,
        
            FeatureSectionActivationSeeder::class,


            PricingSeeder::class,


        ]);
    }
}
