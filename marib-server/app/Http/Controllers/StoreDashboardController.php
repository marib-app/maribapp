<?php

namespace App\Http\Controllers;

use App\Models\ManualPaymentRequest;
use App\Models\ManualPaymentRequestHistory;
use App\Models\Order;
use App\Models\Store;
use App\Models\StoreDailyMetric;
use Carbon\Carbon;
use Illuminate\Http\Request;

class StoreDashboardController extends Controller
{
    public function index(Request $request)
    {
        /** @var Store $store */
        $store = $request->attributes->get('currentStore');

        $overview = [
            'today' => $this->buildSummary($store, Carbon::today(), Carbon::today()->endOfDay()),
            'week' => $this->buildSummary($store, Carbon::now()->subDays(6)->startOfDay(), Carbon::today()->endOfDay()),
            'month' => $this->buildSummary($store, Carbon::now()->subDays(29)->startOfDay(), Carbon::today()->endOfDay()),
        ];

        $status = $this->buildStatusCard($store);
        $manualPaymentStats = $this->buildManualPaymentSummary($store);
        $recentManualPayments = ManualPaymentRequest::query()
            ->where('store_id', $store->getKey())
            ->with('user')
            ->latest()
            ->limit(5)
            ->get();
        $recentOrders = Order::query()
            ->where('store_id', $store->getKey())
            ->latest()
            ->limit(5)
            ->get();

        $pendingOrderStates = [
            Order::STATUS_PROCESSING,
            Order::STATUS_PREPARING,
            Order::STATUS_READY_FOR_DELIVERY,
            Order::STATUS_OUT_FOR_DELIVERY,
        ];

        $pendingOrders = Order::query()
            ->where('store_id', $store->getKey())
            ->whereIn('order_status', $pendingOrderStates);

        $pendingOrderCount = (clone $pendingOrders)->count();
        $pendingOrderValue = (clone $pendingOrders)->sum('final_amount');

        $recentActivities = ManualPaymentRequestHistory::query()
            ->with(['manualPaymentRequest', 'user'])
            ->whereHas('manualPaymentRequest', static function ($query) use ($store) {
                $query->where('store_id', $store->getKey());
            })
            ->latest()
            ->limit(7)
            ->get();

        $alerts = $this->buildAlertCards($status, $manualPaymentStats, $pendingOrderCount);

        return view('store.dashboard', [
            'store' => $store,
            'overview' => $overview,
            'statusCard' => $status,
            'manualPaymentStats' => $manualPaymentStats,
            'recentManualPayments' => $recentManualPayments,
            'recentOrders' => $recentOrders,
            'pendingOrderCount' => $pendingOrderCount,
            'pendingOrderValue' => $pendingOrderValue,
            'recentActivities' => $recentActivities,
            'alerts' => $alerts,
        ]);
    }

    /**
     * @return array<string, mixed>
     */
    private function buildSummary(Store $store, Carbon $from, Carbon $to): array
    {
        $metrics = StoreDailyMetric::query()
            ->where('store_id', $store->getKey())
            ->whereBetween('metric_date', [$from->toDateString(), $to->toDateString()])
            ->selectRaw('SUM(visits) as visits, SUM(product_views) as product_views, SUM(add_to_cart) as add_to_cart')
            ->first();

        $orders = Order::query()
            ->where('store_id', $store->getKey())
            ->whereBetween('created_at', [$from, $to])
            ->selectRaw('COUNT(*) as total_orders, SUM(final_amount) as revenue')
            ->first();

        return [
            'range' => [
                'from' => $from->toDateString(),
                'to' => $to->toDateString(),
            ],
            'visits' => (int) ($metrics->visits ?? 0),
            'product_views' => (int) ($metrics->product_views ?? 0),
            'add_to_cart' => (int) ($metrics->add_to_cart ?? 0),
            'orders' => (int) ($orders->total_orders ?? 0),
            'revenue' => (float) ($orders->revenue ?? 0),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function buildStatusCard(Store $store): array
    {
        $settings = $store->settings;

        $isManualClosed = $settings?->is_manually_closed ?? false;
        $closureMode = $settings?->closure_mode ?? 'full';
        $closureEndsAt = $settings?->manual_closure_expires_at;

        return [
            'status' => $store->status,
            'is_manually_closed' => $isManualClosed,
            'closure_mode' => $closureMode,
            'closure_reason' => $settings?->manual_closure_reason,
            'closure_expires_at' => $closureEndsAt ? $closureEndsAt->toDateTimeString() : null,
            'min_order_amount' => $settings?->min_order_amount,
            'allow_delivery' => (bool) ($settings?->allow_delivery ?? true),
            'allow_pickup' => (bool) ($settings?->allow_pickup ?? true),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function buildManualPaymentSummary(Store $store): array
    {
        $openStatuses = ManualPaymentRequest::OPEN_STATUSES;

        $base = ManualPaymentRequest::query()
            ->where('store_id', $store->getKey());

        $openQuery = (clone $base)->whereIn('status', $openStatuses);

        $approvedToday = (clone $base)
            ->where('status', ManualPaymentRequest::STATUS_APPROVED)
            ->whereDate('updated_at', now())
            ->count();

        $rejectedToday = (clone $base)
            ->where('status', ManualPaymentRequest::STATUS_REJECTED)
            ->whereDate('updated_at', now())
            ->count();

        return [
            'open_count' => $openQuery->count(),
            'open_amount' => (clone $openQuery)->sum('amount'),
            'approved_today' => $approvedToday,
            'rejected_today' => $rejectedToday,
            'total_requests' => (clone $base)->count(),
        ];
    }

    /**
     * @param array<string, mixed> $statusCard
     * @param array<string, mixed> $manualPaymentStats
     * @return array<int, array{type:string,message:string}>
     */
    private function buildAlertCards(array $statusCard, array $manualPaymentStats, int $pendingOrderCount): array
    {
        $alerts = [];

        if (($statusCard['is_manually_closed'] ?? false) === true) {
            $alerts[] = [
                'type' => 'warning',
                'message' => __('المتجر مغلق يدوياً حالياً، لن يتمكن العملاء من إنهاء الطلبات.'),
            ];
        }

        if (($manualPaymentStats['open_count'] ?? 0) > 0) {
            $alerts[] = [
                'type' => 'primary',
                'message' => __('هناك :count حوالات تنتظر الإجراء.', ['count' => $manualPaymentStats['open_count']]),
            ];
        }

        if ($pendingOrderCount > 0) {
            $alerts[] = [
                'type' => 'info',
                'message' => __('هناك :count طلبات قيد التنفيذ وتحتاج لتحديث الحالة.', ['count' => $pendingOrderCount]),
            ];
        }

        return $alerts;
    }
}
