<?php

namespace App\Providers;



use App\Models\OrderItem;
use App\Observers\OrderItemObserver;
use App\Services\CacheMetricsRecorder;
use App\Services\Payment\GatewayLabelService;
use Illuminate\Support\Facades\Blade;
use Illuminate\Support\Facades\DB;
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

        Blade::directive('gatewayLabel', static function ($expression) {
            return sprintf(
                '<?php echo e(app(%s::class)->labelForRow(%s)); ?>',
                addslashes(GatewayLabelService::class),
                $expression
            );
        });

    }
}
