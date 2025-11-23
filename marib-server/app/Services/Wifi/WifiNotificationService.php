<?php

namespace App\Services\Wifi;

use App\Enums\Wifi\WifiCodeBatchStatus;
use App\Models\UserFcmToken;
use App\Models\Wifi\WifiCodeBatch;
use App\Models\Wifi\WifiNetwork;
use App\Models\Wifi\WifiPlan;
use App\Services\NotificationService;
use Illuminate\Support\Facades\DB;

class WifiNotificationService
{
    private const DEFAULT_COMMISSION_EXAMPLE_AMOUNT = 1000.0;

    public function notifyNetworkSubmitted(WifiNetwork $network): void
    {
        $network->loadMissing('owner');

        $title = __('wifi.notifications.network_submitted_title');
        $body = __('wifi.notifications.network_submitted_body', [
            'name' => $network->name,
        ]);

        $this->dispatchToOwner($network, $title, $body, 'wifi_network_submitted', [
            'wifi_network_id' => $network->getKey(),
            'status' => $network->status?->value,
            'deeplink' => config('services.mobile.wifi_owner_networks_deeplink', 'eclassify://wifi/owner/networks'),
        ]);
    }

    public function notifyNetworkStatusUpdated(WifiNetwork $network, ?string $reason = null): void
    {
        $network->loadMissing('owner');

        $title = __('wifi.notifications.network_status_title');
        $statusKey = strtolower((string) $network->status?->value);
        $statusLabel = __('wifi.notifications.status_' . $statusKey);
        if ($statusLabel === 'wifi.notifications.status_' . $statusKey) {
            $statusLabel = $statusKey ?: (string) $network->status?->value;
        }

        $body = __('wifi.notifications.network_status_body', [
            'name' => $network->name,
            'status' => $statusLabel,
        ]);

        if ($reason) {
            $body .= ' ' . __('wifi.notifications.network_status_reason', [
                'reason' => $reason,
            ]);
        }

        $this->dispatchToOwner($network, $title, $body, 'wifi_network_status', [
            'wifi_network_id' => $network->getKey(),
            'status' => $network->status?->value,
            'deeplink' => config('services.mobile.wifi_owner_networks_deeplink', 'eclassify://wifi/owner/networks'),
            'reason' => $reason,
        ]);
    }

    public function notifyCommissionUpdated(WifiNetwork $network, float $rate): void
    {
        $network->loadMissing('owner');

        [$amount, $commissionValue, $netAmount, $currency] = $this->buildCommissionExample($network, $rate);

        $title = __('wifi.notifications.commission_updated_title');
        $body = __('wifi.notifications.commission_updated_body', [
            'rate' => number_format($rate * 100, 2),
            'amount' => number_format($amount, 2),
            'currency' => $currency,
            'commission' => number_format($commissionValue, 2),
            'net' => number_format($netAmount, 2),
        ]);

        $this->dispatchToOwner($network, $title, $body, 'wifi_commission_updated', [
            'wifi_network_id' => $network->getKey(),
            'commission_rate' => $rate,
            'deeplink' => config('services.mobile.wifi_owner_networks_deeplink', 'eclassify://wifi/owner/networks'),
            'example_amount' => $amount,
            'example_commission' => $commissionValue,
            'example_net' => $netAmount,
            'currency' => $currency,
        ]);
    }

    public function notifyBatchStatusChanged(
        WifiCodeBatch $batch,
        WifiCodeBatchStatus $status,
        ?string $reason = null
    ): void {
        $batch->loadMissing(['plan.network.owner']);

        $network = $batch->plan?->network;
        if (! $network instanceof WifiNetwork) {
            return;
        }

        if ($status === WifiCodeBatchStatus::ACTIVE || $status === WifiCodeBatchStatus::VALIDATED) {
            $title = __('wifi.notifications.batch_approved_title');
            $body = __('wifi.notifications.batch_approved_body', [
                'label' => $batch->label,
                'plan' => $batch->plan?->name,
            ]);
        } elseif ($status === WifiCodeBatchStatus::ARCHIVED) {
            $title = __('wifi.notifications.batch_rejected_title');
            $body = __('wifi.notifications.batch_rejected_body', [
                'label' => $batch->label,
                'plan' => $batch->plan?->name,
            ]);

            if ($reason) {
                $body .= ' ' . __('wifi.notifications.batch_rejected_reason', ['reason' => $reason]);
            }
        } else {
            return;
        }

        $this->dispatchToOwner($network, $title, $body, 'wifi_batch_status', [
            'wifi_network_id' => $network->getKey(),
            'wifi_plan_id' => $batch->plan?->getKey(),
            'wifi_code_batch_id' => $batch->getKey(),
            'status' => $status->value,
            'deeplink' => config('services.mobile.wifi_owner_batches_deeplink', 'eclassify://wifi/owner/batches'),
            'reason' => $reason,
        ]);
    }

    /**
     * @return array{0: float, 1: float, 2: float, 3: string}
     */
    protected function buildCommissionExample(WifiNetwork $network, float $rate): array
    {
        $currency = config('app.currency', 'YER');

        $planPrice = WifiPlan::query()
            ->where('wifi_network_id', $network->getKey())
            ->orderBy('price')
            ->value('price');

        if ($planPrice !== null) {
            $amount = (float) $planPrice;
            $currency = $network->plans()
                ->orderBy('price')
                ->value('currency') ?: $currency;
        } else {
            $amount = self::DEFAULT_COMMISSION_EXAMPLE_AMOUNT;
        }

        $commission = round($amount * $rate, 2);
        $net = round(max($amount - $commission, 0), 2);

        return [$amount, $commission, $net, $currency];
    }

    /**
     * @param array<string, mixed> $payload
     */
    protected function dispatchToOwner(
        WifiNetwork $network,
        string $title,
        string $body,
        string $type,
        array $payload
    ): void {
        $tokens = $this->resolveOwnerTokens($network);

        if ($tokens === []) {
            return;
        }

        DB::afterCommit(static function () use ($tokens, $title, $body, $type, $payload): void {
            NotificationService::sendFcmNotification(
                $tokens,
                $title,
                $body,
                $type,
                array_filter(
                    $payload,
                    static fn ($value) => $value !== null && $value !== ''
                )
            );
        });
    }

    /**
     * @return array<int, string>
     */
    protected function resolveOwnerTokens(WifiNetwork $network): array
    {
        $owner = $network->owner;

        if (! $owner) {
            return [];
        }

        return UserFcmToken::query()
            ->where('user_id', $owner->getKey())
            ->pluck('fcm_token')
            ->filter()
            ->unique()
            ->values()
            ->all();
    }
}
