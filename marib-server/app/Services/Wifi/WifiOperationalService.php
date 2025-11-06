<?php

namespace App\Services\Wifi;

use App\Enums\Wifi\WifiCodeStatus;
use App\Enums\Wifi\WifiNetworkStatus;
use App\Enums\Wifi\WifiReportStatus;
use App\Models\User;
use App\Models\UserFcmToken;
use App\Models\Wifi\ReputationCounter;
use App\Models\Wifi\WifiCode;
use App\Models\Wifi\WifiNetwork;
use App\Models\Wifi\WifiPlan;
use App\Models\Wifi\WifiReport;
use App\Services\NotificationService;
use App\Services\SmsService;
use Carbon\Carbon;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class WifiOperationalService
{
    public function __construct(private readonly SmsService $smsService)
    {
    }

    /**
     * @param array<string, mixed> $planMeta
     * @return array<string, mixed>
     */
    public function handlePostSaleInventory(WifiPlan $plan, WifiNetwork $network, array $planMeta): array
    {
        $availableCodes = WifiCode::query()
            ->where('wifi_plan_id', $plan->getKey())
            ->where('status', WifiCodeStatus::AVAILABLE->value)
            ->count();

        $threshold = $this->resolveLowStockThreshold($plan, $network, $planMeta);

        data_set($planMeta, 'alerts.low_stock.last_available', $availableCodes);

        if ($threshold <= 0) {
            if (data_get($planMeta, 'alerts.low_stock.last_triggered_at') !== null) {
                data_set($planMeta, 'alerts.low_stock.last_triggered_at', null);
            }

            return $planMeta;
        }

        $cooldownMinutes = $this->resolveLowStockCooldownMinutes($plan, $network, $planMeta);
        $now = Carbon::now();
        $lastTriggeredAt = data_get($planMeta, 'alerts.low_stock.last_triggered_at');
        $lastTriggered = $lastTriggeredAt ? Carbon::parse($lastTriggeredAt) : null;

        if ($availableCodes > $threshold) {
            if ($lastTriggered !== null) {
                data_set($planMeta, 'alerts.low_stock.last_triggered_at', null);
            }

            return $planMeta;
        }

        if ($lastTriggered !== null && $now->diffInMinutes($lastTriggered) < $cooldownMinutes) {
            return $planMeta;
        }

        $this->dispatchLowStockAlerts($plan, $network, $availableCodes, $threshold);

        data_set($planMeta, 'alerts.low_stock.last_triggered_at', $now->toIso8601String());

        return $planMeta;
    }

    /**
     * @param array<string, mixed> $planMeta
     */
    private function resolveLowStockThreshold(WifiPlan $plan, WifiNetwork $network, array $planMeta): int
    {
        $planThreshold = data_get($planMeta, 'alerts.low_stock.threshold');
        if (is_numeric($planThreshold)) {
            return max(0, (int) $planThreshold);
        }

        $networkSettings = $network->settings ?? [];
        $networkThreshold = data_get($networkSettings, 'alerts.low_stock.threshold');
        if (is_numeric($networkThreshold)) {
            return max(0, (int) $networkThreshold);
        }

        return max(0, (int) config('wifi.alerts.low_stock_threshold', 10));
    }

    /**
     * @param array<string, mixed> $planMeta
     */
    private function resolveLowStockCooldownMinutes(WifiPlan $plan, WifiNetwork $network, array $planMeta): int
    {
        $planCooldown = data_get($planMeta, 'alerts.low_stock.cooldown_minutes');
        if (is_numeric($planCooldown)) {
            return max(1, (int) $planCooldown);
        }

        $networkSettings = $network->settings ?? [];
        $networkCooldown = data_get($networkSettings, 'alerts.low_stock.cooldown_minutes');
        if (is_numeric($networkCooldown)) {
            return max(1, (int) $networkCooldown);
        }

        return max(1, (int) config('wifi.alerts.low_stock_cooldown_minutes', 180));
    }

    private function dispatchLowStockAlerts(WifiPlan $plan, WifiNetwork $network, int $availableCodes, int $threshold): void
    {
        $owner = $network->owner;

        DB::afterCommit(function () use ($plan, $network, $availableCodes, $threshold, $owner): void {
            $message = __('تنبيه: مخزون أكواد خطة :plan ضمن شبكة :network منخفض (:count متبقي).', [
                'plan' => $plan->name,
                'network' => $network->name,
                'count' => $availableCodes,
            ]);

            $fcmPayload = [
                'wifi_plan_id' => $plan->getKey(),
                'wifi_network_id' => $network->getKey(),
                'available_codes' => $availableCodes,
                'threshold' => $threshold,
            ];

            $ownerTokens = $this->resolveOwnerFcmTokens($network);
            if ($ownerTokens !== []) {
                NotificationService::sendFcmNotification(
                    $ownerTokens,
                    __('تنبيه مخزون الأكواد'),
                    $message,
                    'wifi_low_stock',
                    $fcmPayload
                );
            }

            $numbers = $this->resolveNetworkPhoneNumbers($network);
            if ($owner && $owner->mobile) {
                $numbers[] = $this->formatPhoneNumber($owner);
            }

            $numbers = array_values(array_unique(array_filter($numbers)));

            foreach ($numbers as $number) {
                $this->smsService->send($number, $message);
            }
        });
    }

    /**
     * Handle logic once a report is created.
     */
    public function handleReportCreated(WifiReport $report): void
    {
        $report->loadMissing('network.owner');
        $network = $report->network;

        if (! $network instanceof WifiNetwork) {
            return;
        }

        $this->notifyOwnerOfReport($report, $network);
        $this->evaluateReportEscalation($network, $report);
    }

    public function handleReportUpdated(WifiReport $report): void
    {
        $report->loadMissing('network');
        $network = $report->network;

        if (! $network instanceof WifiNetwork) {
            return;
        }

        $this->evaluateReportEscalation($network, $report);
    }

    private function notifyOwnerOfReport(WifiReport $report, WifiNetwork $network): void
    {
        $owner = $network->owner;
        $deadlineAt = data_get($report->meta, 'response_deadline_at');
        $deadlineText = $deadlineAt ? Carbon::parse($deadlineAt)->diffForHumans() : null;

        DB::afterCommit(function () use ($report, $network, $owner, $deadlineText): void {
            $body = __('تم استلام بلاغ جديد على شبكة :network بعنوان ":title".', [
                'network' => $network->name,
                'title' => $report->title,
            ]);

            if ($deadlineText) {
                $body .= ' ' . __('يرجى الرد خلال :deadline.', ['deadline' => $deadlineText]);
            }

            $tokens = $this->resolveOwnerFcmTokens($network);
            if ($tokens !== []) {
                NotificationService::sendFcmNotification(
                    $tokens,
                    __('بلاغ جديد على الشبكة'),
                    $body,
                    'wifi_report_created',
                    [
                        'wifi_network_id' => $network->getKey(),
                        'wifi_report_id' => $report->getKey(),
                    ]
                );
            }

            $numbers = $this->resolveNetworkPhoneNumbers($network);
            if ($owner && $owner->mobile) {
                $numbers[] = $this->formatPhoneNumber($owner);
            }

            foreach (array_unique(array_filter($numbers)) as $number) {
                $this->smsService->send($number, $body);
            }
        });
    }

    private function evaluateReportEscalation(WifiNetwork $network, ?WifiReport $latestReport = null): void
    {
        $threshold = (int) config('wifi.reports.auto_suspend_threshold', 0);
        $windowHours = max(1, (int) config('wifi.reports.auto_suspend_window_hours', 24));
        $now = Carbon::now();
        $since = $now->copy()->subHours($windowHours);

        $openReportsQuery = WifiReport::query()
            ->where('wifi_network_id', $network->getKey())
            ->whereIn('status', [
                WifiReportStatus::OPEN->value,
                WifiReportStatus::INVESTIGATING->value,
            ])
            ->where('created_at', '>=', $since);

        $openReportsCount = (clone $openReportsQuery)->count();

        $this->updateReputationCounter($network, $openReportsCount, $since, $now);

        if ($threshold > 0 && $openReportsCount >= $threshold) {
            $this->suspendNetworkForReports($network, $openReportsCount, $threshold, $latestReport);
        }
    }

    private function suspendNetworkForReports(
        WifiNetwork $network,
        int $openReportsCount,
        int $threshold,
        ?WifiReport $latestReport
    ): void {
        if ($network->status === WifiNetworkStatus::SUSPENDED) {
            return;
        }

        $network->status = WifiNetworkStatus::SUSPENDED;
        $meta = $network->meta ?? [];
        $meta = Arr::add($meta, 'auto_moderation', []);
        $meta['auto_moderation']['reason'] = 'reports_threshold';
        $meta['auto_moderation']['last_triggered_at'] = Carbon::now()->toIso8601String();
        $meta['auto_moderation']['open_reports'] = $openReportsCount;
        $meta['auto_moderation']['threshold'] = $threshold;
        if ($latestReport instanceof WifiReport) {
            $meta['auto_moderation']['last_report_id'] = $latestReport->getKey();
        }

        $network->meta = $meta;
        $network->save();

        DB::afterCommit(function () use ($network, $openReportsCount, $threshold): void {
            $message = __('تم إيقاف شبكة :network مؤقتًا بسبب :count بلاغات مفتوحة خلال الفترة الأخيرة.', [
                'network' => $network->name,
                'count' => $openReportsCount,
            ]);

            $tokens = $this->resolveOwnerFcmTokens($network);
            if ($tokens !== []) {
                NotificationService::sendFcmNotification(
                    $tokens,
                    __('تم إيقاف الشبكة تلقائيًا'),
                    $message,
                    'wifi_network_suspended',
                    [
                        'wifi_network_id' => $network->getKey(),
                        'open_reports' => $openReportsCount,
                        'threshold' => $threshold,
                    ]
                );
            }

            $numbers = $this->resolveNetworkPhoneNumbers($network);
            $owner = $network->owner;
            if ($owner && $owner->mobile) {
                $numbers[] = $this->formatPhoneNumber($owner);
            }

            foreach (array_unique(array_filter($numbers)) as $number) {
                $this->smsService->send($number, $message);
            }
        });
    }

    private function updateReputationCounter(WifiNetwork $network, int $openReportsCount, Carbon $since, Carbon $now): void
    {
        $periodStart = $since->copy()->startOfDay();
        $periodEnd = $now->copy()->endOfDay();

        $counter = ReputationCounter::query()
            ->where('wifi_network_id', $network->getKey())
            ->where('metric', 'reports_pending')
            ->whereDate('period_start', $periodStart)
            ->whereDate('period_end', $periodEnd)
            ->first();

        $referenceThreshold = max(1, (int) config('wifi.reports.auto_suspend_threshold', 1));
        $score = (int) min(100, round(($openReportsCount / $referenceThreshold) * 100));

        if (! $counter) {
            $counter = new ReputationCounter();
            $counter->wifi_network_id = $network->getKey();
            $counter->metric = 'reports_pending';
            $counter->period_start = $periodStart;
            $counter->period_end = $periodEnd;
        }

        $counter->score = $score;
        $counter->value = $openReportsCount;
        $counter->meta = array_replace($counter->meta ?? [], [
            'evaluated_at' => $now->toIso8601String(),
        ]);
        $counter->save();
    }

    /**
     * @return array<int, string>
     */
    private function resolveOwnerFcmTokens(WifiNetwork $network): array
    {
        $owner = $network->owner;

        if (! $owner instanceof User) {
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

    /**
     * @return array<int, string>
     */
    private function resolveNetworkPhoneNumbers(WifiNetwork $network): array
    {
        $contacts = $network->contacts;
        if (! is_iterable($contacts)) {
            return [];
        }

        $numbers = [];
        foreach ($contacts as $contact) {
            if (! is_array($contact)) {
                continue;
            }

            $type = Str::lower((string) ($contact['type'] ?? ''));
            $value = trim((string) ($contact['value'] ?? ''));

            if ($value === '') {
                continue;
            }

            if (in_array($type, ['phone', 'mobile', 'sms'], true)) {
                $numbers[] = $value;
            }
        }

        return $numbers;
    }

    private function formatPhoneNumber(User $user): string
    {
        $countryCode = trim((string) $user->country_code);
        $mobile = trim((string) $user->mobile);

        if ($mobile === '') {
            return '';
        }

        if ($countryCode !== '' && ! Str::startsWith($mobile, $countryCode)) {
            return $countryCode . $mobile;
        }

        return $mobile;
    }
}