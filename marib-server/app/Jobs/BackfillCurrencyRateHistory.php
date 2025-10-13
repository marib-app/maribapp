<?php

namespace App\Jobs;

use App\Services\CurrencyRateHistoryService;
use Carbon\CarbonInterface;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

class BackfillCurrencyRateHistory implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public function __construct(
        private readonly CarbonInterface $startDate,
        private readonly CarbonInterface $endDate,
        private readonly ?int $currencyRateId = null,
        private readonly ?int $governorateId = null,
    ) {
    }

    public function handle(CurrencyRateHistoryService $historyService): void
    {
        $historyService->rebuildDailyAggregates(
            $this->startDate,
            $this->endDate,
            $this->currencyRateId,
            $this->governorateId
        );
    }
}