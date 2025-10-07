<?php

namespace Database\Seeders;

use App\Models\RequestDevice;
use Illuminate\Database\Seeder;
use Carbon\Carbon;

class RequestDeviceSeeder extends Seeder
{
    /**
     * تشغيل بذرة قاعدة البيانات.
     *
     * @return void
     */
    public function run()
    {
        // إضافة بيانات تجريبية
        $devices = [
            [
                'section' => 'computer',
                'phone' => '0512345678',
                'subject' => 'طلب صيانة جهاز كمبيوتر',
                'message' => 'أواجه مشكلة في تشغيل جهاز الكمبيوتر الخاص بي. يرجى المساعدة في إصلاحه.',
                'image' => null,
                'created_at' => Carbon::now()->subDays(5),
                'updated_at' => Carbon::now()->subDays(5),
            ],
            [
                'section' => 'computer',
                'phone' => '0523456789',
                'subject' => 'استفسار عن أسعار أجهزة الكمبيوتر',
                'message' => 'أرغب في معرفة أسعار أجهزة الكمبيوتر المكتبية المتوفرة لديكم.',
                'image' => null,
                'created_at' => Carbon::now()->subDays(3),
                'updated_at' => Carbon::now()->subDays(3),
            ],
            [
                'section' => 'computer',
                'phone' => '0534567890',
                'subject' => 'طلب تركيب برامج',
                'message' => 'أحتاج إلى تركيب برامج مكتبية على جهاز الكمبيوتر الخاص بي.',
                'image' => null,
                'created_at' => Carbon::now()->subDays(2),
                'updated_at' => Carbon::now()->subDays(2),
            ],
            [

                'section' => 'computer',
                'phone' => '0545678901',
                'subject' => 'مشكلة في الشاشة',
                'message' => 'شاشة الكمبيوتر الخاص بي لا تعمل بشكل صحيح، أحتاج إلى مساعدة فنية.',
                'image' => null,
                'created_at' => Carbon::now()->subDay(),
                'updated_at' => Carbon::now()->subDay(),
            ],
            [

                'section' => 'computer',
                'phone' => '0556789012',
                'subject' => 'استبدال قطع غيار',
                'message' => 'أرغب في استبدال بعض قطع الغيار في جهاز الكمبيوتر الخاص بي.',
                'image' => null,
                'created_at' => Carbon::now(),
                'updated_at' => Carbon::now(),
            ],
        ];

        // إضافة البيانات إلى قاعدة البيانات
        foreach ($devices as $device) {
            RequestDevice::create($device);
        }
    }
} 