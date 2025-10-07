<?php

namespace App\Http\Controllers;

use App\Models\WifiCode;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Arr;
use Illuminate\Support\Str;

class WifiPurchaseController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $user = $request->user();

        $validated = $request->validate([
            'status' => 'sometimes|string|in:' . implode(',', [
                WifiCode::STATUS_AVAILABLE,
                WifiCode::STATUS_ALLOCATED,
                WifiCode::STATUS_REDEEMED,
            ]),
            'per_page' => 'sometimes|integer|min:1|max:100',
        ]);

        $query = WifiCode::query()
            ->with([
                'network:id,name',
                'plan:id,wifi_network_id,name,price,currency',
            ])
            ->where('allocated_to_user_id', $user?->getKey())
            ->orderByDesc('allocated_at')
            ->orderByDesc('id');

        if (Arr::has($validated, 'status')) {
            $query->where('status', $validated['status']);
        }

        $perPage = $validated['per_page'] ?? 15;

        $codes = $query->paginate($perPage);
        $codes->getCollection()->transform(fn (WifiCode $code) => $this->transformCode($code));

        return response()->json($codes);
    }

    private function transformCode(WifiCode $code): array
    {
        $network = $code->getRelation('network');
        $plan = $code->getRelation('plan');

        return [
            'id' => $code->getKey(),
            'status' => $code->status,
            'code' => $this->maskValue($code->getDecryptedCode()),
            'serial_no' => $this->maskValue($code->getDecryptedSerialNumber()),
            
            'expires_at' => optional($code->expires_at)->toDateTimeString(),
            'purchased_at' => optional($code->allocated_at)->toDateTimeString(),
            'network' => $network ? [
                'id' => $network->getKey(),
                'name' => $network->name,
            ] : null,
            'plan' => $plan ? [
                'id' => $plan->getKey(),
                'name' => $plan->name,
                'price' => $plan->price,
                'currency' => $plan->currency,
            ] : null,
            'price' => $plan?->price,
            'currency' => $plan?->currency,
        ];
    }

    private function maskValue(?string $value): ?string
    {
        if ($value === null) {
            return null;
        }

        $length = Str::length($value);

        if ($length <= 4) {
            return $value;
        }

        $visible = Str::substr($value, -4);
        $maskedLength = $length - Str::length($visible);

        return str_repeat('*', $maskedLength) . $visible;
    }
}