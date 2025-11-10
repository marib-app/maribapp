<?php

namespace App\Providers;



use App\Models\OrderItem;
use App\Models\Wifi\WifiReport;
use App\Observers\OrderItemObserver;
use App\Observers\Wifi\WifiReportObserver;
use App\Services\CacheMetricsRecorder;
use App\Services\Payments\GatewayLabelService;
use Illuminate\Filesystem\Filesystem;
use Illuminate\Pagination\Paginator;
use Illuminate\Support\Facades\Blade;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\ServiceProvider;
use Throwable;

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
        Paginator::useBootstrapFive();

        $this->registerEnumTypeMapping();

        Schema::defaultStringLength(191);


        OrderItem::observe(OrderItemObserver::class);
        WifiReport::observe(WifiReportObserver::class);
        
        
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


        $this->ensurePublicStorageSymlink();

    }


    private function registerEnumTypeMapping(): void
    {
        try {
            DB::connection()
                ->getDoctrineSchemaManager()
                ->getDatabasePlatform()
                ->registerDoctrineTypeMapping('enum', 'string');
        } catch (Throwable $exception) {
            Log::warning('Failed to register Doctrine enum mapping', [
                'exception' => $exception->getMessage(),
            ]);
        }
    }



    private function ensurePublicStorageSymlink(): void
    {
        $storageDirectory = storage_path('app/public');
        $publicLink = public_path('storage');

        if (!is_dir($storageDirectory) || file_exists($publicLink)) {
            return;
        }

        try {
            /** @var Filesystem $filesystem */
            $filesystem = $this->app->make(Filesystem::class);
            $filesystem->link($storageDirectory, $publicLink);
        } catch (Throwable $exception) {
            Log::warning('Failed to create public storage symlink', [
                'link' => $publicLink,
                'target' => $storageDirectory,
                'exception' => $exception->getMessage(),
            ]);
        }

    }
}
