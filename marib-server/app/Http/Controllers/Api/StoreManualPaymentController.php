<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\ManualPaymentRequestResource;
use App\Models\ManualPaymentRequest;
use App\Models\Store;
use App\Services\Payments\ManualPaymentDecisionService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class StoreManualPaymentController extends Controller
{
    public function __construct(
        private readonly ManualPaymentDecisionService $manualPaymentDecisionService
    ) {
    }

    public function index(Request $request): JsonResponse
    {
        $store = $this->resolveStore($request);
        $status = $request->string('status')->toString();
        $perPage = min(max((int) $request->get('per_page', 15), 5), 50);

        $manualPayments = $store->manualPaymentRequests()
            ->with(['user', 'manualBank'])
            ->when($status !== '', static fn ($query) => $query->where('status', $status))
            ->latest()
            ->paginate($perPage);

        return ManualPaymentRequestResource::collection($manualPayments)->additional([
            'meta' => [
                'current_page' => $manualPayments->currentPage(),
                'per_page' => $manualPayments->perPage(),
                'has_more' => $manualPayments->hasMorePages(),
                'total' => $manualPayments->total(),
            ],
        ])->response()->setStatusCode(200);
    }

    public function show(Request $request, ManualPaymentRequest $manualPaymentRequest): JsonResponse
    {
        $store = $this->resolveStore($request);

        if ($manualPaymentRequest->store_id !== $store->id) {
            return response()->json([
                'message' => __('لم يتم العثور على هذه الحوالة ضمن متجرك.'),
            ], 404);
        }

        $manualPaymentRequest->load(['user', 'manualBank', 'paymentTransaction']);

        return (new ManualPaymentRequestResource($manualPaymentRequest))
            ->response()
            ->setStatusCode(200);
    }

    public function decide(Request $request, ManualPaymentRequest $manualPaymentRequest): JsonResponse
    {
        $store = $this->resolveStore($request);

        if ($manualPaymentRequest->store_id !== $store->id) {
            return response()->json([
                'message' => __('لم يتم العثور على هذه الحوالة ضمن متجرك.'),
            ], 404);
        }

        $validated = $request->validate([
            'decision' => ['required', Rule::in([ManualPaymentRequest::STATUS_APPROVED, ManualPaymentRequest::STATUS_REJECTED])],
            'note' => [
                Rule::requiredIf(static fn () => $request->input('decision') === ManualPaymentRequest::STATUS_REJECTED),
                'string',
                'max:1000',
            ],
            'notify_customer' => ['nullable', 'boolean'],
        ]);

        try {
            $this->manualPaymentDecisionService->decide($manualPaymentRequest, $validated['decision'], [
                'note' => $validated['note'] ?? null,
                'notify' => (bool) ($validated['notify_customer'] ?? false),
                'actor_id' => $request->user()->id,
            ]);
        } catch (\Throwable $throwable) {
            return response()->json([
                'message' => $throwable->getMessage(),
            ], 422);
        }

        return response()->json([
            'message' => __('تم تحديث حالة الحوالة بنجاح.'),
        ]);
    }

    private function resolveStore(Request $request): Store
    {
        $user = $request->user();

        if (! $user || ! $user->isSeller()) {
            abort(403, __('غير مصرح لك.'));
        }

        $store = $user->stores()->latest()->first();

        if (! $store) {
            abort(404, __('لم يتم العثور على متجر مرتبط بالحساب.'));
        }

        return $store;
    }
}
