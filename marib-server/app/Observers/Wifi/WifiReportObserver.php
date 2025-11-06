<?php

namespace App\Observers\Wifi;

use App\Models\Wifi\WifiReport;
use App\Services\Wifi\WifiOperationalService;
use Carbon\Carbon;

class WifiReportObserver
{
    public function creating(WifiReport $report): void
    {
        if ($report->reported_at === null) {
            $report->reported_at = Carbon::now();
        }

        $meta = $report->meta ?? [];
        if (! array_key_exists('response_deadline_at', $meta)) {
            $deadlineHours = (int) config('wifi.reports.response_deadline_hours', 0);
            if ($deadlineHours > 0) {
                $meta['response_deadline_at'] = Carbon::now()->addHours($deadlineHours)->toIso8601String();
            }
        }

        $report->meta = $meta;
    }

    public function created(WifiReport $report): void
    {
        app(WifiOperationalService::class)->handleReportCreated($report);
    }

    public function updated(WifiReport $report): void
    {
        app(WifiOperationalService::class)->handleReportUpdated($report);
    }
}