<?php

namespace App\Providers;

use App\Events\CurrencyRatesUpdated;
use App\Listeners\SendCurrencyRatesUpdatedNotification;
use App\Events\CompetitionAnnounced;
use App\Events\CurrencyCreated;
use App\Events\ManualPaymentRequestCreated;
use App\Events\MetalRateCreated;
use App\Events\MetalRateUpdated;
use App\Events\OrderStatusChanged;
use App\Events\OrderNoteUpdated;
use App\Events\SubscriptionExpired;
use App\Events\UserWentInactive;
use App\Listeners\DispatchDelegateBadgeUpdate;
use App\Listeners\DispatchManualPaymentRequestDelegateNotifications;
use App\Listeners\HandleMarketingAutomation;
use App\Listeners\SendCurrencyCreatedNotification;
use App\Listeners\RecordCacheTelemetry;
use Illuminate\Cache\Events\CacheHit;
use Illuminate\Cache\Events\CacheMissed;
use App\Listeners\RecordOrderStatusTelemetry;
use App\Listeners\SendOrderStatusChangedNotification;
use App\Listeners\SendDelegateAssignmentNotifications;
use App\Listeners\SendOrderNoteNotification;
use App\Listeners\SendMetalRateCreatedNotification;
use App\Listeners\SendMetalRateUpdatedNotification;
use Illuminate\Auth\Events\Registered;
use Illuminate\Auth\Listeners\SendEmailVerificationNotification;
use Illuminate\Foundation\Support\Providers\EventServiceProvider as ServiceProvider;
use App\Events\DelegateAssignmentsUpdated;

class EventServiceProvider extends ServiceProvider
{

    /**
     * The event to listener mappings for the application.
     *
     * @var array<class-string, array<int, class-string>>
     */
    protected $listen = [
        Registered::class => [
            SendEmailVerificationNotification::class,
        ],


        UserWentInactive::class => [
            HandleMarketingAutomation::class,
        ],
        SubscriptionExpired::class => [
            HandleMarketingAutomation::class,
        ],
        CompetitionAnnounced::class => [
            HandleMarketingAutomation::class,
        ],


        OrderStatusChanged::class => [
            SendOrderStatusChangedNotification::class,
            RecordOrderStatusTelemetry::class,
        ],
        OrderNoteUpdated::class => [
            SendOrderNoteNotification::class,
        ],
        ManualPaymentRequestCreated::class => [
            DispatchManualPaymentRequestDelegateNotifications::class,
        ],

        CurrencyCreated::class => [
            SendCurrencyCreatedNotification::class,
        ],
        CurrencyRatesUpdated::class => [
            SendCurrencyRatesUpdatedNotification::class,
        ],


        MetalRateCreated::class => [
            SendMetalRateCreatedNotification::class,
        ],

        MetalRateUpdated::class => [
            SendMetalRateUpdatedNotification::class,
        ],



        DelegateAssignmentsUpdated::class => [
            
            SendDelegateAssignmentNotifications::class,
            DispatchDelegateBadgeUpdate::class,
        ],

        CacheHit::class => [
            RecordCacheTelemetry::class,
        ],

        CacheMissed::class => [
            RecordCacheTelemetry::class,
        ],



    ];

    public function boot(): void
    {


        //
    }

    public function shouldDiscoverEvents(): bool
    {

        
        return false;
    }
}
