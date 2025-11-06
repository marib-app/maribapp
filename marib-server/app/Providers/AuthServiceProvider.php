<?php

namespace App\Providers;

use Illuminate\Foundation\Support\Providers\AuthServiceProvider as ServiceProvider;
use Illuminate\Support\Facades\Gate;
use App\Models\StoreGatewayAccount;
use App\Policies\SectionDelegatePolicy;
use App\Policies\StoreGatewayAccountPolicy;
use App\Models\Wifi\WifiNetwork;
use App\Models\Wifi\WifiPlan;
use App\Models\Wifi\WifiCodeBatch;
use App\Models\Wifi\WifiCode;
use App\Policies\Wifi\WifiNetworkPolicy;
use App\Policies\Wifi\WifiPlanPolicy;
use App\Policies\Wifi\WifiCodeBatchPolicy;
use App\Policies\Wifi\WifiCodePolicy;



class AuthServiceProvider extends ServiceProvider
{
    /**
     * The model to policy mappings for the application.
     *
     * @var array<class-string, class-string>
     */
    protected $policies = [
        StoreGatewayAccount::class => StoreGatewayAccountPolicy::class,
        WifiNetwork::class => WifiNetworkPolicy::class,
        WifiPlan::class => WifiPlanPolicy::class,
        WifiCodeBatch::class => WifiCodeBatchPolicy::class,
        WifiCode::class => WifiCodePolicy::class,
    ];

    /**
     * Register any authentication / authorization services.
     */
    public function boot(): void
    {
        $this->registerPolicies();

        // امنح كل الصلاحيات لأدوار الأدمن
        Gate::before(function ($user, $ability) {
            if (method_exists($user, 'hasAnyRole') &&
                $user->hasAnyRole(['admin', 'Admin', 'super-admin', 'Super Admin'])) {
                return true;
            }
            return null;
        });





        Gate::define('section.publish', [SectionDelegatePolicy::class, 'publish']);
        Gate::define('section.update', [SectionDelegatePolicy::class, 'update']);
        Gate::define('section.copy', [SectionDelegatePolicy::class, 'copy']);
        Gate::define('section.change', [SectionDelegatePolicy::class, 'changeSection']);
        Gate::define('section.batchImport', [SectionDelegatePolicy::class, 'batchImport']);

    }
}
