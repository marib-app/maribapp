<?php

namespace App\Support;

use JsonSerializable;
use stdClass;
use Throwable;

class ColorFieldParser
{
    public static function parse(mixed $source): array
    {
        if ($source === null) {
            return [];
        }

        $data = $source;

        if (is_string($source)) {
            $trimmed = trim($source);
            if ($trimmed === '') {
                return [];
            }

            if (self::looksLikeJson($trimmed)) {
                try {
                    $decoded = json_decode($trimmed, true, 512, JSON_THROW_ON_ERROR);
                    $data = $decoded;
                } catch (Throwable) {
                    $hex = self::sanitizeHex($trimmed);
                    return $hex === null ? [] : [['code' => $hex]];
                }
            } else {
                $hex = self::sanitizeHex($trimmed);
                return $hex === null ? [] : [['code' => $hex]];
            }
        }

        if ($data instanceof JsonSerializable) {
            $data = $data->jsonSerialize();
        }

        if ($data instanceof stdClass) {
            $data = (array) $data;
        }

        $entries = [];

        $walker = function ($value) use (&$walker, &$entries): void {
            if ($value === null) {
                return;
            }

            if ($value instanceof JsonSerializable) {
                $walker($value->jsonSerialize());
                return;
            }

            if ($value instanceof stdClass) {
                $walker((array) $value);
                return;
            }

            if (is_string($value) || is_numeric($value)) {
                $hex = self::sanitizeHex((string) $value);
                if ($hex !== null) {
                    self::storeEntry($entries, $hex, null);
                }
                return;
            }

            if (is_array($value)) {
                if (! array_is_list($value)) {
                    self::parseAssocArray($value, $entries, $walker);
                    return;
                }

                foreach ($value as $item) {
                    $walker($item);
                }
            }
        };

        $walker($data);

        return array_values($entries);
    }

    public static function labels(array $entries): array
    {
        $labels = [];
        foreach ($entries as $entry) {
            $code = isset($entry['code']) ? strtoupper((string) $entry['code']) : null;
            if ($code === null || self::sanitizeHex($code) === null) {
                continue;
            }

            $label = '#' . $code;
            if (isset($entry['quantity'])) {
                $quantity = self::normalizeQuantity($entry['quantity']);
                if ($quantity !== null && $quantity > 0) {
                    $label .= ' × ' . $quantity;
                }
            }

            $labels[] = $label;
        }

        return $labels;
    }

    public static function normalizeCode(mixed $value): ?string
    {
        if ($value === null) {
            return null;
        }

        if (is_string($value) || is_numeric($value)) {
            return self::sanitizeHex((string) $value);
        }

        if ($value instanceof JsonSerializable) {
            return self::normalizeCode($value->jsonSerialize());
        }

        if ($value instanceof stdClass) {
            return self::normalizeCode((array) $value);
        }

        if (is_array($value)) {
            if (isset($value['code'])) {
                return self::sanitizeHex((string) $value['code']);
            }

            if (isset($value['value'])) {
                return self::sanitizeHex((string) $value['value']);
            }

            $first = reset($value);
            if ($first !== false) {
                return self::normalizeCode($first);
            }
        }

        return null;
    }

    private static function parseAssocArray(array $value, array &$entries, callable $walker): void
    {
        $code = null;
        $quantity = null;

        foreach (['code', 'hex', 'color', 'value'] as $key) {
            if (array_key_exists($key, $value)) {
                $candidate = self::sanitizeHex((string) $value[$key]);
                if ($candidate !== null) {
                    $code = $candidate;
                    break;
                }
            }
        }

        if ($code === null) {
            foreach ($value as $key => $val) {
                $candidate = self::sanitizeHex((string) $key);
                if ($candidate !== null) {
                    $code = $candidate;
                    $quantity = self::normalizeQuantity($val);
                    break;
                }
            }
        }

        if ($code === null) {
            foreach ($value as $val) {
                if (is_scalar($val)) {
                    $candidate = self::sanitizeHex((string) $val);
                    if ($candidate !== null) {
                        $code = $candidate;
                        break;
                    }
                }
            }
        }

        if ($code !== null) {
            foreach (['quantity', 'qty', 'count', 'stock', 'amount', 'available'] as $key) {
                if (array_key_exists($key, $value)) {
                    $quantity = self::normalizeQuantity($value[$key]);
                    break;
                }
            }

            self::storeEntry($entries, $code, $quantity);
        }

        foreach ($value as $nested) {
            if (is_array($nested) || $nested instanceof JsonSerializable || $nested instanceof stdClass) {
                $walker($nested);
            }
        }
    }

    private static function storeEntry(array &$entries, string $code, ?int $quantity): void
    {
        $code = strtoupper($code);
        $existingQuantity = $entries[$code]['quantity'] ?? null;
        $resolvedQuantity = $quantity ?? $existingQuantity;

        $entry = ['code' => $code];
        if ($resolvedQuantity !== null) {
            $entry['quantity'] = $resolvedQuantity;
        }

        $entries[$code] = $entry;
    }

    private static function sanitizeHex(?string $value): ?string
    {
        if ($value === null) {
            return null;
        }

        $candidate = strtoupper(trim(str_replace(['#', '0X', '0x'], '', $value)));
        if ($candidate === '') {
            return null;
        }

        return preg_match('/^[0-9A-F]{6}$/', $candidate) ? $candidate : null;
    }

    private static function normalizeQuantity(mixed $value): ?int
    {
        if ($value === null) {
            return null;
        }

        if (is_bool($value)) {
            return $value ? 1 : 0;
        }

        if (is_int($value)) {
            return max(0, $value);
        }

        if (is_numeric($value)) {
            return max(0, (int) floor((float) $value));
        }

        if (is_string($value)) {
            $trimmed = trim($value);
            if ($trimmed === '' || ! is_numeric($trimmed)) {
                return null;
            }

            return max(0, (int) floor((float) $trimmed));
        }

        return null;
    }

    private static function looksLikeJson(string $value): bool
    {
        $first = substr($value, 0, 1);

        return $first === '[' || $first === '{';
    }
}