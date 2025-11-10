<?php

declare(strict_types=1);

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class AllowWebExperienceCors
{
    /**
     * Handle an incoming request.
     *
     * @param  Closure(Request): (Response)  $next
     */
    public function handle(Request $request, Closure $next): Response
    {
        if ($request->getMethod() === Request::METHOD_OPTIONS) {
            return $this->decorate(new Response(), $request);
        }

        /** @var Response $response */
        $response = $next($request);

        return $this->decorate($response, $request);
    }

    private function decorate(Response $response, Request $request): Response
    {
        $origin = $request->headers->get('Origin');

        if ($origin === null) {
            return $response;
        }

        $response->headers->set('Access-Control-Allow-Origin', $origin);
        $response->headers->set('Vary', trim($response->headers->get('Vary').' Origin'));
        $response->headers->set('Access-Control-Allow-Headers', 'Content-Type, Accept');
        $response->headers->set('Access-Control-Allow-Methods', 'GET, OPTIONS');
        $response->headers->set('Access-Control-Allow-Credentials', 'false');

        return $response;
    }
}
