<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\BinaryFileResponse;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpFoundation\StreamedResponse;

class CompressJsonResponse
{
    /**
     * Handle an incoming request.
     */
    public function handle(Request $request, Closure $next)
    {
        /** @var \Symfony\Component\HttpFoundation\Response $response */
        $response = $next($request);

        if (! $this->shouldCompress($request, $response)) {
            return $response;
        }

        $encoding = $this->negotiateEncoding($request);

        if ($encoding === null) {
            return $response;
        }

        $compressed = $this->compressContent($response->getContent(), $encoding);

        if ($compressed === false) {
            return $response;
        }

        $response->setContent($compressed);
        $response->headers->set('Content-Encoding', $encoding);
        $this->appendVaryHeader($response, 'Accept-Encoding');
        $response->headers->set('Content-Length', (string) strlen($compressed));

        return $response;
    }

    private function shouldCompress(Request $request, Response $response): bool
    {
        if ($request->isMethod('HEAD')) {
            return false;
        }


        if (php_sapi_name() === 'cli-server') {
            return false;
        }

        if ($this->isCompressionAlreadyEnabled()) {
            return false;
        }



        if ($response instanceof StreamedResponse || $response instanceof BinaryFileResponse) {
            return false;
        }

        if ($response->headers->has('Content-Encoding')) {
            return false;
        }

        if ($response->headers->has('Content-Type')) {
            $contentType = $response->headers->get('Content-Type');

            if ($contentType === null || ! str_contains(strtolower($contentType), 'application/json')) {
                return false;
            }
        } elseif (! $response instanceof JsonResponse) {
            return false;
        }

        $content = $response->getContent();

        return is_string($content) && $content !== '';
    }



    private function isCompressionAlreadyEnabled(): bool
    {
        $zlibOutputCompression = ini_get('zlib.output_compression');

        if ($zlibOutputCompression !== false && $this->iniValueIsEnabled((string) $zlibOutputCompression)) {
            return true;
        }

        $outputHandler = ini_get('output_handler');

        if (is_string($outputHandler) && stripos($outputHandler, 'ob_gzhandler') !== false) {
            return true;
        }

        foreach (ob_list_handlers() as $handler) {
            $handler = (string) $handler;

            if (stripos($handler, 'ob_gzhandler') !== false || stripos($handler, 'zlib output compression') !== false) {
                return true;
            }
        }

        return false;
    }

    private function iniValueIsEnabled(string $value): bool
    {
        $normalized = strtolower($value);

        if (is_numeric($value)) {
            return (float) $value > 0;
        }

        return in_array($normalized, ['on', 'yes', 'true'], true);
    }

    private function negotiateEncoding(Request $request): ?string
    {
        $header = strtolower((string) $request->header('Accept-Encoding', ''));

        if ($header === '') {
            return null;
        }

        if (preg_match('/(^|,|\s)br(\s|,|;|$)/', $header)) {
            if (function_exists('brotli_compress')) {
                return 'br';
            }
        }

        if (preg_match('/(^|,|\s)gzip(\s|,|;|$)/', $header)) {
            if (function_exists('gzencode')) {
                return 'gzip';
            }
        }

        return null;
    }

    private function compressContent(string $content, string $encoding): string|false
    {
        return match ($encoding) {
            'br' => function_exists('brotli_compress')
                ? brotli_compress($content, 11, defined('BROTLI_TEXT') ? BROTLI_TEXT : 0)
                : false,
            'gzip' => function_exists('gzencode') ? gzencode($content, 9) : false,
            default => false,
        };
    }

    private function appendVaryHeader(Response $response, string $value): void
    {
        $existing = $response->headers->get('Vary');

        if ($existing === null) {
            $response->headers->set('Vary', $value);

            return;
        }

        $values = array_map('trim', explode(',', $existing));

        if (! in_array($value, $values, true)) {
            $values[] = $value;
            $response->headers->set('Vary', implode(', ', $values));
        }
    }
}