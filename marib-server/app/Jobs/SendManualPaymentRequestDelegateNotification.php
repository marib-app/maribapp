<?php

namespace App\Jobs;

use App\Models\ManualPaymentRequest;
use App\Models\UserFcmToken;
use App\Services\NotificationService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

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
        $manualPaymentRequest = ManualPaymentRequest::query()->find($this->manualPaymentRequestId);

        if ($manualPaymentRequest === null) {
            return;
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

        $title = __('Manual payment request received');
        $body = __('A new manual payment request requires your review for the :department department.', [
            'department' => $this->department,
        ]);

        $payload = [
            'manual_payment_request_id' => $manualPaymentRequest->getKey(),
            'department' => $this->department,
            'status' => $manualPaymentRequest->status,
            'type' => 'manual_payment_request',
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
}