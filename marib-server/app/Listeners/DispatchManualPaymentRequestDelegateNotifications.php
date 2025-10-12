<?php

namespace App\Listeners;

use App\Events\ManualPaymentRequestCreated;
use App\Jobs\SendManualPaymentRequestDelegateNotification;
use App\Models\ManualPaymentRequest;
use App\Models\ManualPaymentRequestHistory;

use App\Services\DelegateAuthorizationService;
use Illuminate\Support\Facades\Schema;

class DispatchManualPaymentRequestDelegateNotifications
{
    public function __construct(private readonly DelegateAuthorizationService $delegateAuthorizationService)
    {
    }

    public function handle(ManualPaymentRequestCreated $event): void
    {
        $manualPaymentRequest = $event->manualPaymentRequest;
        $department = $event->department();

        if ($department === null) {
            return;
        }

        $restrictedDepartments = $this->delegateAuthorizationService->getRestrictedDepartments();

        if ($restrictedDepartments === [] || ! in_array($department, $restrictedDepartments, true)) {
            return;
        }

        $delegateIds = $this->delegateAuthorizationService->getDelegatesForSection($department);

        if ($delegateIds === []) {
            return;
        }

        foreach ($delegateIds as $delegateId) {
            SendManualPaymentRequestDelegateNotification::dispatch(
                $manualPaymentRequest->getKey(),
                $delegateId,
                $department
            );
        }

        if (Schema::hasTable('manual_payment_request_histories')) {
            $status = is_string($manualPaymentRequest->status) && $manualPaymentRequest->status !== ''
                ? $manualPaymentRequest->status
                : ManualPaymentRequest::STATUS_PENDING;

            $orderId = ManualPaymentRequest::isOrderPayableType((string) $manualPaymentRequest->payable_type)
                ? $manualPaymentRequest->payable_id
                : null;


            ManualPaymentRequestHistory::create([
                'manual_payment_request_id' => $manualPaymentRequest->getKey(),
                'status' => $status,
                'meta' => [
                    'action' => 'delegate_notifications_dispatched',
                    'department' => $department,
                    'delegate_ids' => $delegateIds,
                    'order_id' => $orderId,


                ],
            ]);
        }
    }
}