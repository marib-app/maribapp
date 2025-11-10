<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Store\StoreOnboardingRequest;
use App\Http\Resources\StoreResource;
use App\Services\ResponseService;
use App\Services\Store\StoreRegistrationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;
use Throwable;

class StoreOnboardingController extends Controller
{
    public function __construct(
        private readonly StoreRegistrationService $storeRegistrationService
    ) {
    }

    public function show(Request $request): JsonResponse
    {
        $store = $request->user()
            ->stores()
            ->with(['settings', 'workingHours', 'policies', 'staff'])
            ->latest()
            ->first();

        if (! $store) {
            return response()->json([
                'data' => null,
            ]);
        }

        return response()->json([
            'data' => new StoreResource($store),
        ]);
    }

    public function store(StoreOnboardingRequest $request): JsonResponse
    {
        $logPayload = $request->all();
        if (isset($logPayload['credentials']['password'])) {
            $logPayload['credentials']['password'] = '[hidden]';
        }
        if (isset($logPayload['staff']['password'])) {
            $logPayload['staff']['password'] = '[hidden]';
        }

        \Log::info('store_onboarding.request', [
            'user_id' => $request->user()?->id,
            'payload' => $logPayload,
        ]);

        try {
            $store = $this->storeRegistrationService->register(
                $request->user(),
                $request->validated()
            );

            return response()->json([
                'message' => __('تم حفظ بيانات المتجر بنجاح.'),
                'data' => new StoreResource($store),
            ], 201);
        } catch (ValidationException $exception) {
            $failedPayload = $request->all();
            if (isset($failedPayload['credentials']['password'])) {
                $failedPayload['credentials']['password'] = '[hidden]';
            }
            if (isset($failedPayload['staff']['password'])) {
                $failedPayload['staff']['password'] = '[hidden]';
            }

            \Log::warning('store_onboarding.validation_failed', [
                'user_id' => $request->user()?->id,
                'errors' => $exception->errors(),
                'payload' => $failedPayload,
            ]);

            throw $exception;
        } catch (Throwable $throwable) {
            ResponseService::logErrorResponse($throwable, 'StoreOnboardingController -> store');

            return response()->json([
                'message' => __('تعذر حفظ بيانات المتجر، يرجى المحاولة مرة أخرى.'),
            ], 500);
        }
    }
}
