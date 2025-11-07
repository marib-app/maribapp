<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\OrderResource;
use App\Models\Order;
use App\Models\OrderHistory;
use App\Models\Store;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class StoreOrderController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $store = $this->resolveStore($request);
        $status = $request->string('status')->toString();
        $perPage = min(max((int) $request->get('per_page', 15), 5), 50);

        $orders = $store->orders()
            ->when($status !== '', static fn ($query) => $query->where('order_status', $status))
            ->latest()
            ->paginate($perPage);

        return OrderResource::collection($orders)->additional([
            'meta' => [
                'current_page' => $orders->currentPage(),
                'per_page' => $orders->perPage(),
                'has_more' => $orders->hasMorePages(),
                'total' => $orders->total(),
            ],
        ])->response()->setStatusCode(200);
    }

    public function updateStatus(Request $request, Order $order): JsonResponse
    {
        $store = $this->resolveStore($request);

        if ($order->store_id !== $store->id) {
            return response()->json([
                'message' => __('لم يتم العثور على هذا الطلب ضمن متجرك.'),
            ], 404);
        }

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
            return response()->json([
                'message' => __('لا يوجد تغيير في حالة الطلب.'),
            ], 200);
        }

        $previousStatus = $order->order_status;
        $statusTimestamps = $order->status_timestamps ?? [];
        $statusTimestamps[$newStatus] = now()->toIso8601String();

        $order->fill([
            'order_status' => $newStatus,
            'status_timestamps' => $statusTimestamps,
        ])->save();

        OrderHistory::create([
            'order_id' => $order->id,
            'user_id' => $request->user()->id,
            'status_from' => $previousStatus,
            'status_to' => $newStatus,
            'comment' => $comment,
            'notify_customer' => $notify,
        ]);

        return response()->json([
            'message' => __('تم تحديث حالة الطلب بنجاح.'),
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
