<?php

namespace App\Http\Controllers\Wifi;

use App\Http\Controllers\Controller;
use App\Models\PaymentTransaction;
use App\Models\Wifi\WifiCode;
use App\Models\Wifi\WifiPlan;
use App\Models\Wifi\WifiNetwork;
use App\Enums\Wifi\WifiCodeStatus;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpFoundation\Response;

class WifiOrderController extends Controller
{
    public function revealCode(Request $request, PaymentTransaction $transaction): JsonResponse
    {
        $userId = $request->user()?->getKey();
        if ($transaction->user_id !== $userId) {
            abort(Response::HTTP_FORBIDDEN, 'Unauthorized');
        }

        $explicitCodeId = data_get($transaction->meta, 'wifi_code_id')
            ?? data_get($transaction->meta, 'wifi.wifi_code_id');

        $codeQuery = WifiCode::query()
            ->with(['plan:id,name,price,currency,wifi_network_id', 'plan.network:id,name'])
            ->orderByDesc('sold_at')
            ->orderByDesc('id');

        if ($explicitCodeId) {
            $codeQuery->whereKey($explicitCodeId);
        } else {
            $codeQuery
                ->where(function ($q) use ($transaction): void {
                    $q->where('meta->payment_transaction_id', $transaction->getKey())
                        ->orWhere('meta->payment_transaction_id', (string) $transaction->getKey());
                })
                ->when($transaction->payable_id, function ($q, $planId) {
                    $q->orWhere('wifi_plan_id', $planId);
                })
                ->when(data_get($transaction->meta, 'wifi.network_id'), function ($q, $networkId) {
                    $q->orWhere('wifi_network_id', $networkId);
                });
        }

        $code = $codeQuery->first();

        if (! $code instanceof WifiCode) {
            // إذا لم نجد كوداً مرتبطاً بالمعاملة، نحاول بيع/تخصيص كود متاح الآن
            $code = DB::transaction(function () use ($transaction, $userId) {
                if ($transaction->payable_type !== WifiPlan::class || ! $transaction->payable_id) {
                    return null;
                }

                $plan = WifiPlan::query()->with('network')->lockForUpdate()->find($transaction->payable_id);
                if (! $plan instanceof WifiPlan) {
                    return null;
                }
                $network = $plan->network;
                if (! $network instanceof WifiNetwork) {
                    return null;
                }

                $fallback = WifiCode::query()
                    ->where('wifi_plan_id', $plan->getKey())
                    ->where('status', WifiCodeStatus::AVAILABLE->value)
                    ->orderBy('id')
                    ->lockForUpdate()
                    ->first();

                if (! $fallback instanceof WifiCode) {
                    return null;
                }

                $now = now();
                $fallback->status = WifiCodeStatus::SOLD;
                $fallback->sold_at = $now;
                $fallback->delivered_at = $now;
                $fallback->meta = array_replace_recursive($fallback->meta ?? [], [
                    'payment_transaction_id' => $transaction->getKey(),
                    'sold_to_user_id' => $userId,
                ]);
                $fallback->save();

                // اربط المعاملة بالكود
                $meta = $transaction->meta ?? [];
                $meta['wifi_code_id'] = $fallback->getKey();
                $meta['wifi']['wifi_code_id'] = $fallback->getKey();
                $transaction->meta = $meta;
                $transaction->save();

                return $fallback;
            });
        }

        if (! $code instanceof WifiCode) {
            abort(Response::HTTP_NOT_FOUND, 'Wifi code not found for this transaction.');
        }

        $plan = $code->plan;
        $network = $plan?->network;

        // حاول فك التشفير، وإن فشل استخدم آخر 4 أرقام كحل مؤقت
        $plainCode = null;
        try {
            $plainCode = $code->code ?? null;
        } catch (\Throwable) {
            $plainCode = null;
        }
        if (! $plainCode) {
            try {
                $plainCode = \Illuminate\Support\Facades\Crypt::decryptString($code->code_encrypted);
            } catch (\Throwable) {
                $plainCode = $code->code_suffix ?? $code->code_last4 ?? null;
            }
        }

        return response()->json([
            'data' => [
                'code' => [
                    'id' => $code->getKey(),
                    'code' => $plainCode,
                    'username' => $code->username,
                    'password' => $code->password,
                    'serial_no' => $code->serialNo,
                    'expiry_date' => optional($code->expiry_date)->toDateString(),
                    'status' => $code->status?->value ?? $code->status,
                    'reveal_count' => $code->reveal_count ?? null,
                    'revealed_at' => optional($code->revealed_at)->toDateTimeString(),
                ],
                'plan' => $plan ? [
                    'id' => $plan->getKey(),
                    'name' => $plan->name,
                    'price' => $plan->price,
                    'currency' => $plan->currency,
                ] : null,
                'network' => $network ? [
                    'id' => $network->getKey(),
                    'name' => $network->name,
                ] : null,
                'transaction' => [
                    'id' => $transaction->getKey(),
                    'amount' => $transaction->amount,
                    'currency' => $transaction->currency,
                    'payment_status' => $transaction->payment_status,
                    'payment_gateway' => $transaction->payment_gateway,
                ],
            ],
        ]);
    }
}
use Illuminate\Support\Facades\Crypt;
