<?php

namespace App\Services\Wifi;

use App\Models\User;
use App\Models\WifiCode;
use App\Models\WifiCodeRevealLog;
use Illuminate\Support\Facades\DB;
use InvalidArgumentException;

class WifiCodeAuditService
{
    public function log(WifiCode $code, User $user, string $action, array $context = []): WifiCodeRevealLog
    {
        $normalizedAction = trim(strtolower($action));

        if ($normalizedAction === '') {
            throw new InvalidArgumentException('A valid action is required to record the Wi-Fi code audit entry.');
        }

        return DB::transaction(function () use ($code, $user, $normalizedAction, $context) {
            $lockedCode = WifiCode::query()->lockForUpdate()->findOrFail($code->getKey());

            $log = WifiCodeRevealLog::create([
                'wifi_code_id' => $lockedCode->getKey(),
                'user_id' => $user->getKey(),
                'action' => $normalizedAction,
                'ip_address' => $context['ip_address'] ?? null,
                'user_agent' => $context['user_agent'] ?? null,
                'meta' => $context['meta'] ?? null,
            ]);

            if (in_array($normalizedAction, ['view', 'initial_reveal'], true)) {
                $updates = [
                    'reveal_count' => ($lockedCode->reveal_count ?? 0) + 1,
                ];

                if ($lockedCode->revealed_at === null) {
                    $updates['revealed_at'] = now();
                }

                $lockedCode->forceFill($updates)->save();
            }

            return $log;
        });
    }
}