<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

class StripNumberFields
{
    /**
     * Handle an incoming request by removing any keys that end with `_number`.
     */
    public function handle(Request $request, Closure $next)
    {
        $all = $request->all();

        $sanitized = $this->stripNumberFieldsFromArray($all);

        // Replace the request input with sanitized data
        $request->replace($sanitized);

        return $next($request);
    }

    /**
     * Recursively strip keys that end with `_number` (case-insensitive) from an array.
     * @param array<mixed> $data
     * @return array<mixed>
     */
    private function stripNumberFieldsFromArray(array $data): array
    {
        $result = [];

        foreach ($data as $key => $value) {
            // If key ends with _number (case-insensitive), skip it
            if (is_string($key) && preg_match('/_number$/i', $key)) {
                continue;
            }

            if (is_array($value)) {
                $result[$key] = $this->stripNumberFieldsFromArray($value);
            } else {
                $result[$key] = $value;
            }
        }

        return $result;
    }
}
