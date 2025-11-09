<?php

namespace App\Http\Controllers;

use App\Enums\StoreStatus;
use App\Models\Category;
use App\Models\Store;
use App\Services\ResponseService;
use App\Services\Store\StoreStatusService;
use Illuminate\Contracts\View\View;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class MerchantStoreController extends Controller
{
    public function __construct(private readonly StoreStatusService $storeStatusService)
    {
    }

    public function index(Request $request): View
    {
        ResponseService::noPermissionThenRedirect('seller-store-settings-manage');

        $statusFilter = (string) $request->query('status', '');
        $search = trim((string) $request->query('search', ''));

        $query = Store::query()
            ->with(['owner'])
            ->withCount(['items', 'orders']);

        if ($statusFilter !== '' && in_array($statusFilter, StoreStatus::values(), true)) {
            $query->where('status', $statusFilter);
        }

        if ($search !== '') {
            $query->where(static function ($inner) use ($search) {
                $inner->where('name', 'like', "%{$search}%")
                    ->orWhere('slug', 'like', "%{$search}%")
                    ->orWhere('contact_phone', 'like', "%{$search}%")
                    ->orWhere('contact_email', 'like', "%{$search}%")
                    ->orWhereHas('owner', static function ($ownerQuery) use ($search) {
                        $ownerQuery->where('name', 'like', "%{$search}%")
                            ->orWhere('email', 'like', "%{$search}%")
                            ->orWhere('mobile', 'like', "%{$search}%");
                    });
            });
        }

        $stores = $query->orderByDesc('status_changed_at')
            ->orderByDesc('created_at')
            ->paginate(20)
            ->withQueryString();

        $statusCounts = Store::query()
            ->select('status')
            ->selectRaw('count(*) as total')
            ->groupBy('status')
            ->pluck('total', 'status');

        $metrics = [
            'total' => $statusCounts->sum(),
            'pending' => $statusCounts->get(StoreStatus::PENDING->value, 0),
            'approved' => $statusCounts->get(StoreStatus::APPROVED->value, 0),
            'suspended' => $statusCounts->get(StoreStatus::SUSPENDED->value, 0),
        ];

        return view('merchant-stores.index', [
            'stores' => $stores,
            'metrics' => $metrics,
            'statuses' => StoreStatus::cases(),
            'filters' => [
                'search' => $search,
                'status' => $statusFilter,
            ],
        ]);
    }

    public function show(Store $store): View
    {
        ResponseService::noPermissionThenRedirect('seller-store-settings-manage');

        $store->load([
            'owner',
            'settings',
            'workingHours',
            'policies',
            'staff' => static fn ($query) => $query->with(['user'])->orderBy('created_at'),
            'gatewayAccounts.storeGateway',
            'statusLogs' => static fn ($query) => $query->with('actor')->latest()->take(20),
        ]);

        $statusSnapshot = $this->storeStatusService->resolve($store->replicate());
        $meta = $store->meta ?? [];

        $categoryIds = Arr::wrap($meta['categories'] ?? []);
        $categories = [];

        if ($categoryIds !== []) {
            $categories = Category::query()
                ->whereIn('id', $categoryIds)
                ->pluck('name', 'id')
                ->toArray();
        }

        $paymentMethods = Arr::wrap($meta['payment_methods'] ?? []);

        return view('merchant-stores.show', [
            'store' => $store,
            'statusSnapshot' => $statusSnapshot,
            'categories' => $categories,
            'paymentMethods' => $paymentMethods,
            'statuses' => StoreStatus::cases(),
        ]);
    }

    public function updateStatus(Request $request, Store $store): RedirectResponse
    {
        ResponseService::noPermissionThenRedirect('seller-store-settings-manage');

        $data = $request->validate([
            'status' => ['required', Rule::in(StoreStatus::values())],
            'reason' => ['nullable', 'string', 'max:500'],
        ]);

        $newStatus = $data['status'];
        $reason = $data['reason'] ?? null;

        if (in_array($newStatus, [StoreStatus::REJECTED->value, StoreStatus::SUSPENDED->value], true)
            && empty($reason)) {
            return redirect()
                ->back()
                ->withErrors(['reason' => __('Reason is required for this action.')])
                ->withInput();
        }

        if ($store->status === $newStatus) {
            return redirect()
                ->back()
                ->with('info', __('The store is already using this status.'));
        }

        DB::transaction(function () use ($store, $newStatus, $reason) {
            $now = now();
            $authId = Auth::id();

            $store->status = $newStatus;
            $store->status_changed_at = $now;

            if ($newStatus === StoreStatus::APPROVED->value) {
                $store->approved_at = $now;
                $store->approved_by = $authId;
                $store->rejection_reason = null;
                $store->suspended_at = null;
                $store->suspended_by = null;
            } elseif ($newStatus === StoreStatus::REJECTED->value) {
                $store->rejection_reason = $reason;
                $store->approved_at = null;
                $store->approved_by = null;
                $store->suspended_at = null;
                $store->suspended_by = null;
            } elseif ($newStatus === StoreStatus::SUSPENDED->value) {
                $store->suspended_at = $now;
                $store->suspended_by = $authId;
            } else {
                if ($newStatus !== StoreStatus::APPROVED->value) {
                    $store->approved_at = null;
                    $store->approved_by = null;
                }
                $store->rejection_reason = null;
                $store->suspended_at = null;
                $store->suspended_by = null;
            }

            $store->save();

            $store->statusLogs()->create([
                'status' => $newStatus,
                'reason' => $reason,
                'context' => [
                    'source' => 'admin_panel',
                ],
                'changed_by' => $authId,
            ]);
        });

        return redirect()
            ->route('merchant-stores.show', $store)
            ->with('success', __('Store status updated successfully.'));
    }
}
