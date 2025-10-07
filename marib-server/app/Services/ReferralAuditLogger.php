<?php

namespace App\Services;
use App\Models\ReferralAttempt;
use Illuminate\Support\Arr;
class ReferralAuditLogger
{
    public function record(string $status, array $context = []): ReferralAttempt
    {
        app(TelemetryService::class)->record('referral.attempt', array_merge($context, [
            'status' => $status,
        ]));




        $knownContextKeys = [
            'code',
            'referrer_id',
            'referred_user_id',
            'referral_id',
            'challenge_id',
            'lat',
            'lng',
            'admin_area',
            'device_time',
            'contact',
            'request_ip',
            'user_agent',
            'awarded_points',
            'exception_message',
            'meta',
        ];

        $payload = [
            'status' => $status,
            'code' => $context['code'] ?? null,
            'referrer_id' => $context['referrer_id'] ?? null,
            'referred_user_id' => $context['referred_user_id'] ?? null,
            'referral_id' => $context['referral_id'] ?? null,
            'challenge_id' => $context['challenge_id'] ?? null,
            'lat' => $context['lat'] ?? null,
            'lng' => $context['lng'] ?? null,
            'admin_area' => $context['admin_area'] ?? null,
            'device_time' => $context['device_time'] ?? null,
            'contact' => $context['contact'] ?? null,
            'request_ip' => $context['request_ip'] ?? null,
            'user_agent' => $context['user_agent'] ?? null,
            'awarded_points' => $context['awarded_points'] ?? null,
            'exception_message' => $context['exception_message'] ?? null,
        ];

        $extraMeta = Arr::except($context, array_merge($knownContextKeys, ['status']));

        if (!empty($context['meta']) && is_array($context['meta'])) {
            $extraMeta = array_merge($extraMeta, $context['meta']);
        }

        if (!empty($extraMeta)) {
            $payload['meta'] = $extraMeta;
        }

        return ReferralAttempt::create($payload);



    }
}