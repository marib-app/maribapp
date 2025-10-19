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
        $title = __('Currency rate updated');

        $governorateLabel = $this->governorateName ?: __('Selected region');
        $body = __('Updated :currency rates for :governorate.', [
            'currency' => $this->currencyName,
            'governorate' => $governorateLabel,
        ]);

        $priceSegments = [];

        if ($this->sellPrice !== null) {
            $priceSegments[] = __('Sell: :value', ['value' => $this->sellPrice]);
        }

        if ($this->buyPrice !== null) {
            $priceSegments[] = __('Buy: :value', ['value' => $this->buyPrice]);
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