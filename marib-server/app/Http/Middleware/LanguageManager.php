<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\Session;

class LanguageManager {
    /**
     * Handle an incoming request.
     *
     * @param Request $request
     * @param Closure(\Illuminate\Http\Request): (\Illuminate\Http\Response|\Illuminate\Http\RedirectResponse)  $next
     * @return Response|RedirectResponse
     */
    public function handle(Request $request, Closure $next) {
        
        if (Session::has('language')) {
            $language = Session::get('language');
            $locale = null;

            if (is_object($language)) {
                $locale = $language->code ?? $language->locale ?? null;
            } elseif (is_array($language)) {
                $locale = $language['code'] ?? ($language['locale'] ?? null);
            } elseif (is_string($language) && $language !== '') {
                $locale = $language;
            }

            app()->setLocale($locale ?? config('app.locale', 'ar'));
        
        } else {
            // تعيين اللغة العربية كلغة افتراضية
            app()->setLocale('ar');
        }
        return $next($request);
    }
}
