<?php

namespace Database\Seeders;

use App\Models\Language;
use App\Models\Setting;
use App\Models\User;
use App\Services\DepartmentReportService;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;
use Spatie\Permission\Models\Role;

class InstallationSeeder extends Seeder
{
    public function run()
    {
        Role::updateOrCreate(['name' => 'User']);
        Role::updateOrCreate(['name' => 'Super Admin']);

        $user = User::updateOrCreate(['id' => 1], [
            'id'       => 1,
            'name'     => 'admin',
            'email'    => 'admin@gmail.com',
            'password' => Hash::make('admin123'),
        ]);
        $user->syncRoles('Super Admin');
        // إضافة اللغة العربية كلغة افتراضية
        Language::updateOrInsert(
            ['id' => 1],
            [
                'name'            => 'العربية',
                'name_in_english' => 'Arabic',
                'code'            => 'ar',
                'panel_file'      => 'ar.json',
                'app_file'        => 'ar_app.json',
                'web_file'        => 'ar_web.json',
                'rtl'             => true,
                'image'           => 'language/ar.svg'
            ]
        );
        
        // إضافة اللغة الإنجليزية كلغة ثانوية
        Language::updateOrInsert(
            ['id' => 2],
            [
                'name'            => 'English',
                'name_in_english' => 'English',
                'code'            => 'en',
                'panel_file'      => 'en.json',
                'app_file'        => 'en_app.json',
                'web_file'        => 'en_web.json',
                'rtl'             => false,
                'image'           => 'language/en.svg'
            ]
        );
        Setting::upsert(config('constants.DEFAULT_SETTINGS'), ['name'], ['value', 'type']);
        $sheinCategoryIds = app(DepartmentReportService::class)
            ->resolveCategoryIds(DepartmentReportService::DEPARTMENT_SHEIN);

        if ($sheinCategoryIds !== []) {
            Setting::updateOrCreate(
                ['name' => 'product_link_required_categories'],
                [
                    'value' => json_encode(array_values($sheinCategoryIds)),
                    'type'  => 'json',
                ]
            );
        }

    }
}
