<?php

namespace Database\Seeders;

use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;
use App\Models\User;
use App\Models\Challenge;
use App\Models\Referral;
use Illuminate\Support\Facades\Hash;

class ReferralSystemSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        // إنشاء مستخدمين تجريبيين
        $users = [
            [
                'name' => 'أحمد محمد',
                'email' => 'ahmed@example.com',
                'password' => Hash::make('password123'),
                'mobile' => '0501234567'
            ],
            [
                'name' => 'سارة خالد',
                'email' => 'sara@example.com',
                'password' => Hash::make('password123'),
                'mob' => '0507654321'
            ],
            [
                'name' => 'محمد علي',
                'email' => 'mohammed@example.com',
                'password' => Hash::make('password123'),
                'mob' => '0503456789'
            ],
            [
                'name' => 'فاطمة أحمد',
                'email' => 'fatima@example.com',
                'password' => Hash::make('password123'),
                'mob' => '0509876543'
            ],
            [
                'name' => 'عمر حسن',
                'email' => 'omar@example.com',
                'password' => Hash::make('password123'),
                'mob' => '0502345678'
            ]
        ];

        foreach ($users as $userData) {
            User::create($userData);
        }

        // إنشاء تحديات تجريبية
        $challenges = [
            [
                'title' => 'دعوة 5 أصدقاء',
                'description' => 'قم بدعوة 5 أصدقاء للانضمام إلى المنصة',
                'points' => 50,
                'status' => 'active'
            ],
            [
                'title' => 'إكمال الملف الشخصي',
                'description' => 'قم بإكمال جميع معلومات ملفك الشخصي',
                'points' => 30,
                'status' => 'active'
            ],
            [
                'title' => 'إجراء أول طلب',
                'description' => 'قم بإجراء أول طلب شراء في المنصة',
                'points' => 100,
                'status' => 'active'
            ],
            [
                'title' => 'مشاركة تجربتك',
                'description' => 'قم بكتابة تقييم لتجربتك مع المنصة',
                'points' => 25,
                'status' => 'active'
            ]
        ];

        foreach ($challenges as $challengeData) {
            Challenge::create($challengeData);
        }

        // إنشاء إحالات تجريبية
        $users = User::all();
        $challenges = Challenge::all();

        // إنشاء 20 إحالة تجريبية
        for ($i = 0; $i < 20; $i++) {
            $referrer = $users->random();
            $referred = $users->except($referrer->id)->random();
            $challenge = $challenges->random();

            Referral::create([
                'referrer_id' => $referrer->id,
                'referred_user_id' => $referred->id,
                'challenge_id' => $challenge->id,
                'points' => $challenge->points,
                'status' => 'completed',
                'created_at' => now()->subDays(rand(1, 30)), // تواريخ عشوائية خلال الشهر الماضي
                'updated_at' => now()->subDays(rand(1, 30))
            ]);
        }
    }
}
