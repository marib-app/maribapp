<?php

namespace App\Http\Controllers\Wifi;

use App\Enums\Wifi\WifiCodeStatus;
use App\Http\Controllers\Controller;
use App\Http\Resources\PaymentTransactionResource;
use App\Models\PaymentTransaction;
use App\Models\Wifi\WifiCode;
use App\Models\Wifi\WifiPlan;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

class WifiOrderController extends Controller
{
    public function showCode(Request $request, int $transaction): JsonResponse
    {
        $user = $request->user();

        if (! $user) {
            abort(401);
        }

        /** @var PaymentTransaction $paymentTransaction */
        $paymentTransaction = PaymentTransaction::query()
            ->with('manualPaymentRequest')
            ->whereKey($transaction)
            ->firstOrFail();

        if ((int) $paymentTransaction->user_id !== $user->getKey()) {
            abort(404);
        }

        if ($paymentTransaction->payable_type !== WifiPlan::class) {
            abort(404);
        }

        if (strtolower((string) $paymentTransaction->payment_status) !== 'succeed') {
            throw ValidationException::withMessages([
                'transaction_id' => __('This WiFi card is not ready yet. Please try again shortly.'),
            ]);
        }

        $codeQuery = WifiCode::query()
            ->where('wifi_plan_id', (int) $paymentTransaction->payable_id)
            ->where(function ($query) use ($transaction, $user): void {
                $query->where('meta->payment_transaction_id', $transaction)
                    ->orWhere('meta->transaction_id', $transaction)
                    ->orWhere('meta->sold_to_user_id', $user->getKey());
            });

        /** @var WifiCode|null $code */
        $code = $codeQuery->first();

        if (! $code instanceof WifiCode) {
            abort(404, __('Unable to locate the WiFi card for this order.'));
        }

        $plan = $code->plan()->with('network')->first();

        $payload = [
            'code' => [
                'id' => $code->getKey(),
                'code' => $code->code,
                'username' => $code->username,
                'password' => $code->password,
                'serial_no' => $code->serialNo,
                'expiry_date' => optional($code->expiry_date)->toDateString(),
                'status' => $code->status instanceof WifiCodeStatus
                    ? $code->status->value
                    : $code->status,
            ],
            'plan' => $plan ? [
                'id' => $plan->getKey(),
                'name' => $plan->name,
                'price' => (float) $plan->price,
                'currency' => $plan->currency,
            ] : null,
            'network' => $plan && $plan->network ? [
                'id' => $plan->network->getKey(),
                'name' => $plan->network->name,
            ] : null,
            'transaction' => PaymentTransactionResource::make($paymentTransaction)->resolve(),
        ];

        return response()->json([
            'data' => $payload,
        ]);
    }
}
