<?php

namespace App\Http\Controllers\Store;

use App\Http\Controllers\Controller;
use App\Models\Order;
use App\Models\OrderHistory;
use App\Models\Store;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Validation\Rule;
use Illuminate\View\View;

class StoreOrderController extends Controller
{
    public function index(Request $request): View
    {
        /** @var Store $store */
        $store = $request->attributes->get('currentStore');

        $status = $request->string('status')->toString();
        $ordersQuery = $store->orders()
            ->latest();

        if ($status !== '') {
            $ordersQuery->where('order_status', $status);
        }

        $orders = $ordersQuery
            ->paginate(15)
            ->appends($request->only('status'));

        $statusCounts = $store->orders()
            ->selectRaw('order_status, COUNT(*) as total')
            ->groupBy('order_status')
            ->pluck('total', 'order_status');

        return view('store.orders.index', [
            'store' => $store,
            'orders' => $orders,
            'selectedStatus' => $status,
            'statusCounts' => $statusCounts,
        ]);
    }

    public function show(Request $request, Order $order): View
    {
        /** @var Store $store */
        $store = $request->attributes->get('currentStore');
        abort_if($order->store_id !== $store->id, 404);

        $order->load(['orderItems.item', 'user']);

        return view('store.orders.show', [
            'store' => $store,
            'order' => $order,
            'statusOptions' => config('constants.ORDER_STATUSES', []),
        ]);
    }

    public function updateStatus(Request $request, Order $order): RedirectResponse
    {
        /** @var Store $store */
        $store = $request->attributes->get('currentStore');
        abort_if($order->store_id !== $store->id, 404);

        $validated = $request->validate([
            'order_status' => [
                'required',
                Rule::in(array_keys(config('constants.ORDER_STATUSES', []))),
            ],
            'comment' => ['nullable', 'string', 'max:1000'],
            'notify_customer' => ['nullable', 'boolean'],
        ]);

        $newStatus = $validated['order_status'];
        $comment = $validated['comment'] ?? null;
        $notify = (bool) ($validated['notify_customer'] ?? false);

        if ($order->order_status === $newStatus) {
            return redirect()
                ->back()
                ->with('info', __('حالة الطلب لم تتغير.'));
        }

        $oldStatus = $order->order_status;
        $statusTimestamps = $order->status_timestamps ?? [];
        $statusTimestamps[$newStatus] = now()->toIso8601String();

        $order->fill([
            'order_status' => $newStatus,
            'status_timestamps' => $statusTimestamps,
        ])->save();

        OrderHistory::create([
            'order_id' => $order->id,
            'user_id' => Auth::id(),
            'status_from' => $oldStatus,
            'status_to' => $newStatus,
            'comment' => $comment,
            'notify_customer' => $notify,
        ]);

        return redirect()
            ->route('merchant.orders.show', $order)
            ->with('success', __('تم تحديث حالة الطلب بنجاح.'));
    }
}
