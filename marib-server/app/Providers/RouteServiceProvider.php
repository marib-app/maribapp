<?php

namespace App\Providers;

use App\Models\User;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Foundation\Support\Providers\RouteServiceProvider as ServiceProvider;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Facades\Route;

class RouteServiceProvider extends ServiceProvider {
    /**
     * The path to the "home" route for your application.
     *
     * Typically, users are redirected here after authentication.
     *
     * @var string
     */
    public const HOME = '/home';

    /**
     * Determine the correct home path for a given user.
     */
    public static function resolveHomePath(?User $user): string {
        if ($user && $user->account_type === User::ACCOUNT_TYPE_SELLER) {
            return route('merchant.dashboard');
        }

        return static::HOME;
    }

    /**
     * Define your route model bindings, pattern filters, and other route configuration.
     *
     * @return void
     */
    public function boot() {
        $this->configureRateLimiting();

        $this->routes(function () {
            Route::middleware('api')
                ->prefix('api')
                ->group(base_path('routes/api.php'));

            Route::middleware('web')
                ->group(base_path('routes/web.php'));
        });
    }

    /**
     * Configure the rate limiters for the application.
     *
     * @return void
     */
    protected function configureRateLimiting() {
        RateLimiter::for('api', static function (Request $request) {
            return Limit::perMinute(180)->by($request->user()?->id ?: $request->ip());
        });

        RateLimiter::for('cart-shipping-quote', static function (Request $request) {
            return Limit::perMinute(15)->by($request->user()?->id ?: $request->ip());
        });

        RateLimiter::for('payments-initiate', static function (Request $request) {
            $purpose = strtolower((string) $request->input('purpose', 'general'));
            $subject = $request->input('wifi_plan_id')
                ?? $request->input('service_request_id')
                ?? $request->input('service_id')
                ?? $request->input('order_id')
                ?? $request->input('package_id')
                ?? 'general';

            $key = implode('|', [
                $request->user()?->getAuthIdentifier() ?: $request->ip(),
                $purpose,
                $subject,
            ]);

            return Limit::perMinute(60)->by($key);
        });
    }
}
