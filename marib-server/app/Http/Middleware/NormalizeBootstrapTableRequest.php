<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class NormalizeBootstrapTableRequest
{
    private const DEFAULT_LIMIT = 10;
    private const MAX_LIMIT = 200;
    private const DEFAULT_PAGE = 1;

    public function handle(Request $request, Closure $next)
    {
        $shouldNormalize = $this->shouldNormalize($request);

        if ($shouldNormalize) {
            $normalized = $this->normalizeQueryParameters($request->query->all());
            $request->query->replace($normalized);
        }

        /** @var \Symfony\Component\HttpFoundation\Response $response */
        $response = $next($request);

        if ($shouldNormalize && $response instanceof JsonResponse) {
            $payload = $response->getData(true);

            if (is_array($payload) && array_key_exists('rows', $payload)) {
                if (!array_key_exists('data', $payload)) {
                    $payload['data'] = $payload['rows'];
                }

                $page = $this->positiveInt($request->query('page'), self::DEFAULT_PAGE);
                $length = $this->limitInt($request->query('length', $request->query('limit')));

                $payload['page'] = $payload['page'] ?? $page;
                $payload['length'] = $payload['length'] ?? $length;
                $payload['limit'] = $payload['limit'] ?? $length;
                $payload['offset'] = $payload['offset'] ?? $this->nonNegativeInt($request->query('offset'), ($page - 1) * $length);

                $response->setData($payload);
            }
        }

        return $response;
    }

    private function shouldNormalize(Request $request): bool
    {
        if (!$request->isMethod('get')) {
            return false;
        }

        $keys = ['limit', 'offset', 'page', 'pageNumber', 'length'];
        foreach ($keys as $key) {
            if ($request->query->has($key)) {
                return true;
            }
        }

        return false;
    }

    private function normalizeQueryParameters(array $query): array
    {
        $normalized = [];

        foreach ($query as $key => $value) {
            $sanitized = $this->sanitizeValue($value);

            if ($sanitized === null) {
                continue;
            }

            $normalized[$key] = $sanitized;
        }

        $limit = $this->limitInt($normalized['limit'] ?? $normalized['length'] ?? null);
        $normalized['limit'] = $limit;
        $normalized['length'] = $limit;

        $page = $this->positiveInt($normalized['page'] ?? $normalized['pageNumber'] ?? null);

        if ($page === null) {
            $offset = $this->nonNegativeInt($normalized['offset'] ?? null);
            $page = $offset === null ? self::DEFAULT_PAGE : (int) floor($offset / max($limit, 1)) + 1;
        }

        if ($page < self::DEFAULT_PAGE) {
            $page = self::DEFAULT_PAGE;
        }

        $normalized['page'] = $page;
        $normalized['pageNumber'] = $page;

        $offset = $this->nonNegativeInt($normalized['offset'] ?? null, ($page - 1) * $limit);
        $normalized['offset'] = $offset;

        if (array_key_exists('order', $normalized)) {
            $normalized['order'] = strtoupper((string) $normalized['order']) === 'ASC' ? 'ASC' : 'DESC';
        }

        if (!array_key_exists('sort', $normalized) || !is_string($normalized['sort']) || trim($normalized['sort']) === '') {
            $normalized['sort'] = 'id';
        } else {
            $normalized['sort'] = trim((string) $normalized['sort']);
        }

        if (array_key_exists('search', $normalized)) {
            $search = $this->sanitizeStringValue($normalized['search']);
            if ($search === null) {
                unset($normalized['search']);
            } else {
                $normalized['search'] = $search;
            }
        }

        return $normalized;
    }

    private function sanitizeValue($value)
    {
        if (is_array($value)) {
            $sanitizedArray = [];

            foreach ($value as $entry) {
                $sanitizedEntry = $this->sanitizeValue($entry);

                if ($sanitizedEntry === null) {
                    continue;
                }

                $sanitizedArray[] = $sanitizedEntry;
            }

            return count($sanitizedArray) > 0 ? $sanitizedArray : null;
        }

        if ($value === null) {
            return null;
        }

        if (is_string($value)) {
            $trimmed = trim($value);

            if ($trimmed === '') {
                return null;
            }

            $normalized = strtolower($trimmed);

            if (in_array($normalized, ['null', 'undefined', 'all'], true)) {
                return null;
            }

            return $trimmed;
        }

        return $value;
    }

    private function sanitizeStringValue($value): ?string
    {
        if ($value === null) {
            return null;
        }

        if (is_string($value)) {
            $trimmed = trim($value);

            if ($trimmed === '') {
                return null;
            }

            $normalized = strtolower($trimmed);

            if (in_array($normalized, ['null', 'undefined', 'all'], true)) {
                return null;
            }

            return $trimmed;
        }

        return (string) $value;
    }

    private function positiveInt($value, ?int $fallback = null): ?int
    {
        $intValue = $this->toInteger($value);

        if ($intValue === null || $intValue <= 0) {
            return $fallback;
        }

        return $intValue;
    }

    private function nonNegativeInt($value, int $fallback = 0): int
    {
        $intValue = $this->toInteger($value);

        if ($intValue === null || $intValue < 0) {
            return $fallback;
        }

        return $intValue;
    }

    private function limitInt($value): int
    {
        $intValue = $this->positiveInt($value, self::DEFAULT_LIMIT);

        if ($intValue === null) {
            $intValue = self::DEFAULT_LIMIT;
        }

        return max(1, min(self::MAX_LIMIT, $intValue));
    }

    private function toInteger($value): ?int
    {
        if (is_int($value)) {
            return $value;
        }

        if (is_numeric($value)) {
            return (int) $value;
        }

        return null;
    }
}