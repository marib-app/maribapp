<?php

namespace App\Http\Controllers\Store;

use App\Http\Controllers\Controller;
use App\Models\Order;
use App\Models\Store;
use Illuminate\Http\Request;
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
}
