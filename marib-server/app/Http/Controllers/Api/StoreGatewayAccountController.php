<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\StoreGatewayAccountResource;
use App\Models\StoreGatewayAccount;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Validation\Rule;

class StoreGatewayAccountController extends Controller
{
    public function index(Request $request): AnonymousResourceCollection
    {
        $this->authorize('viewAny', StoreGatewayAccount::class);

        $accounts = $request->user()
            ->storeGatewayAccounts()
            ->with('storeGateway')
            ->latest()
            ->get();

        return StoreGatewayAccountResource::collection($accounts);
    }

    public function store(Request $request): JsonResponse
    {
        $this->authorize('create', StoreGatewayAccount::class);

        $validated = $request->validate([
            'store_gateway_id' => [
                'required',
                'integer',
                Rule::exists('store_gateways', 'id')->where('is_active', true),
            ],
            'beneficiary_name' => ['required', 'string', 'max:255'],
            'account_number' => ['required', 'string', 'max:255'],
            'is_active' => ['sometimes', 'boolean'],
        ]);

        /** @var \App\Models\User $user */
        $user = $request->user();

        $account = $user->storeGatewayAccounts()->create([
            'store_gateway_id' => $validated['store_gateway_id'],
            'beneficiary_name' => $validated['beneficiary_name'],
            'account_number' => $validated['account_number'],
            'is_active' => array_key_exists('is_active', $validated)
                ? (bool) $validated['is_active']
                : true,
        ])->load('storeGateway');

        return (new StoreGatewayAccountResource($account))
            ->response()
            ->setStatusCode(201);
    }

    public function update(Request $request, StoreGatewayAccount $storeGatewayAccount): StoreGatewayAccountResource
    {
        $this->authorize('update', $storeGatewayAccount);

        $validated = $request->validate([
            'store_gateway_id' => [
                'sometimes',
                'integer',
                Rule::exists('store_gateways', 'id')->where('is_active', true),
            ],
            'beneficiary_name' => ['sometimes', 'string', 'max:255'],
            'account_number' => ['sometimes', 'string', 'max:255'],
            'is_active' => ['sometimes', 'boolean'],
        ]);

        if (array_key_exists('is_active', $validated)) {
            $validated['is_active'] = (bool) $validated['is_active'];
        }

        $storeGatewayAccount->update($validated);

        return new StoreGatewayAccountResource($storeGatewayAccount->fresh('storeGateway'));
    }

    public function destroy(StoreGatewayAccount $storeGatewayAccount): JsonResponse
    {
        $this->authorize('delete', $storeGatewayAccount);

        $storeGatewayAccount->delete();

        return response()->json(null, 204);
    }
}