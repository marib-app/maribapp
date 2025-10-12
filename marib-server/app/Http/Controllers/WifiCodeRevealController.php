<?php

namespace App\Http\Controllers;

use App\Models\WifiCode;
use App\Services\Wifi\WifiCodeAuditService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

class WifiCodeRevealController extends Controller
{
    public function store(Request $request, WifiCode $code, WifiCodeAuditService $auditService): JsonResponse
    {
        $user = $request->user();

        if (! $user) {
            abort(401, __('Authentication is required.'));
        }

        if ((int) $code->allocated_to_user_id !== $user->getKey() && $user->cannot('wifi-cabin-manage')) {
            abort(403, __('You are not allowed to log events for this Wi-Fi code.'));
        }

        $validated = $request->validate([
            'action' => ['required', 'string', 'max:255'],
            'meta' => ['nullable', 'array'],
        ]);

        try {
            $log = $auditService->log($code, $user, $validated['action'], [
                'ip_address' => $request->ip(),
                'user_agent' => $request->userAgent(),
                'meta' => $validated['meta'] ?? null,
            ]);
        } catch (ValidationException $exception) {
            throw $exception;
        }

        $freshCode = $code->fresh();

        return response()->json([
            'data' => array_filter([
                'id' => $log->getKey(),
                'action' => $log->action,
                'created_at' => optional($log->created_at)->toDateTimeString(),
                'reveal_count' => $freshCode?->reveal_count,
                'revealed_at' => optional($freshCode?->revealed_at)->toDateTimeString(),
            ], static fn ($value) => $value !== null),
        ], 201);
    }
}