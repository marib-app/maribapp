<?php

namespace App\Console\Commands;

use App\Services\CurrencyRateHistoryService;
use Carbon\CarbonImmutable;
use Illuminate\Console\Command;

class CaptureCurrencyRateSnapshotsCommand extends Command
{
    protected $signature = 'currency:history-snapshot {--at=}';

    protected $description = 'Capture hourly snapshots for currency rates and refresh aggregates.';

    public function __construct(private readonly CurrencyRateHistoryService $historyService)
    {
        parent::__construct();
    }

    public function handle(): int
    {
        $at = $this->option('at');
        $timestamp = null;

        if (is_string($at) && $at !== '') {
            try {
                $timestamp = CarbonImmutable::parse($at);
            } catch (\Throwable $exception) {
                $this->error('Invalid --at timestamp provided.');
                return static::FAILURE;
            }
        }

        $this->historyService->snapshotQuotes($timestamp);

        $this->info('Currency rate history snapshot captured successfully.');

        return static::SUCCESS;
    }
}