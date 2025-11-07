<?php

namespace App\Services\Store;

use App\Models\Store;
use App\Models\StoreSetting;
use App\Models\StoreWorkingHour;
use Carbon\Carbon;
use Illuminate\Support\Collection;

class StoreStatusService
{
    public function resolve(Store $store, ?Carbon $reference = null): array
    {
        $store->loadMissing(['settings', 'workingHours']);

        $settings = $store->settings;
        $timezone = $store->timezone ?: config('app.timezone', 'UTC');
        $now = ($reference ? $reference->copy() : Carbon::now())->setTimezone($timezone);

        $manualClosureEndsAt = $settings?->manual_closure_expires_at
            ? Carbon::parse($settings->manual_closure_expires_at)->setTimezone($timezone)
            : null;

        $manualClosureActive = (bool) ($settings?->is_manually_closed ?? false);

        if ($manualClosureActive && $manualClosureEndsAt && $manualClosureEndsAt->isPast()) {
            $manualClosureActive = false;
        }

        $workingHours = $store->workingHours ?? collect();
        $statusWindow = $this->resolveWorkingHourState(
            $workingHours,
            $now,
            $manualClosureActive,
            $manualClosureEndsAt
        );

        $closureMode = $settings?->closure_mode ?? 'full';

        return [
            'status' => $store->status,
            'is_open_now' => $statusWindow['is_open'],
            'today_schedule' => [
                'is_open' => $statusWindow['today']['is_open'],
                'opens_at' => $statusWindow['today']['opens_at'],
                'closes_at' => $statusWindow['today']['closes_at'],
            ],
            'next_open_at' => $statusWindow['next_open_at'],
            'is_manually_closed' => $manualClosureActive,
            'manual_closure_expires_at' => $manualClosureEndsAt?->toIso8601String(),
            'closure_mode' => $closureMode,
            'closure_reason' => $settings?->manual_closure_reason,
            'min_order_amount' => $settings?->min_order_amount,
            'allow_delivery' => (bool) ($settings?->allow_delivery ?? true),
            'allow_pickup' => (bool) ($settings?->allow_pickup ?? true),
            'allow_manual_payments' => (bool) ($settings?->allow_manual_payments ?? true),
            'allow_wallet' => (bool) ($settings?->allow_wallet ?? false),
            'allow_cod' => (bool) ($settings?->allow_cod ?? false),
            'checkout_notice' => $settings?->checkout_notice,
        ];
    }

    /**
     * @param Collection<int, StoreWorkingHour> $workingHours
     * @return array{is_open: bool, today: array{is_open: bool, opens_at: ?string, closes_at: ?string}, next_open_at: ?string}
     */
    private function resolveWorkingHourState(
        Collection $workingHours,
        Carbon $now,
        bool $forceClosed,
        ?Carbon $manualClosureEndsAt
    ): array {
        $todayWindow = $this->normalizeWorkingWindow($workingHours, $now->dayOfWeek, $now);
        $isOpen = false;

        if (! $forceClosed && $todayWindow !== null) {
            $start = $todayWindow['opens_at'];
            $end = $todayWindow['closes_at'];
            $isOpen = $now->greaterThanOrEqualTo($start) && $now->lessThan($end);
        }

        $reference = $isOpen ? $now->copy()->addMinute() : $now;

        if ($forceClosed && $manualClosureEndsAt && $manualClosureEndsAt->greaterThan($reference)) {
            $reference = $manualClosureEndsAt->copy()->addMinute();
        }

        $nextOpen = $forceClosed && ! $manualClosureEndsAt
            ? null
            : $this->findNextOpenWindow($workingHours, $reference);

        return [
            'is_open' => $isOpen && ! $forceClosed,
            'today' => $todayWindow ? [
                'is_open' => true,
                'opens_at' => $todayWindow['opens_at']->toTimeString(),
                'closes_at' => $todayWindow['closes_at']->toTimeString(),
            ] : [
                'is_open' => false,
                'opens_at' => null,
                'closes_at' => null,
            ],
            'next_open_at' => $nextOpen?->toIso8601String(),
        ];
    }

    /**
     * @param Collection<int, StoreWorkingHour> $workingHours
     * @return array{opens_at: Carbon, closes_at: Carbon}|null
     */
    private function normalizeWorkingWindow(Collection $workingHours, int $weekday, Carbon $reference): ?array
    {
        /** @var StoreWorkingHour|null $entry */
        $entry = $workingHours->firstWhere('weekday', $weekday);

        if (! $entry || ! $entry->is_open || ! $entry->opens_at || ! $entry->closes_at) {
            return null;
        }

        $open = $this->parseLocalTime($entry->opens_at, $reference);
        $close = $this->parseLocalTime($entry->closes_at, $reference);

        if (! $open || ! $close) {
            return null;
        }

        if ($close->lessThanOrEqualTo($open)) {
            $close->addDay();
        }

        return [
            'opens_at' => $open,
            'closes_at' => $close,
        ];
    }

    private function parseLocalTime(string $time, Carbon $reference): ?Carbon
    {
        $formats = ['H:i:s', 'H:i'];

        foreach ($formats as $format) {
            try {
                $parsed = Carbon::createFromFormat($format, $time, $reference->timezone);

                if ($parsed !== false) {
                    return $parsed->setDate(
                        $reference->year,
                        $reference->month,
                        $reference->day
                    );
                }
            } catch (\Throwable) {
                continue;
            }
        }

        return null;
    }

    /**
     * @param Collection<int, StoreWorkingHour> $workingHours
     */
    private function findNextOpenWindow(Collection $workingHours, Carbon $start): ?Carbon
    {
        $candidate = $start->copy();

        for ($i = 0; $i < 8; $i++) {
            $window = $this->normalizeWorkingWindow($workingHours, $candidate->dayOfWeek, $candidate);

            if ($window && $window['opens_at']->greaterThan($start)) {
                return $window['opens_at'];
            }

            $candidate->addDay()->startOfDay();
        }

        return null;
    }
}
