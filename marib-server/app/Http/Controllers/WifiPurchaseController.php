<?php

namespace App\Http\Controllers;

use App\Models\PaymentTransaction;
use App\Models\User;
use App\Models\WifiPlan;
use App\Services\Wifi\WifiCodeAuditService;
use App\Models\WifiCode;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Arr;
use Illuminate\Support\Str;
use App\Support\Payments\PaymentLabelService;

class WifiPurchaseController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $user = $request->user();

        $validated = $request->validate([
            'status' => 'sometimes|string|in:' . implode(',', [
                WifiCode::STATUS_AVAILABLE,
                WifiCode::STATUS_ALLOCATED,
                WifiCode::STATUS_REDEEMED,
            ]),
            'per_page' => 'sometimes|integer|min:1|max:100',
        ]);

        $query = WifiCode::query()
            ->with([
                'network:id,name',
                'plan:id,wifi_network_id,name,price,currency',
            ])
            ->where('allocated_to_user_id', $user?->getKey())
            ->orderByDesc('allocated_at')
            ->orderByDesc('id');

        if (Arr::has($validated, 'status')) {
            $query->where('status', $validated['status']);
        }

        $perPage = $validated['per_page'] ?? 15;

        $codes = $query->paginate($perPage);
        $codes->getCollection()->transform(fn (WifiCode $code) => $this->transformCode($code));

        return response()->json($codes);
    }


    public function show(
        Request $request,
        PaymentTransaction $transaction,
        WifiCodeAuditService $auditService
    ): JsonResponse {
        $user = $request->user();

        if (! $user) {
            abort(401, __('Authentication is required.'));
        }

        if ((int) $transaction->user_id !== $user->getKey() && $user->cannot('wifi-cabin-manage')) {
            abort(403, __('You are not allowed to access this transaction.'));
        }

        $payableType = ltrim((string) $transaction->payable_type, '\\');

        if ($payableType !== '' && ! is_a($payableType, WifiPlan::class, true)) {
            abort(404, __('The requested transaction is not associated with a Wi-Fi purchase.'));
        }

        if (strtolower((string) $transaction->payment_status) !== 'succeed') {
            return response()->json([
                'message' => __('The transaction has not been completed yet.'),
            ], 409);
        }

        $code = $this->findTransactionCode($transaction, $user);

        if (! $code) {
            return response()->json([
                'message' => __('No Wi-Fi code has been issued for this transaction yet.'),
            ], 404);
        }

        $code->loadMissing([
            'network:id,name,logo_path,login_screenshot_path',
            'plan:id,wifi_network_id,name,price,currency',
        ]);

        $action = ($code->reveal_count ?? 0) > 0 ? 'view' : 'initial_reveal';

        $auditService->log($code, $user, $action, [
            'ip_address' => $request->ip(),
            'user_agent' => $request->userAgent(),
            'meta' => array_filter([
                'transaction_id' => $transaction->getKey(),
                'requested_via' => 'api',
            ], static fn ($value) => $value !== null),
        ]);

        $code->refresh();
        $code->loadMissing([
            'network:id,name,logo_path,login_screenshot_path',
            'plan:id,wifi_network_id,name,price,currency',
        ]);

        $decrypted = array_merge($code->toDecryptedArray(), [
            'id' => $code->getKey(),
            'status' => $code->status,
            'reveal_count' => $code->reveal_count,
            'revealed_at' => optional($code->revealed_at)->toDateTimeString(),
        ]);
        $transactionLabels = PaymentLabelService::forPaymentTransaction($transaction);

        return response()->json([
            'data' => [
                'code' => $decrypted,
                'network' => $code->network ? [
                    'id' => $code->network->getKey(),
                    'name' => $code->network->name,
                    'logo_url' => $code->network->logo_url,
                    'login_screenshot_url' => $code->network->login_screenshot_url,
                ] : null,
                'plan' => $code->plan ? [
                    'id' => $code->plan->getKey(),
                    'name' => $code->plan->name,
                    'price' => $code->plan->price,
                    'currency' => $code->plan->currency,
                ] : null,
                'transaction' => array_filter([
                    'id' => $transaction->getKey(),
                    'payment_gateway' => $transaction->payment_gateway,
                    'payment_status' => $transaction->payment_status,
                    'meta' => $transaction->meta,
                    'terms_acknowledged' => (bool) data_get($transaction->meta, 'terms_acknowledged'),
                    'gateway_key' => $transactionLabels['gateway_key'],
                    'gateway_label' => $transactionLabels['gateway_label'],
                    'bank_name' => $transactionLabels['bank_name'],
                ], static fn ($value) => $value !== null),
            ],
        ]);
    }


    private function transformCode(WifiCode $code): array
    {
        $network = $code->getRelation('network');
        $plan = $code->getRelation('plan');

        return [
            'id' => $code->getKey(),
            'status' => $code->status,
            'code' => $this->maskValue($code->getDecryptedCode()),
            'serial_no' => $this->maskValue($code->getDecryptedSerialNumber()),

            'transaction_id' => data_get($code->meta, 'payment_transaction_id'),
            'reveal_count' => $code->reveal_count,
            'revealed_at' => optional($code->revealed_at)->toDateTimeString(),

            
            'expires_at' => optional($code->expires_at)->toDateTimeString(),
            'purchased_at' => optional($code->allocated_at)->toDateTimeString(),
            'network' => $network ? [
                'id' => $network->getKey(),
                'name' => $network->name,
            ] : null,
            'plan' => $plan ? [
                'id' => $plan->getKey(),
                'name' => $plan->name,
                'price' => $plan->price,
                'currency' => $plan->currency,
            ] : null,
            'price' => $plan?->price,
            'currency' => $plan?->currency,
        ];
    }



    private function findTransactionCode(PaymentTransaction $transaction, User $user): ?WifiCode
    {
        $codeId = data_get($transaction->meta, 'wifi_code_id');

        return WifiCode::query()
            ->where('allocated_to_user_id', $user->getKey())
            ->where(function ($builder) use ($transaction, $codeId) {
                $builder->where('meta->payment_transaction_id', $transaction->getKey());

                if ($codeId) {
                    $builder->orWhereKey($codeId);
                }
            })
            ->orderByDesc('allocated_at')
            ->orderByDesc('id')
            ->first();
    }


    private function maskValue(?string $value): ?string
    {
        if ($value === null) {
            return null;
        }

        $length = Str::length($value);

        if ($length <= 4) {
            return $value;
        }

        $visible = Str::substr($value, -4);
        $maskedLength = $length - Str::length($visible);

        return str_repeat('*', $maskedLength) . $visible;
    }
}