<?php

namespace App\Http\Controllers\Store;

use App\Http\Controllers\Controller;
use App\Models\ManualPaymentRequest;
use App\Models\Store;
use App\Services\Payments\ManualPaymentDecisionService;
use App\Support\ManualPayments\TransferDetailsResolver;
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
        $search = trim($request->string('search')->toString());

        $manualPaymentsQuery = $store->manualPaymentRequests()
            ->with(['user', 'manualBank'])
            ->when($status !== '', static fn ($query) => $query->where('status', $status))
            ->when($search !== '', static function ($query) use ($search) {
                $query->where(function ($builder) use ($search) {
                    $builder->where('reference', 'like', "%{$search}%")
                        ->orWhere('id', $search)
                        ->orWhereHas('user', static function ($userQuery) use ($search) {
                            $userQuery->where('name', 'like', "%{$search}%")
                                ->orWhere('email', 'like', "%{$search}%")
                                ->orWhere('mobile', 'like', "%{$search}%");
                        });
                });
            });

        $manualPayments = $manualPaymentsQuery
            ->latest()
            ->paginate(15)
            ->appends($request->only('status', 'search'));

        $statusCounts = $store->manualPaymentRequests()
            ->selectRaw('status, COUNT(*) as total')
            ->groupBy('status')
            ->pluck('total', 'status');

        $openStatuses = ManualPaymentRequest::OPEN_STATUSES;
        $openQuery = $store->manualPaymentRequests()->whereIn('status', $openStatuses);

        $openCount = (clone $openQuery)->count();
        $openAmount = (clone $openQuery)->sum('amount');
        $approvedToday = $store->manualPaymentRequests()
            ->where('status', ManualPaymentRequest::STATUS_APPROVED)
            ->whereDate('updated_at', now())
            ->count();
        $rejectedToday = $store->manualPaymentRequests()
            ->where('status', ManualPaymentRequest::STATUS_REJECTED)
            ->whereDate('updated_at', now())
            ->count();

        return view('store.manual-payments.index', [
            'store' => $store,
            'manualPayments' => $manualPayments,
            'selectedStatus' => $status,
            'statusCounts' => $statusCounts,
            'search' => $search,
            'openCount' => $openCount,
            'openAmount' => $openAmount,
            'approvedToday' => $approvedToday,
            'rejectedToday' => $rejectedToday,
        ]);
    }

    public function show(Request $request, ManualPaymentRequest $manualPaymentRequest): View
    {
        /** @var Store $store */
        $store = $request->attributes->get('currentStore');
        abort_if($manualPaymentRequest->store_id !== $store->id, 404);

        $manualPaymentRequest->load([
            'user',
            'manualBank',
            'paymentTransaction.order',
            'store',
            'histories.user',
        ]);

        $transferDetails = TransferDetailsResolver::forManualPaymentRequest($manualPaymentRequest)->toArray();
        $historyEntries = $manualPaymentRequest->histories()
            ->latest()
            ->get();

        return view('store.manual-payments.show', [
            'store' => $store,
            'manualPaymentRequest' => $manualPaymentRequest,
            'canDecide' => $manualPaymentRequest->isOpen(),
            'transferDetails' => $transferDetails,
            'relatedOrder' => $manualPaymentRequest->paymentTransaction?->order,
            'historyEntries' => $historyEntries,
        ]);
    }

    public function decide(Request $request, ManualPaymentRequest $manualPaymentRequest): RedirectResponse
    {
        /** @var Store $store */
        $store = $request->attributes->get('currentStore');
        abort_if($manualPaymentRequest->store_id !== $store->id, 404);

        $validated = $request->validate([
            'decision' => ['required', Rule::in([ManualPaymentRequest::STATUS_APPROVED, ManualPaymentRequest::STATUS_REJECTED])],
            'note' => [
                Rule::requiredIf(static fn () => $request->input('decision') === ManualPaymentRequest::STATUS_REJECTED),
                'string',
                'max:1000',
            ],
            'notify_customer' => ['nullable', 'boolean'],
            'attachment' => ['nullable', 'file', 'mimes:jpg,jpeg,png,pdf', 'max:5120'],
        ]);

        $attachmentPath = null;
        $attachmentOriginalName = null;

        if ($request->hasFile('attachment')) {
            $attachment = $request->file('attachment');
            $attachmentPath = $attachment->store('manual_payment_decisions', 'public');
            $attachmentOriginalName = $attachment->getClientOriginalName();
        }

        try {
            $this->manualPaymentDecisionService->decide($manualPaymentRequest, $validated['decision'], [
                'note' => $validated['note'] ?? null,
                'notify' => (bool) ($validated['notify_customer'] ?? false),
                'actor_id' => Auth::id(),
                'attachment_path' => $attachmentPath,
                'attachment_name' => $attachmentOriginalName,
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
