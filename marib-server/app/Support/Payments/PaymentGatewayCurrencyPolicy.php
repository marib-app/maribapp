<?php

namespace App\Support\Payments;

use App\Models\ManualPaymentRequest;
use App\Services\OrderCheckoutService;
use Illuminate\Support\Str;

class PaymentGatewayCurrencyPolicy
{
    /**
     * @var array<string, array<int, string>>
     */
    private const SUPPORTED = [
        'manual_bank' => ['USD', 'YER'],
        'east_yemen_bank' => ['YER'],
        'wallet' => ['YER'],
        'cash' => ['YER'],
    ];

    public static function supports(?string $gateway, ?string $currency): bool
    {
        $normalizedGateway = self::normalizeGateway($gateway);
        $normalizedCurrency = self::normalizeCurrency($currency);

        if ($normalizedGateway === null || $normalizedCurrency === null) {
            return false;
        }

        $supported = self::SUPPORTED[$normalizedGateway] ?? null;

        if ($supported === null) {
            return false;
        }

        return in_array($normalizedCurrency, $supported, true);
    }

    /**
     * @return array<int, string>
     */
    public static function supportedCurrencies(string $gateway): array
    {
        $normalizedGateway = self::normalizeGateway($gateway);

        if ($normalizedGateway === null) {
            return [];
        }

        return self::SUPPORTED[$normalizedGateway] ?? [];
    }

    private static function normalizeGateway(?string $gateway): ?string
    {
        if (! is_string($gateway)) {
            return null;
        }

        $candidate = OrderCheckoutService::normalizePaymentMethod($gateway);

        if ($candidate === null) {
            $candidate = ManualPaymentRequest::canonicalGateway($gateway);
        } else {
            $candidate = ManualPaymentRequest::canonicalGateway($candidate) ?? $candidate;
        }

        if ($candidate === null || trim($candidate) === '') {
            return null;
        }

        $candidate = Str::lower(trim($candidate));

        return match ($candidate) {
            'manual_banks' => 'manual_bank',
            'bank_alsharq' => 'east_yemen_bank',
            default => $candidate,
        };
    }

    private static function normalizeCurrency(?string $currency): ?string
    {
        if (! is_string($currency)) {
            return null;
        }

        $normalized = strtoupper(trim($currency));

        return $normalized === '' ? null : $normalized;
    }
}
