<?php

namespace App\Support\Payments;

class PaymentGatewayCurrencyPolicy
{
    /**
     * @var array<string, array<int, string>>
     */
    private const SUPPORTED = [
        'manual_bank' => ['USD', 'YER'],
        'east_yemen_bank' => ['YER'],
        'bank_alsharq' => ['YER'],
        'wallet' => ['YER'],
        'cash' => ['YER'],
    ];

    public static function supports(?string $gateway, ?string $currency): bool
    {
        if ($gateway === null || $currency === null) {
            return false;
        }

        $normalizedGateway = mb_strtolower(trim($gateway));
        $normalizedCurrency = strtoupper(trim($currency));

        if ($normalizedGateway === '' || $normalizedCurrency === '') {
            return false;
        }

        /** @var array<int, string>|null $supported */
        $supported = self::SUPPORTED[$normalizedGateway] ?? null;

        if ($supported === null) {
            return true;
        }

        return in_array($normalizedCurrency, $supported, true);
    }

    /**
     * @return array<int, string>
     */
    public static function supportedCurrencies(string $gateway): array
    {
        $normalizedGateway = mb_strtolower(trim($gateway));

        if ($normalizedGateway === '') {
            return [];
        }

        return self::SUPPORTED[$normalizedGateway] ?? [];
    }
}

