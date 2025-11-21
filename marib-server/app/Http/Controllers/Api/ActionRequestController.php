<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ActionRequest;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Str;

class ActionRequestController extends Controller
{
    public function show(Request $request, ActionRequest $actionRequest): JsonResponse
    {
        $this->authorizeRequest($request, $actionRequest);

        return response()->json([
            'data' => $this->transform($actionRequest),
        ]);
    }

    public function perform(Request $request, ActionRequest $actionRequest): JsonResponse
    {
        $this->authorizeRequest($request, $actionRequest);

        if ($actionRequest->status !== 'pending') {
            return response()->json([
                'success' => false,
                'error' => 'already_processed',
                'data' => $this->transform($actionRequest),
            ], 409);
        }

        if ($actionRequest->expires_at && now()->greaterThan($actionRequest->expires_at)) {
            return response()->json([
                'success' => false,
                'error' => 'expired',
            ], 410);
        }

        $idempotencyKey = (string) $request->header('Idempotency-Key');
        if ($idempotencyKey === '') {
            return response()->json([
                'success' => false,
                'error' => 'missing_idempotency_key',
            ], 422);
        }

        if (!$this->claimIdempotency($actionRequest->id, $idempotencyKey)) {
            return response()->json([
                'success' => false,
                'error' => 'duplicate_request',
            ], 409);
        }

        $actionRequest->forceFill([
            'status' => 'completed',
            'used_at' => now(),
            'used_ip' => $request->ip(),
            'used_device' => (string) Str::limit((string) $request->userAgent(), 128, ''),
        ])->save();

        return response()->json([
            'success' => true,
            'data' => $this->transform($actionRequest->fresh()),
        ]);
    }

    protected function authorizeRequest(Request $request, ActionRequest $actionRequest): void
    {
        abort_unless($request->user()->id === $actionRequest->user_id, 404);

        $token = (string) $request->query('token', $request->input('token'));
        abort_unless($token !== '' && hash_equals($actionRequest->hmac_token, $token), 403, 'Invalid token.');

        if ($actionRequest->expires_at && now()->greaterThan($actionRequest->expires_at)) {
            abort(410, 'Action request expired.');
        }
    }

    protected function claimIdempotency(string $requestId, string $key): bool
    {
        $cacheKey = sprintf('action_request:%s:%s', $requestId, hash('sha256', $key));

        return Cache::store(config('notification.cache_store', config('cache.default')))
            ->add($cacheKey, now()->timestamp, now()->addMinutes(30));
    }

    protected function transform(ActionRequest $actionRequest): array
    {
        return [
            'id' => $actionRequest->id,
            'kind' => $actionRequest->kind,
            'entity' => $actionRequest->entity,
            'entity_id' => $actionRequest->entity_id,
            'amount' => $actionRequest->amount,
            'currency' => $actionRequest->currency,
            'status' => $actionRequest->status,
            'due_at' => optional($actionRequest->due_at)->toIso8601String(),
            'expires_at' => optional($actionRequest->expires_at)->toIso8601String(),
            'meta' => $actionRequest->meta,
            'used_at' => optional($actionRequest->used_at)->toIso8601String(),
        ];
    }
}
