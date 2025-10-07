<?php

namespace App\Http\Middleware;

use App\Models\Category;
use App\Services\ServiceAuthorizationService;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureCategoryManager
{
    public function __construct(private ServiceAuthorizationService $serviceAuthorizationService)
    {
    }

    public function handle(Request $request, Closure $next, string $parameter = 'category')
    {
        $user = $request->user();

        if (!$user) {
            return $this->forbiddenResponse($request);
        }

        $route = $request->route();
        $categoryParam = $route?->parameter($parameter);

        if ($categoryParam === null) {
            return $next($request);
        }

        $category = $categoryParam instanceof Category
            ? $categoryParam
            : Category::find($categoryParam);

        if (!$category) {
            abort(404);
        }

        if (!$this->serviceAuthorizationService->userCanManageCategory($user, $category)) {
            return $this->forbiddenResponse($request);
        }

        $route?->setParameter($parameter, $category);

        return $next($request);
    }

    protected function forbiddenResponse(Request $request)
    {
        $message = __('You are not authorized to manage this category.');

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