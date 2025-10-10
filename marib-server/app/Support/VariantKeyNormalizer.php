<?php

namespace App\Support;

class VariantKeyNormalizer
{
    /**
     * Normalize a variant key string to the canonical representation used by the
     * VariantKeyGenerator.
     */
    public static function normalize(?string $variantKey): string
    {
        if ($variantKey === null) {
            return '';
        }

        $attributes = self::decode($variantKey);

        if ($attributes === []) {
            return '';
        }

        return VariantKeyGenerator::fromAttributes($attributes);
    }

    /**
     * Decode a variant key (canonical or legacy) into an attribute map.
     *
     * @return array<string, string>
     */
    public static function decode(string $variantKey): array
    {
        $trimmed = trim($variantKey);

        if ($trimmed === '') {
            return [];
        }

        $attributes = [];
        $segments = explode('|', $trimmed);

        foreach ($segments as $segment) {
            if ($segment === '') {
                continue;
            }

            $key = '';
            $value = '';

            if (str_contains($segment, '=')) {
                [$rawKey, $rawValue] = array_pad(explode('=', $segment, 2), 2, '');
                $key = rawurldecode($rawKey);
                $value = rawurldecode($rawValue);
            } elseif (str_contains($segment, ':')) {
                [$rawKey, $rawValue] = array_pad(explode(':', $segment, 2), 2, '');
                $key = $rawKey;
                $value = $rawValue;
            } else {
                $key = $segment;
                $value = '';
            }

            $key = trim((string) $key);
            $value = trim((string) $value);

            if ($key === '') {
                continue;
            }

            $attributes[$key] = $value;
        }

        return $attributes;
    }

    /**
     * Build the legacy (colon delimited) representation of the provided attributes.
     *
     * @param array<string, string> $attributes
     */
    public static function legacyFromAttributes(array $attributes): string
    {
        if ($attributes === []) {
            return '';
        }

        ksort($attributes, SORT_STRING);

        $parts = [];
        foreach ($attributes as $key => $value) {
            $parts[] = sprintf('%s:%s', trim((string) $key), trim((string) $value));
        }

        return implode('|', $parts);
    }

    /**
     * Return the canonical key followed by any alternate legacy representations.
     *
     * @return list<string>
     */
    public static function expand(string $variantKey): array
    {
        $attributes = self::decode($variantKey);

        if ($attributes === []) {
            return [''];
        }

        $canonical = VariantKeyGenerator::fromAttributes($attributes);
        $legacy = self::legacyFromAttributes($attributes);

        $keys = [$canonical];

        if ($legacy !== '' && $legacy !== $canonical) {
            $keys[] = $legacy;
        }

        return array_values(array_unique($keys));
    }
}