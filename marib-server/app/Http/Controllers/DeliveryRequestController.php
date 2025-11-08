<?php

namespace App\Http\Controllers;

use App\Models\DeliveryAgent;
use App\Models\DeliveryRequest;
use App\Models\User;
use App\Models\UserFcmToken;
use Illuminate\Http\Request;
use Illuminate\Http\RedirectResponse;
use Illuminate\View\View;
use App\Services\NotificationService;

class DeliveryRequestController extends Controller
{
    public function index(Request $request): View
    {
        $status = $request->string('status')->toString();
        $search = trim($request->string('search')->toString());

        $requests = DeliveryRequest::query()
            ->with(['order', 'assignee'])
            ->when($status !== '', static function ($query) use ($status) {
                $query->where('status', $status);
            })
            ->when($search !== '', static function ($query) use ($search) {
                $query->whereHas('order', static function ($orderQuery) use ($search) {
                    $orderQuery->where('order_number', 'like', "%{$search}%")
                        ->orWhere('id', $search);
                });
            })
            ->latest()
            ->paginate(20)
            ->appends($request->only('status', 'search'));

        return view('delivery.requests.index', [
            'requests' => $requests,
            'selectedStatus' => $status,
            'search' => $search,
        ]);
    }

    public function show(DeliveryRequest $deliveryRequest): View
    {
        $deliveryRequest->load([
            'order.items',
            'order.user',
            'order.store',
            'assignee',
        ]);

        $availableAgents = DeliveryAgent::active()
            ->with('user')
            ->orderBy('name')
            ->get();

        return view('delivery.requests.show', [
            'deliveryRequest' => $deliveryRequest,
            'availableAgents' => $availableAgents,
            'statuses' => [
                DeliveryRequest::STATUS_PENDING => __('قيد الترحيل'),
                DeliveryRequest::STATUS_ASSIGNED => __('تم التعيين'),
                DeliveryRequest::STATUS_DISPATCHED => __('في الطريق'),
                DeliveryRequest::STATUS_DELIVERED => __('مكتمل'),
                DeliveryRequest::STATUS_CANCELED => __('ملغى'),
            ],
        ]);
    }

    public function update(Request $request, DeliveryRequest $deliveryRequest): RedirectResponse
    {
        $deliveryRequest->loadMissing(['order.user', 'order.store']);

        $previousStatus = $deliveryRequest->status;
        $previousAssignee = $deliveryRequest->assigned_to;

        $validated = $request->validate([
            'status' => ['required', 'string', 'in:' . implode(',', [
                DeliveryRequest::STATUS_PENDING,
                DeliveryRequest::STATUS_ASSIGNED,
                DeliveryRequest::STATUS_DISPATCHED,
                DeliveryRequest::STATUS_DELIVERED,
                DeliveryRequest::STATUS_CANCELED,
            ])],
            'assigned_to' => ['nullable', 'exists:users,id'],
            'notes' => ['nullable', 'string', 'max:400'],
        ]);

        $deliveryRequest->fill($validated);

        if ($validated['status'] === DeliveryRequest::STATUS_ASSIGNED && empty($deliveryRequest->assigned_at)) {
            $deliveryRequest->assigned_at = now();
        }

        if ($validated['status'] === DeliveryRequest::STATUS_DISPATCHED && empty($deliveryRequest->dispatched_at)) {
            $deliveryRequest->dispatched_at = now();
        }

        if ($validated['status'] === DeliveryRequest::STATUS_DELIVERED) {
            $deliveryRequest->delivered_at = now();
        }

        $deliveryRequest->save();
        $this->notifyDeliveryUpdate(
            $deliveryRequest,
            $previousStatus !== $deliveryRequest->status,
            $previousAssignee !== $deliveryRequest->assigned_to
        );

        return redirect()
            ->route('delivery.requests.show', $deliveryRequest)
            ->with('success', __('تم تحديث حالة طلب التوصيل.'));
    }

