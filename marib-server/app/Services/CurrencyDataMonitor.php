<?php

namespace App\Services;

use App\Models\AdminNotification;
use App\Models\CurrencyRate;
use Carbon\Carbon;
use Carbon\CarbonInterface;
use Illuminate\Support\Facades\Log;

class CurrencyDataMonitor
{
    public function __construct(
        private readonly CurrencyRateHistoryService $historyService
    ) {
    }

    public function inspectCurrency(CurrencyRate $currency, ?CarbonInterface $capturedAt, string $sourceQuality): void
    {
        $severity = $this->resolveSeverity($capturedAt, $sourceQuality);

        if ($severity === null) {
            $this->resolveAlert($currency);

            return;
        }

        $this->sendAlert($currency, $capturedAt, $sourceQuality, $severity);
    }

    public function checkHistoricalSnapshots(): void
    {
        $currencies = CurrencyRate::query()
            ->with(['hourlyHistories' => static function ($query) {
                $query->orderByDesc('captured_at')
                    ->orderByDesc('hour_start')
                    ->limit(1);
            }])
            ->get();

        foreach ($currencies as $currency) {
            $latestHistory = $currency->hourlyHistories->first();
            $capturedAt = $latestHistory?->captured_at ?? $latestHistory?->hour_start;
            $sourceQuality = $this->historyService->determineSourceQuality($capturedAt);

            $this->inspectCurrency($currency, $capturedAt, $sourceQuality);
        }
    }

    private function resolveSeverity(?CarbonInterface $capturedAt, string $sourceQuality): ?string
    {
        $qualitySeverity = $this->severityFromQuality($sourceQuality);
        $freshnessSeverity = $this->severityFromAge($capturedAt);

        return $this->pickHighestSeverity($qualitySeverity, $freshnessSeverity);
    }

    private function severityFromQuality(string $sourceQuality): ?string
    {
        $qualityKey = strtolower($sourceQuality);
        $mapping = config('currency-monitor.quality_alerts', []);

        return $mapping[$qualityKey] ?? null;
    }

    private function severityFromAge(?CarbonInterface $capturedAt): ?string
    {
        $warningHours = (int) config('currency-monitor.freshness.warning_hours', 3);
        $criticalHours = (int) config('currency-monitor.freshness.critical_hours', 12);

        if ($criticalHours < $warningHours) {
            $criticalHours = $warningHours;
        }

        if ($capturedAt === null) {
            return 'critical';
        }

        $ageHours = $capturedAt->diffInHours($this->now());

        if ($ageHours >= $criticalHours) {
            return 'critical';
        }

        if ($ageHours >= $warningHours) {
            return 'warning';
        }

        return null;
    }

    private function pickHighestSeverity(?string ...$severities): ?string
    {
        $rank = [
            'warning' => 1,
            'critical' => 2,
        ];

        $selected = null;
        $selectedRank = 0;

        foreach ($severities as $severity) {
            if ($severity === null) {
                continue;
            }

            $currentRank = $rank[$severity] ?? 0;

            if ($currentRank > $selectedRank) {
                $selectedRank = $currentRank;
                $selected = $severity;
            }
        }

        return $selected;
    }

    private function sendAlert(
        CurrencyRate $currency,
        ?CarbonInterface $capturedAt,
        string $sourceQuality,
        string $severity
    ): void {
        if (!(config('currency-monitor.channels.admin_notification', true))) {
            return;
        }

        $now = $this->now();
        $ageMinutes = $capturedAt ? $capturedAt->diffInMinutes($now) : null;

        $title = match ($severity) {
            'critical' => sprintf('Currency data is stale for %s', $currency->currency_name),
            default => sprintf('Currency data warning for %s', $currency->currency_name),
        };

        $meta = array_filter([
            'severity' => $severity,
            'source_quality' => $sourceQuality,
            'captured_at' => $capturedAt?->toIso8601String(),
            'age_minutes' => $ageMinutes,
        ], static fn ($value) => $value !== null);

        $notification = AdminNotification::storePendingFor(
            $currency,
            AdminNotification::TYPE_CURRENCY_DATA_ALERT,
            $title,
            null,
            $meta
        );

        if (!($notification->wasRecentlyCreated || $notification->wasChanged())) {
            return;
        }

        Log::warning('CurrencyDataMonitor: currency data alert dispatched', [
            'currency_id' => $currency->getKey(),
            'severity' => $severity,
            'source_quality' => $sourceQuality,
            'captured_at' => $capturedAt?->toIso8601String(),
        ]);
    }

    private function resolveAlert(CurrencyRate $currency): void
    {
        if (!(config('currency-monitor.channels.admin_notification', true))) {
            return;
        }

        $notification = AdminNotification::resolveFor($currency, AdminNotification::TYPE_CURRENCY_DATA_ALERT);

        if ($notification && $notification->wasChanged()) {
            Log::info('CurrencyDataMonitor: currency data alert resolved', [
                'currency_id' => $currency->getKey(),
            ]);
        }
    }

    private function now(): CarbonInterface
    {
        return Carbon::now();
    }
}