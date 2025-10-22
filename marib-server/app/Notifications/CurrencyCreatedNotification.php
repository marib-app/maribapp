<?php

namespace App\Notifications;

use App\Notifications\Channels\FcmChannel;
use Illuminate\Bus\Queueable;
use Illuminate\Notifications\Notification;

class CurrencyCreatedNotification extends Notification
{
    use Queueable;

    public function __construct(
        private readonly int $currencyId,
        private readonly string $currencyName,
        private readonly int $defaultGovernorateId,
        private readonly ?string $defaultGovernorateName,
        private readonly ?string $sellPrice,
        private readonly ?string $buyPrice
    ) {
    }

    public function via(object $notifiable): array
    {
        return [FcmChannel::class];
    }

    public function toFcm(object $notifiable): array
    {
        $title = __('notifications.currency.created.title');

        $body = __('notifications.currency.created.body', [
            'currency' => $this->currencyName,
        ]);

        if ($this->defaultGovernorateName) {
            $body .= ' ' . __('notifications.currency.created.default_governorate', [
                'governorate' => $this->defaultGovernorateName,
            ]);
        }

        if ($this->sellPrice !== null || $this->buyPrice !== null) {
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
        }

        return [
            'title' => $title,
            'body' => $body,
            'type' => 'currency_created',
            'data' => [
                'currency_id' => $this->currencyId,
                'default_governorate_id' => $this->defaultGovernorateId,
            ],
        ];
    }
}