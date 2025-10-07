<?php

namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class WifiPaymentGatewayController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $gateways = [
            [
                'id' => 'wallet',
                'name' => __('Wallet'),
                'description' => __('Pay using your in-app wallet balance.'),
                'is_wallet' => true,
                'is_default' => true,
                'metadata' => [
                    'supports_refund' => true,
                ],
            ],
        ];

        return response()->json([
            'data' => $gateways,
        ]);
    }
}