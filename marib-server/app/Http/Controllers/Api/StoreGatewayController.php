<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\StoreGatewayResource;
use App\Models\StoreGateway;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class StoreGatewayController extends Controller
{
    public function index(): AnonymousResourceCollection
    {
        $gateways = StoreGateway::query()
            ->where('is_active', true)
            ->orderBy('name')
            ->get();

        return StoreGatewayResource::collection($gateways);
    }
}