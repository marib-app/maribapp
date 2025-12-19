<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\StorefrontUiSetting;

class StorefrontUiController extends Controller
{
    public function show()
    {
        $setting = StorefrontUiSetting::query()->first();

        if (! $setting) {
            $setting = new StorefrontUiSetting([
                'enabled' => false,
                'featured_categories' => [],
                'promotion_slots' => [],
            ]);
        }

        return response()->json([
            'data' => [
                'enabled' => (bool) $setting->enabled,
                'featured_categories' => $setting->featured_categories ?? [],
                'promotion_slots' => $setting->promotion_slots ?? [],
            ],
        ]);
    }
}