    private function notifyDeliveryUpdate(DeliveryRequest $deliveryRequest, bool $statusChanged, bool $assigneeChanged): void
    {
        if ($assigneeChanged && $deliveryRequest->assignee) {
            $tokens = UserFcmToken::query()
                ->where('user_id', $deliveryRequest->assignee->getKey())
                ->pluck('fcm_token')
                ->filter()
                ->unique()
                ->values()
                ->all();

            if ($tokens !== []) {
                NotificationService::sendFcmNotification(
                    $tokens,
                    __('تم تعيينك لطلب توصيل'),
                    __('الطلب رقم #:order جاهز للاستلام.', ['order' => $deliveryRequest->order?->order_number ?? $deliveryRequest->order_id]),
                    'delivery_assignment',
                    $this->buildDeliveryPayload($deliveryRequest)
                );
            }
        }

        if ($statusChanged && $deliveryRequest->order?->user) {
            $tokens = UserFcmToken::query()
                ->where('user_id', $deliveryRequest->order->user->getKey())
                ->pluck('fcm_token')
                ->filter()
                ->unique()
                ->values()
                ->all();

            if ($tokens === []) {
                return;
            }

            $title = match ($deliveryRequest->status) {
                DeliveryRequest::STATUS_DISPATCHED => __('الطلب في الطريق إليك'),
                DeliveryRequest::STATUS_DELIVERED => __('تم تسليم طلبك'),
                default => null,
            };

            if ($title === null) {
                return;
            }

            $body = $deliveryRequest->status === DeliveryRequest::STATUS_DELIVERED
                ? __('تم تأكيد تسليم الطلب رقم #:order. نتمنى لك تجربة ممتعة!', ['order' => $deliveryRequest->order->order_number ?? $deliveryRequest->order_id])
                : __('تم إرسال الطلب رقم #:order مع فريق التوصيل.', ['order' => $deliveryRequest->order->order_number ?? $deliveryRequest->order_id]);

            NotificationService::sendFcmNotification(
                $tokens,
                $title,
                $body,
                'delivery_status_update',
                $this->buildDeliveryPayload($deliveryRequest)
            );
        }
    }

    public function notifyAgent(Request $request, DeliveryRequest $deliveryRequest): RedirectResponse
    {
        $validated = $request->validate([
            'agent_id' => ['required', 'exists:delivery_agents,id'],
            'message' => ['nullable', 'string', 'max:500'],
        ]);

        $agent = DeliveryAgent::with('user')->findOrFail($validated['agent_id']);

        $tokens = UserFcmToken::query()
            ->where('user_id', $agent->user_id)
            ->pluck('fcm_token')
            ->filter()
            ->unique()
            ->values()
            ->all();

        if ($tokens === []) {
            return back()->withErrors(['message' => __('لا يتوفر جهاز مرتبط بهذا المستخدم حالياً.')]);
        }

        $body = $validated['message'] ?: __('طلب توصيل رقم #:order جاهز للتنفيذ.', [
            'order' => $deliveryRequest->order?->order_number ?? $deliveryRequest->order_id,
        ]);

        $payload = $this->buildDeliveryPayload($deliveryRequest);
        $payload['agent_id'] = $agent->getKey();

        NotificationService::sendFcmNotification(
            $tokens,
            __('طلب توصيل جديد'),
            $body,
            'delivery_manual_push',
            $payload
        );

        return back()->with('success', __('تم إرسال الإشعار للمندوب.'));
    }

    /**
     * @return array<string, mixed>
     */
    private function buildDeliveryPayload(DeliveryRequest $deliveryRequest): array
    {
        $order = $deliveryRequest->order;

        $storeLocation = null;
        if ($order?->store?->location_latitude && $order->store->location_longitude) {
            $storeLocation = [
                'lat' => $order->store->location_latitude,
                'lng' => $order->store->location_longitude,
            ];
        }

        $shipping = $order?->shipping_address ?? $order?->address_snapshot;
        $customerLocation = null;
        if (is_array($shipping)) {
            $lat = $shipping['latitude'] ?? $shipping['lat'] ?? null;
            $lng = $shipping['longitude'] ?? $shipping['lng'] ?? null;
            if ($lat && $lng) {
                $customerLocation = ['lat' => $lat, 'lng' => $lng];
            }
        }

        $storeMap = $storeLocation
            ? sprintf('https://www.google.com/maps/dir/?api=1&destination=%s,%s', $storeLocation['lat'], $storeLocation['lng'])
            : null;

        $customerMap = $customerLocation
            ? sprintf('https://www.google.com/maps/dir/?api=1&destination=%s,%s', $customerLocation['lat'], $customerLocation['lng'])
            : null;

        return array_filter([
            'delivery_request_id' => $deliveryRequest->id,
            'order_id' => $deliveryRequest->order_id,
            'status' => $deliveryRequest->status,
            'store_location' => $storeLocation,
            'customer_location' => $customerLocation,
            'store_map_link' => $storeMap,
            'customer_map_link' => $customerMap,
            'deeplink' => route('delivery.requests.show', $deliveryRequest),
        ]);
    }
}
