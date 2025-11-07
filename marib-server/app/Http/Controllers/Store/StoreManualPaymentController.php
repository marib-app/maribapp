<?php

namespace App\Http\Controllers\Store;

use App\Http\Controllers\Controller;
use App\Models\ManualPaymentRequest;
use App\Models\Store;
use App\Services\Payments\ManualPaymentDecisionService;
use Illuminate\Http\Request;
use Illuminate\Http\RedirectResponse;
use Illuminate\Support\Facades\Auth;
use Illuminate\Validation\Rule;
use Illuminate\View\View;

class StoreManualPaymentController extends Controller
{
    public function __construct(
        private readonly ManualPaymentDecisionService $manualPaymentDecisionService
    ) {
    }

    public function index(Request $request): View
    {
        /** @var Store $store */
        $store = $request->attributes->get('currentStore');

        $status = $request->string('status')->toString();

        $manualPayments = $store->manualPaymentRequests()
            ->with(['user', 'manualBank'])
            ->when($status !== '', static fn ($query) => $query->where('status', $status))
            ->latest()
            ->paginate(15)
            ->appends($request->only('status'));

        $statusCounts = $store->manualPaymentRequests()
            ->selectRaw('status, COUNT(*) as total')
            ->groupBy('status')
            ->pluck('total', 'status');

        return view('store.manual-payments.index', [
            'store' => $store,
            'manualPayments' => $manualPayments,
            'selectedStatus' => $status,
            'statusCounts' => $statusCounts,
        ]);
    }

    public function show(Request $request, ManualPaymentRequest $manualPaymentRequest): View
    {
        /** @var Store $store */
        $store = $request->attributes->get('currentStore');
        abort_if($manualPaymentRequest->store_id !== $store->id, 404);

        $manualPaymentRequest->load(['user', 'manualBank', 'paymentTransaction']);

        return view('store.manual-payments.show', [
            'store' => $store,
            'manualPaymentRequest' => $manualPaymentRequest,
            'canDecide' => $manualPaymentRequest->isOpen(),
        ]);
    }

    public function decide(Request $request, ManualPaymentRequest $manualPaymentRequest): RedirectResponse
    {
        /** @var Store $store */
        $store = $request->attributes->get('currentStore');
        abort_if($manualPaymentRequest->store_id !== $store->id, 404);

        $validated = $request->validate([
            'decision' => ['required', Rule::in([ManualPaymentRequest::STATUS_APPROVED, ManualPaymentRequest::STATUS_REJECTED])],
            'note' => ['nullable', 'string', 'max:1000'],
            'notify_customer' => ['nullable', 'boolean'],
        ]);

        try {
            $this->manualPaymentDecisionService->decide($manualPaymentRequest, $validated['decision'], [
                'note' => $validated['note'] ?? null,
                'notify' => (bool) ($validated['notify_customer'] ?? false),
                'actor_id' => Auth::id(),
            ]);
        } catch (\Throwable $throwable) {
            return redirect()
                ->back()
                ->withErrors(['message' => $throwable->getMessage()]);
        }

        $message = $validated['decision'] === ManualPaymentRequest::STATUS_APPROVED
            ? __('تم قبول الحوالة وتأكيد الطلب.')
            : __('تم رفض الحوالة وإبلاغ العميل.');

        return redirect()
            ->route('merchant.manual-payments.show', $manualPaymentRequest)
            ->with('success', $message);
    }
}
