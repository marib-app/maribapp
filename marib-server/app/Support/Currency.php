<?php

namespace App\Support;

final class Currency
{
    private const PREFERRED_SYMBOLS = [
        'YER' => 'ر.ي',
        'SAR' => 'ر.س',
        'USD' => 'أ.ر',
    ];

    private const SYMBOL_SYNONYMS = [
        'ر.ي' => 'YER',
        'ر.س' => 'SAR',
        'أ.ر' => 'USD',
    ];

    public static function preferredSymbol(?string $currency, ?string $fallback = null): ?string
    {
        $preferred = self::preferredSymbolOrNull($currency);
        if ($preferred !== null) {
            return $preferred;
        }

        $fallbackPreferred = self::preferredSymbolOrNull($fallback);
        if ($fallbackPreferred !== null) {
            return $fallbackPreferred;
        }

        $trimmed = self::trim($currency);
        if ($trimmed !== null) {
            return $trimmed;
        }

        $fallbackTrimmed = self::trim($fallback);
        if ($fallbackTrimmed !== null) {
            return $fallbackTrimmed;
        }

        return self::PREFERRED_SYMBOLS['YER'];
    }

    public static function normalize(?string $currency): ?string
    {
        return self::normalizeInternal($currency);
    }

    private static function preferredSymbolOrNull(?string $currency): ?string
    {
        $normalized = self::normalizeInternal($currency);
        if ($normalized === null) {
            return null;
        }

        return self::PREFERRED_SYMBOLS[$normalized] ?? null;
    }

    private static function normalizeInternal(?string $currency): ?string
    {
        $trimmed = self::trim($currency);
        if ($trimmed === null) {
            return null;
        }

        if (isset(self::SYMBOL_SYNONYMS[$trimmed])) {
            return self::SYMBOL_SYNONYMS[$trimmed];
        }

        $upper = strtoupper($trimmed);

        if (isset(self::PREFERRED_SYMBOLS[$upper])) {
            return $upper;
        }

        return null;
    }

    private static function trim(?string $value): ?string
    {
        if ($value === null) {
            return null;
        }

        $trimmed = trim($value);
        return $trimmed === '' ? null : $trimmed;
    }
}