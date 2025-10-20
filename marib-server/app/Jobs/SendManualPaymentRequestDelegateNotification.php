<?php

namespace App\Jobs;

use App\Models\ManualPaymentRequest;
use App\Models\Order;
use App\Models\UserFcmToken;
use App\Services\NotificationService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Illuminate\Support\Facades\Route;

class SendManualPaymentRequestDelegateNotification implements ShouldQueue
{
    use Dispatchable;
    use InteractsWithQueue;
    use Queueable;
    use SerializesModels;

    public function __construct(
        public int $manualPaymentRequestId,
        public int $delegateId,
        public string $department
    ) {
    }

    public function handle(): void
    {
        $manualPaymentRequest = ManualPaymentRequest::query()
            ->with('payable')
            ->find($this->manualPaymentRequestId);


        if ($manualPaymentRequest === null) {
            return;
        }

        $orderId = null;
        $orderReference = null;

        if (ManualPaymentRequest::isOrderPayableType((string) $manualPaymentRequest->payable_type)) {
            $orderId = $manualPaymentRequest->payable_id ? (int) $manualPaymentRequest->payable_id : null;

            $payable = $manualPaymentRequest->payable;

            if ($payable instanceof Order) {
                $orderReference = $payable->order_number
                    ?: $payable->invoice_no
                    ?: (string) $payable->getKey();
            } elseif ($orderId !== null) {
                $orderReference = (string) $orderId;
            }
        }

        if ($orderReference === null) {
            $orderReference = (string) $manualPaymentRequest->getKey();
        }

        $orderReference = trim($orderReference);

        if ($orderReference === '') {
            $orderReference = (string) $manualPaymentRequest->getKey();
        }

        if (! Str::startsWith($orderReference, '#')) {
            $orderReference = '#' . ltrim($orderReference, '#');
        }



        $tokens = UserFcmToken::query()
            ->where('user_id', $this->delegateId)
            ->pluck('fcm_token')
            ->filter()
            ->unique()
            ->values()
            ->all();

        if ($tokens === []) {
            return;
        }

        $departmentLabel = trans('departments.' . $this->department, [], 'ar');

        if ($departmentLabel === 'departments.' . $this->department) {
            $departmentLabel = $this->department;
        }

        $title = 'طلب شراء جديد يحتاج إلى مراجعة';
        $body = sprintf(
            'لديك طلب شراء في قسم %s رقم الطلب %s يحتاج إلى مراجعة.',
            $departmentLabel,
            $orderReference
        );

        $reviewUrl = $this->resolveManualPaymentReviewUrl($manualPaymentRequest);
        $ordersIndexUrl = $this->resolveOrdersIndexUrl();
        $deeplink = $ordersIndexUrl ?? $reviewUrl ?? '#';


        $payload = [
            'manual_payment_request_id' => $manualPaymentRequest->getKey(),
            'department' => $this->department,
            'status' => $manualPaymentRequest->status,
            'type' => 'manual_payment_request',
            'order_id' => $orderId,
            'order_reference' => $orderReference,
            'deeplink' => $deeplink,
            'click_action' => $deeplink,
            'manual_payment_review_url' => $reviewUrl,

            'message_preview' => $body,

        ];

        try {
            NotificationService::sendFcmNotification(
                $tokens,
                $title,
                $body,
                'manual_payment_request',
                $payload
            );
        } catch (\Throwable $exception) {
            Log::warning('manual_payment.delegate_notification_failed', [
                'manual_payment_request_id' => $manualPaymentRequest->getKey(),
                'delegate_id' => $this->delegateId,
                'error' => $exception->getMessage(),
            ]);
        }
    }



    private function resolveOrdersIndexUrl(): ?string
    {
        if (Route::has('orders.index')) {
            return route('orders.index', ['department' => $this->department]);
        }

        if (Route::has('orders')) {
            try {
                return route('orders', ['department' => $this->department]);
            } catch (\Throwable) {
                // Fallback handled below.
            }
        }

        return null;
    }

    private function resolveManualPaymentReviewUrl(ManualPaymentRequest $manualPaymentRequest): ?string
    {
        if (! Route::has('payment-requests.review')) {
            return null;
        }

        try {
            return route('payment-requests.review', $manualPaymentRequest);
        } catch (\Throwable) {
            return null;
        }
    }
}
