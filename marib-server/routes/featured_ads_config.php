<?php

use App\Http\Controllers\Api\FeaturedAdsConfigController;
use Illuminate\Support\Facades\Route;

Route::middleware(['auth:sanctum'])->group(function () {
    Route::get('/featured-ads-configs', [FeaturedAdsConfigController::class, 'index']);
    Route::post('/featured-ads-configs', [FeaturedAdsConfigController::class, 'store']);
    Route::get('/featured-ads-configs/{featuredAdsConfig}', [FeaturedAdsConfigController::class, 'show']);
    Route::put('/featured-ads-configs/{featuredAdsConfig}', [FeaturedAdsConfigController::class, 'update']);
    Route::delete('/featured-ads-configs/{featuredAdsConfig}', [FeaturedAdsConfigController::class, 'destroy']);
});
