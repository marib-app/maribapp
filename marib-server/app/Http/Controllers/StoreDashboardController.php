<?php

namespace App\Http\Controllers;

use App\Models\Order;
use App\Models\Store;
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

        return view('store.dashboard', [
            'store' => $store,
            'overview' => $overview,
            'statusCard' => $status,
        ]);
    }

    /**
     * @return array<string, mixed>
     */
    private function buildSummary(Store $store, Carbon $from, Carbon $to): array
    {
        $metrics = $store->dailyMetrics()
            ->whereBetween('metric_date', [$from->toDateString(), $to->toDateString()])
            ->selectRaw('SUM(visits) as visits, SUM(product_views) as product_views, SUM(add_to_cart) as add_to_cart')
            ->first();

        $orders = $store->orders()
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
}
