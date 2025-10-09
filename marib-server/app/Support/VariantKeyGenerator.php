<?php

namespace App\Support;

class VariantKeyGenerator
{
    /**
     * @param array<string, mixed> $attributes
     */
    public static function fromAttributes(array $attributes): string
    {
        if ($attributes === []) {
            return '';
        }

        $normalized = [];
        foreach ($attributes as $key => $value) {
            $normalizedKey = self::normalizeScalar($key);
            $normalized[$normalizedKey] = self::canonicalizeValue($value);
        }

        ksort($normalized, SORT_STRING);

        $parts = [];
        foreach ($normalized as $key => $value) {
            $parts[] = sprintf('%s=%s', self::encodePart($key), self::encodePart($value));
        }

        return implode('|', $parts);
    }

    private static function canonicalizeValue(mixed $value): string
    {
        if (is_bool($value)) {
            return $value ? '1' : '0';
        }

        if (is_numeric($value)) {
            return (string) $value;
        }

        if (is_string($value)) {
            return trim($value);
        }

        if (is_array($value)) {
            if ($value === []) {
                return '';
            }

            if (array_is_list($value)) {
                $items = array_map(static fn ($item) => self::canonicalizeValue($item), $value);
                sort($items, SORT_STRING);

                return implode(',', $items);
            }

            $assoc = [];
            foreach ($value as $k => $v) {
                $assoc[self::normalizeScalar($k)] = self::canonicalizeValue($v);
            }
            ksort($assoc, SORT_STRING);

            $pairs = [];
            foreach ($assoc as $k => $v) {
                $pairs[] = sprintf('%s:%s', $k, $v);
            }

            return implode(',', $pairs);
        }

        if ($value === null) {
            return '';
        }

        return (string) $value;
    }

    private static function normalizeScalar(mixed $value): string
    {
        if (is_string($value)) {
            return trim($value);
        }

        if (is_numeric($value) || is_bool($value)) {
            return (string) $value;
        }

        return (string) json_encode($value, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    }

    private static function encodePart(string $value): string
    {
        return rawurlencode($value);
    }
}