<?php

namespace App\Http\Controllers\Store;

use App\Http\Controllers\Controller;
use App\Models\Store;
use Illuminate\Http\Request;
use Illuminate\View\View;

class StoreManualPaymentController extends Controller
{
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
}
