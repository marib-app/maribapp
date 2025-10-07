<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Symfony\Component\HttpFoundation\BinaryFileResponse;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpFoundation\StreamedResponse;

class AttachCachingHeaders
{
    private const JSON_MAX_AGE = 60;
    private const IMAGE_MAX_AGE = 604800;

    public function handle(Request $request, Closure $next)
    {
        /** @var \Symfony\Component\HttpFoundation\Response $response */
        $response = $next($request);

        if (! $this->shouldProcess($request, $response)) {
            return $response;
        }

        $hash = $this->generateHash($response);

        if ($hash === null) {
            return $response;
        }

        $etag = '"' . $hash . '"';
        $response->headers->set('ETag', $etag);

        $maxAge = $this->determineMaxAge($response);

        if ($maxAge !== null) {
            $response->headers->set('Cache-Control', $this->cacheControlValue($response, $maxAge));
            $response->headers->set('Expires', $this->formatHttpDate(Carbon::now('UTC')->addSeconds($maxAge)));
        }

        if ($request->isMethod('GET') || $request->isMethod('HEAD')) {
            $ifNoneMatch = $request->headers->get('If-None-Match');

            if ($ifNoneMatch !== null) {
                if (trim($ifNoneMatch) === '*') {
                    $response->setNotModified();

                    return $response;
                }

                foreach (array_map('trim', explode(',', $ifNoneMatch)) as $candidate) {
                    if ($candidate === $etag || $candidate === 'W/' . $etag) {
                        $response->setNotModified();

                        return $response;
                    }
                }
            }
        }

        return $response;
    }

    private function shouldProcess(Request $request, Response $response): bool
    {
        if (! $request->isMethod('GET') && ! $request->isMethod('HEAD')) {
            return false;
        }

        if ($response->getStatusCode() < 200 || $response->getStatusCode() >= 400) {
            return false;
        }

        if ($response instanceof StreamedResponse && ! $response instanceof BinaryFileResponse) {
            return false;
        }

        return $this->isJsonResponse($response) || $this->isImageResponse($response);
    }

    private function generateHash(Response $response): ?string
    {
        if ($response instanceof BinaryFileResponse) {
            $file = $response->getFile();

            if ($file !== null && $file->isFile()) {
                return sha1_file($file->getPathname()) ?: null;
            }

            return null;
        }

        if (! method_exists($response, 'getContent')) {
            return null;
        }

        $content = $response->getContent();

        return is_string($content) ? sha1($content) : null;
    }

    private function determineMaxAge(Response $response): ?int
    {
        if ($this->isJsonResponse($response)) {
            return self::JSON_MAX_AGE;
        }

        if ($this->isImageResponse($response)) {
            return self::IMAGE_MAX_AGE;
        }

        return null;
    }

    private function cacheControlValue(Response $response, int $maxAge): string
    {
        if ($this->isImageResponse($response)) {
            return sprintf('public, max-age=%d, immutable', $maxAge);
        }

        return sprintf('public, max-age=%d, must-revalidate', $maxAge);
    }

    private function isJsonResponse(Response $response): bool
    {
        $contentType = strtolower((string) $response->headers->get('Content-Type', ''));

        return str_contains($contentType, 'application/json');
    }

    private function isImageResponse(Response $response): bool
    {
        $contentType = strtolower((string) $response->headers->get('Content-Type', ''));

        return str_starts_with($contentType, 'image/');
    }

    private function formatHttpDate(Carbon $date): string
    {
        return $date->setTimezone('GMT')->format('D, d M Y H:i:s') . ' GMT';
    }
}