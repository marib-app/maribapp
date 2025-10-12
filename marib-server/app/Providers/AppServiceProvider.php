<?php

namespace App\Providers;
use App\Models\OrderItem;
use App\Observers\OrderItemObserver;
use Illuminate\Support\Facades\DB;
use App\Services\CacheMetricsRecorder;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     *
     * @return void
     */
    public function register()
    {
        //
        $this->app->singleton(CacheMetricsRecorder::class);
    }

    /**
     * Bootstrap any application services.
     *
     * @return void
     */
    public function boot()
    {

        DB::connection()->getDoctrineSchemaManager()->getDatabasePlatform()->registerDoctrineTypeMapping('enum', 'string');
        Schema::defaultStringLength(191);


        OrderItem::observe(OrderItemObserver::class);
        
        $this->app->terminating(static function () {
            app(CacheMetricsRecorder::class)->flush();
        });
    }
}
