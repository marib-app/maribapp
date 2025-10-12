<?php

namespace Database\Seeders;

use App\Models\Governorate;
use Illuminate\Database\Seeder;

class GovernorateSeeder extends Seeder
{
    public function run(): void
    {
        $governorates = [
            ['code' => 'NATL', 'name' => 'National Market Average'],
            ['code' => 'ABE', 'name' => 'Abyan'],
            ['code' => 'ADE', 'name' => 'Aden'],
            ['code' => 'AMN', 'name' => 'Amanat Al Asimah'],
            ['code' => 'AMR', 'name' => 'Amran'],
            ['code' => 'BAI', 'name' => 'Al Bayda'],
            ['code' => 'DAL', 'name' => 'Al Dhale\'e'],
            ['code' => 'DHA', 'name' => 'Dhamar'],
            ['code' => 'HAD', 'name' => 'Hadhramaut'],
            ['code' => 'HAJ', 'name' => 'Hajjah'],
            ['code' => 'HUD', 'name' => 'Al Hudaydah'],
            ['code' => 'IBB', 'name' => 'Ibb'],
            ['code' => 'JAW', 'name' => 'Al Jawf'],
            ['code' => 'LAH', 'name' => 'Lahij'],
            ['code' => 'MAH', 'name' => 'Al Mahrah'],
            ['code' => 'MAW', 'name' => 'Al Mahwit'],
            ['code' => 'MAR', 'name' => 'Ma\'rib'],
            ['code' => 'RAI', 'name' => 'Raymah'],
            ['code' => 'SAA', 'name' => 'Saada'],
            ['code' => 'SAN', 'name' => 'Sana\'a'],
            ['code' => 'SHB', 'name' => 'Shabwah'],
            ['code' => 'SOC', 'name' => 'Socotra'],
            ['code' => 'TAI', 'name' => 'Taiz'],
        ];

        foreach ($governorates as $governorate) {
            Governorate::updateOrCreate(
                ['code' => $governorate['code']],
                [
                    'name' => $governorate['name'],
                    'is_active' => true,
                ]
            );
        }
    }
}