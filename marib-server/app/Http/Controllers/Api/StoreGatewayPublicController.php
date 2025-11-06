<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\StoreGatewayAccountResource;
use App\Models\User;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class StoreGatewayPublicController extends Controller
{
    public function index(User $seller): AnonymousResourceCollection
    {
        $accounts = $seller->storeGatewayAccounts()
            ->where('is_active', true)
            ->whereHas('storeGateway', static fn ($query) => $query->where('is_active', true))
            ->with(['storeGateway' => static fn ($query) => $query->where('is_active', true)])
            ->orderBy('id')
            ->get();

        return StoreGatewayAccountResource::collection($accounts);
    }
}