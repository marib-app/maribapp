<?php

namespace App\Console\Commands;

use App\Models\WalletUsageLimit;
use App\Models\WalletTransaction;
use Illuminate\Console\Command;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

class SyncWalletUsageLimitsCommand extends Command
{
    protected $signature = 'wallet:sync-usage-limits';

    protected $description = 'Synchronize wallet usage limits with existing transactions for the current day and month.';

    public function handle(): int
    {
        $now = Carbon::now();
        $dailyStart = $now->copy()->startOfDay();
        $dailyEnd = $dailyStart->copy()->addDay();
        $monthlyStart = $now->copy()->startOfMonth();
        $monthlyEnd = $monthlyStart->copy()->addMonth();

        DB::transaction(function () use ($dailyStart, $dailyEnd, $monthlyStart, $monthlyEnd) {
            $this->syncPeriod($dailyStart, $dailyEnd, 'daily');
            $this->syncPeriod($monthlyStart, $monthlyEnd, 'monthly');
        });

        $this->info('Wallet usage limits synchronized successfully.');

        return self::SUCCESS;
    }

    protected function syncPeriod(Carbon $periodStart, Carbon $periodEnd, string $period): void
    {
        $aggregates = WalletTransaction::query()
            ->select('wallet_account_id', 'type', DB::raw('SUM(amount) as total_amount'))
            ->where('created_at', '>=', $periodStart)
            ->where('created_at', '<', $periodEnd)
            ->groupBy('wallet_account_id', 'type')
            ->get()
            ->groupBy('wallet_account_id');

        foreach ($aggregates as $accountId => $rows) {
            $totals = [
                'credit' => 0.0,
                'debit' => 0.0,
            ];

            foreach ($rows as $row) {
                $totals[$row->type] = round((float) $row->total_amount, 2);
            }

            $usage = WalletUsageLimit::query()->firstOrNew([
                'wallet_account_id' => (int) $accountId,
                'period' => $period,
                'period_start' => $periodStart->toDateString(),
            ]);

            $usage->wallet_account_id = (int) $accountId;
            $usage->period = $period;
            $usage->period_start = $periodStart->copy();
            $usage->total_credit = $totals['credit'];
            $usage->total_debit = $totals['debit'];

            $usage->save();
        }
    }
}