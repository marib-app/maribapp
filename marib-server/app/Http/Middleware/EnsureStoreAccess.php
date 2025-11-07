<?php

namespace App\Http\Middleware;

use App\Models\Store;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\View;
use Symfony\Component\HttpFoundation\Response;

class EnsureStoreAccess
{
    /**
     * Handle an incoming request.
     *
     * @param  Closure(Request): (Response)  $next
     */
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if (! $user || ! $user->isSeller()) {
            abort(403, __('غير مصرح لك بالدخول إلى لوحة التاجر.'));
        }

        /** @var Store|null $store */
        $store = $user->stores()
            ->with('settings')
            ->latest()
            ->first();

        if (! $store) {
            return redirect()->route('seller-store-settings.index')
                ->withErrors([
                    'message' => __('الرجاء استكمال بيانات المتجر أولاً.'),
                ]);
        }

        $request->attributes->set('currentStore', $store);
        View::share('currentStore', $store);

        return $next($request);
    }
}
