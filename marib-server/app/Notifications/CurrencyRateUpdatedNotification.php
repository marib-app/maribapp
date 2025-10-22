<?php

namespace App\Notifications;

use App\Notifications\Channels\FcmChannel;
use Illuminate\Bus\Queueable;
use Illuminate\Notifications\Notification;

class CurrencyRateUpdatedNotification extends Notification
{
    use Queueable;

    public function __construct(
        public readonly int $currencyId,
        public readonly string $currencyName,
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
        $title = __('notifications.currency.updated.title');

        $governorateLabel = $this->governorateName
            ?: __('notifications.currency.updated.governorate_fallback');
        $body = __('notifications.currency.updated.body', [


            'currency' => $this->currencyName,
            'governorate' => $governorateLabel,
        ]);

        $priceSegments = [];

        if ($this->sellPrice !== null) {
            $priceSegments[] = __('notifications.currency.price.sell', ['value' => $this->sellPrice]);
        }

        if ($this->buyPrice !== null) {
            $priceSegments[] = __('notifications.currency.price.buy', ['value' => $this->buyPrice]);
        }

        if (!empty($priceSegments)) {
            $body .= ' ' . implode(' ', $priceSegments);
        }

        return [
            'title' => $title,
            'body' => $body,
            'type' => 'currency_rate_updated',
            'data' => [
                'currency_id' => $this->currencyId,
                'governorate_id' => $this->governorateId,
            ],
        ];
    }
}