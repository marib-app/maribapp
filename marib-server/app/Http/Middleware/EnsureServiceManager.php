<?php

namespace App\Http\Middleware;

use App\Models\Service;
use App\Services\ServiceAuthorizationService;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureServiceManager
{
    public function __construct(private ServiceAuthorizationService $serviceAuthorizationService)
    {
    }

    public function handle(Request $request, Closure $next, string $parameter = 'service')
    {
        $user = $request->user();

        if (!$user) {
            return $this->forbiddenResponse($request);
        }

        $route = $request->route();
        $serviceParam = $route?->parameter($parameter);

        if ($serviceParam === null) {
            return $next($request);
        }

        $service = $serviceParam instanceof Service
            ? $serviceParam
            : Service::find($serviceParam);

        if (!$service) {
            abort(404);
        }

        if (!$this->serviceAuthorizationService->userCanManageService($user, $service)) {
            return $this->forbiddenResponse($request);
        }

        $route?->setParameter($parameter, $service);

        return $next($request);
    }

    protected function forbiddenResponse(Request $request)
    {
        $message = __('You are not authorized to manage this service.');

        if ($request->expectsJson() || $request->is('api/*')) {
            return response()->json([
                'error' => true,
                'message' => $message,
                'code' => Response::HTTP_FORBIDDEN,
            ], Response::HTTP_FORBIDDEN);
        }

        abort(Response::HTTP_FORBIDDEN, $message);
    }
}