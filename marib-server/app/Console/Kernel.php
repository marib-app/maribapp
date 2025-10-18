<?php

namespace App\Console;


use App\Services\CurrencyDataMonitor;
use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Foundation\Console\Kernel as ConsoleKernel;

class Kernel extends ConsoleKernel
{
    protected $commands = [
        \App\Console\Commands\CustomAutoTranslate::class,
        \App\Console\Commands\CustomTranslateMissing::class,

        \App\Console\Commands\MigrateChatData::class,
        \App\Console\Commands\SyncWalletUsageLimitsCommand::class,
        \App\Console\Commands\OrdersSettlementReminder::class,
        \App\Console\Commands\SyncServiceCustomFieldLabelsCommand::class,
        \App\Console\Commands\PruneStaleUserFcmTokens::class,
        \App\Console\Commands\CaptureCurrencyRateSnapshotsCommand::class,
        \App\Console\Commands\NormalizeOrderPaymentMethodsCommand::class,

    ];
    /**
     * Define the application's command schedule.
     *
     * @param  \Illuminate\Console\Scheduling\Schedule  $schedule
     * @return void
     */
    protected function schedule(Schedule $schedule)
    {
        $schedule->command('orders:settlement-reminder')
            ->hourly()
            ->withoutOverlapping();

            
        $schedule->command('fcm:prune-tokens')
            ->dailyAt('03:00')
            ->withoutOverlapping();

        $schedule->command('currency:history-snapshot')
            ->hourly()
            ->withoutOverlapping();

        $schedule->call(static function () {
            app(CurrencyDataMonitor::class)->checkHistoricalSnapshots();
        })
            ->name('currency-data-monitor')
            ->everyFifteenMinutes()
            ->withoutOverlapping();

            
    }

    /**
     * Register the commands for the application.
     *
     * @return void
     */
    protected function commands()
    {
        $this->load(__DIR__.'/Commands');

        require base_path('routes/console.php');

    }



}
