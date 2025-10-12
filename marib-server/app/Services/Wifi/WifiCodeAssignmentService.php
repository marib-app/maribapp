<?php

namespace App\Services\Wifi;

use App\Models\PaymentTransaction;
use App\Models\User;
use App\Models\WifiCode;
use App\Models\WifiPlan;
use App\Services\NotificationService;
use App\Services\WalletService;
use Illuminate\Support\Facades\DB;
use RuntimeException;

class WifiCodeAssignmentService
{
    public function __construct(private readonly WalletService $walletService)
    {
    }

    /**
     * @return array{code: WifiCode, gross_amount: float, commission_amount: float, net_amount: float}
     */
    public function assign(WifiPlan $plan, User $buyer, PaymentTransaction $transaction, array $options = []): array
    {
        $grossAmount = (float) ($options['amount'] ?? $transaction->amount ?? $plan->price);

        if ($grossAmount <= 0) {
            $grossAmount = (float) $plan->price;
        }

        return DB::transaction(function () use ($plan, $buyer, $transaction, $grossAmount, $options) {
            $plan->loadMissing('network.owner');
            $network = $plan->network;

            if (!$network || !$network->owner) {
                throw new RuntimeException('Wi-Fi plan network owner could not be resolved.');
            }

            $code = WifiCode::query()
                ->where('wifi_network_id', $network->getKey())
                ->where(function ($query) use ($plan) {
                    $query->where('wifi_plan_id', $plan->getKey());
                })
                ->available()
                ->orderBy('id')
                ->lockForUpdate()
                ->first();

            if (!$code) {
                throw new RuntimeException(__('No Wi-Fi codes are available for the selected plan.'));
            }

            $commissionRate = $network->effectiveCommissionRate($plan);
            $commissionFlat = (float) $network->commission_flat;
            $commissionAmount = round(($grossAmount * ($commissionRate / 100)), 2) + $commissionFlat;
            $commissionAmount = min($commissionAmount, $grossAmount);
            $netAmount = round($grossAmount - $commissionAmount, 2);

            $code->forceFill([
                'status' => WifiCode::STATUS_ALLOCATED,
                'allocated_to_user_id' => $buyer->getKey(),
                'allocated_at' => now(),
                'meta' => array_filter(
                    array_merge($code->meta ?? [], [
                        'payment_transaction_id' => $transaction->getKey(),
                        'gross_amount' => $grossAmount,
                        'commission_amount' => $commissionAmount,
                        'net_amount' => $netAmount,
                    ]),
                    static fn ($value) => $value !== null
                ),
            ])->save();

            if ($netAmount > 0) {
                $this->walletService->credit(
                    $network->owner,
                    'wifi-credit-' . $transaction->getKey(),
                    $netAmount,
                    [
                        'currency' => $plan->currency,
                        'payment_transaction' => $transaction,
                        'meta' => array_filter([
                            'source' => 'wifi_plan_purchase',
                            'wifi_plan_id' => $plan->getKey(),
                            'wifi_network_id' => $network->getKey(),
                            'wifi_code_id' => $code->getKey(),
                            'gross_amount' => $grossAmount,
                            'commission_amount' => $commissionAmount,
                            'net_amount' => $netAmount,
                        ], static fn ($value) => $value !== null),
                    ]
                );
            }

            DB::afterCommit(function () use ($code, $buyer, $network, $plan) {
                NotificationService::notifyWifiBuyerCodeReady($buyer, $network, $plan, $code);
                NotificationService::notifyWifiOwnerPurchase($network->owner, $buyer, $network, $plan, $code);
            });

            return [
                'code' => $code->fresh(),
                'gross_amount' => $grossAmount,
                'commission_amount' => $commissionAmount,
                'net_amount' => $netAmount,
            ];
        });
    }
}