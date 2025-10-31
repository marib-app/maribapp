<?php

namespace App\Support;

class InputSanitizer
{
    /**
     * Remove any keys ending with `_number` (case-insensitive) from an array recursively.
     * @param array<mixed> $data
     * @return array<mixed>
     */
    public static function stripNumberFields(array $data): array
    {
        $result = [];

        foreach ($data as $key => $value) {
            if (is_string($key) && preg_match('/_number$/i', $key)) {
                // skip keys that end with _number
                continue;
            }

            if (is_array($value)) {
                $result[$key] = self::stripNumberFields($value);
            } else {
                $result[$key] = $value;
            }
        }

        return $result;
    }
}
