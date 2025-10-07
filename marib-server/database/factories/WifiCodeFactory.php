<?php

namespace Database\Factories;

use App\Models\WifiCode;
use App\Models\WifiCodeBatch;
use App\Models\WifiNetwork;
use App\Models\WifiPlan;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Str;

/**
 * @extends Factory<\App\Models\WifiCode>
 */
class WifiCodeFactory extends Factory
{
    protected $model = WifiCode::class;

    public function definition(): array
    {
        $code = Str::upper(Str::random(10));
        $username = 'user-' . Str::lower(Str::random(6));
        $password = 'pass-' . Str::lower(Str::random(8));
        $serial = 'SN-' . Str::upper(Str::random(8));

        return [
            'wifi_network_id' => WifiNetwork::factory(),
            'wifi_plan_id' => WifiPlan::factory(),
            'wifi_code_batch_id' => WifiCodeBatch::factory(),
            'code_encrypted' => Crypt::encryptString($code),
            'code_hash' => WifiCode::hashCode($code),
            'username_encrypted' => Crypt::encryptString($username),
            'serial_encrypted' => Crypt::encryptString($serial),


            'password_encrypted' => Crypt::encryptString($password),
            'expires_at' => now()->addDays(7),
            'status' => WifiCode::STATUS_AVAILABLE,
            'meta' => [],
        ];
    }
}