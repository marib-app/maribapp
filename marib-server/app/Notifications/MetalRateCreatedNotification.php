<?php

namespace App\Notifications;

use App\Notifications\Channels\FcmChannel;
use Illuminate\Bus\Queueable;
use Illuminate\Notifications\Notification;

class MetalRateCreatedNotification extends Notification
{
    use Queueable;

    public function __construct(
        public readonly int $metalId,
        public readonly string $metalName,
        public readonly int $governorateId,
        public readonly ?string $governorateName,
        public readonly ?string $sellPrice,
        public readonly ?string $buyPrice
    ) {
    }

    public function via(object $notifiable): array
    {
        return [FcmChannel::class];
    }

    public function toFcm(object $notifiable): array
    {
        $title = __('تم إضافة سعر جديد للمعدن');
        $governorateLabel = $this->governorateName ?: __('السوق الافتراضي');

        $body = __('تم تسجيل سعر :metal في :governorate.', [
            'metal' => $this->metalName,
            'governorate' => $governorateLabel,
        ]);

        $priceSegments = [];

        if ($this->sellPrice !== null) {
            $priceSegments[] = __('سعر البيع: :value', ['value' => $this->sellPrice]);
        }

        if ($this->buyPrice !== null) {
            $priceSegments[] = __('سعر الشراء: :value', ['value' => $this->buyPrice]);
        }

        if (!empty($priceSegments)) {
            $body .= ' ' . implode(' ', $priceSegments);
        }

        return [
            'title' => $title,
            'body' => $body,
            'type' => 'metal_rate_created',
            'data' => [
                'metal_id' => $this->metalId,
                'governorate_id' => $this->governorateId,
            ],
        ];
    }
}