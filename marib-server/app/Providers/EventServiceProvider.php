<?php

namespace App\Providers;

use App\Events\CompetitionAnnounced;
use App\Events\ManualPaymentRequestCreated;
use App\Events\OrderStatusChanged;
use App\Events\OrderNoteUpdated;
use App\Listeners\HandleMarketingAutomation;
use App\Listeners\RecordOrderStatusTelemetry;
use App\Listeners\SendOrderStatusChangedNotification;
use App\Listeners\DispatchManualPaymentRequestDelegateNotifications;
use App\Events\SubscriptionExpired;
use App\Listeners\SendDelegateAssignmentNotifications;
use App\Listeners\SendOrderNoteNotification;
use App\Events\UserWentInactive;
use Illuminate\Auth\Events\Registered;
use Illuminate\Auth\Listeners\SendEmailVerificationNotification;
use Illuminate\Foundation\Support\Providers\EventServiceProvider as ServiceProvider;
use App\Events\DelegateAssignmentsUpdated;
use App\Listeners\DispatchDelegateBadgeUpdate;

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
         DelegateAssignmentsUpdated::class => [
            SendDelegateAssignmentNotifications::class,
            DispatchDelegateBadgeUpdate::class,
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
