<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\StoreGatewayAccountResource;
use App\Models\StoreGatewayAccount;
use App\Models\User;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class StoreGatewayPublicController extends Controller
{
    public function index(User $seller): AnonymousResourceCollection
    {
        $store = $seller->stores()
            ->where('status', 'approved')
            ->first();

        $accountsQuery = StoreGatewayAccount::query()
            ->where('is_active', true)
            ->whereHas('storeGateway', static fn ($query) => $query->where('is_active', true))
            ->with(['storeGateway' => static fn ($query) => $query->where('is_active', true)])
            ->orderBy('id');

        if ($store) {
            $accountsQuery->where('store_id', $store->id);
        } else {
            $accountsQuery->where('user_id', $seller->getKey());
        }

        $accounts = $accountsQuery->get();

        return StoreGatewayAccountResource::collection($accounts);
    }
}
