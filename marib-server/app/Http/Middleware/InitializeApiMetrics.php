<?php

namespace App\Http\Middleware;

use App\Services\ApiMetricsService;
use Closure;
use Illuminate\Http\Request;

class InitializeApiMetrics
{
    public function handle(Request $request, Closure $next)
    {
        ApiMetricsService::startRequest($request);

        $response = $next($request);

        ApiMetricsService::record($response);

        return $response;
    }
}