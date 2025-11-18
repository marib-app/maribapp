<?php

namespace App\Http\Controllers\Store;

use App\Http\Controllers\Controller;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\Store;
use App\Models\User;
use Carbon\Carbon;
use Carbon\CarbonInterval;
use Illuminate\Contracts\View\View;
use Illuminate\Http\Request;

class StoreInsightsController extends Controller
{
    public function coupons(): View
    {
        return $this->renderPlaceholder('coupons');
    }

    public function orderReports(Request $request): View
    {
        $store = $this->currentStore($request);

        [$from, $to, $periodKey] = $this->resolveRange($request);

        $ordersInRange = Order::query()
            ->where('store_id', $store->getKey())
            ->whereBetween('created_at', [$from, $to]);

        $totalOrders = (clone $ordersInRange)->count();
        $totalRevenue = (clone $ordersInRange)->sum('final_amount');

        $pendingStatuses = [
            Order::STATUS_CONFIRMED,
            Order::STATUS_PROCESSING,
            Order::STATUS_PREPARING,
            Order::STATUS_READY_FOR_DELIVERY,
            Order::STATUS_OUT_FOR_DELIVERY,
        ];

        $openOrders = (clone $ordersInRange)
            ->whereIn('order_status', $pendingStatuses)
            ->count();

        $avgFulfillmentLabel = null;
        $completedDurations = (clone $ordersInRange)
            ->whereNotNull('completed_at')
            ->get(['created_at', 'completed_at']);

        if ($completedDurations->isNotEmpty()) {
            $avgMinutes = (int) round($completedDurations->avg(
                static fn ($order) => $order->completed_at?->diffInMinutes($order->created_at)
            ));

            if ($avgMinutes > 0) {
                $avgFulfillmentLabel = CarbonInterval::minutes($avgMinutes)
                    ->cascade()
                    ->forHumans([
                        'short' => true,
                        'parts' => 2,
                        'join' => true,
                        'aUnit' => false,
                    ]);
            }
        }

        $statusBreakdown = (clone $ordersInRange)
            ->selectRaw('order_status, COUNT(*) as total_orders, SUM(final_amount) as revenue')
            ->groupBy('order_status')
            ->orderByDesc('total_orders')
            ->get();

        $paymentBreakdown = (clone $ordersInRange)
            ->selectRaw('payment_status, COUNT(*) as total_orders, SUM(final_amount) as revenue')
            ->groupBy('payment_status')
            ->orderByDesc('total_orders')
            ->get();

        $dailyTrend = (clone $ordersInRange)
            ->selectRaw('DATE(created_at) as day, COUNT(*) as total_orders, SUM(final_amount) as revenue')
            ->groupBy('day')
            ->orderBy('day')
            ->get()
            ->map(static function ($row) {
                $row->day = Carbon::parse($row->day);

                return $row;
            });

        $recentOrders = Order::query()
            ->with(['user:id,name'])
            ->where('store_id', $store->getKey())
            ->latest()
            ->limit(10)
            ->get(['id', 'order_number', 'final_amount', 'order_status', 'payment_status', 'created_at', 'user_id']);

        return view('store.insights.orders', [
            'store' => $store,
            'range' => [
                'from' => $from,
                'to' => $to,
                'key' => $periodKey,
            ],
            'summary' => [
                'total_orders' => $totalOrders,
                'total_revenue' => $totalRevenue,
                'open_orders' => $openOrders,
                'avg_fulfillment' => $avgFulfillmentLabel,
            ],
            'statusBreakdown' => $statusBreakdown,
            'paymentBreakdown' => $paymentBreakdown,
            'dailyTrend' => $dailyTrend,
            'recentOrders' => $recentOrders,
        ]);
    }

    public function salesReports(Request $request): View
    {
        $store = $this->currentStore($request);
        [$from, $to, $periodKey] = $this->resolveRange($request);

        $completedStatuses = $this->completedStatuses();

        $completedOrders = Order::query()
            ->where('store_id', $store->getKey())
            ->whereBetween('created_at', [$from, $to])
            ->whereIn('order_status', $completedStatuses);

        $totalRevenue = (clone $completedOrders)->sum('final_amount');
        $totalOrders = (clone $completedOrders)->count();
        $avgOrderValue = $totalOrders > 0 ? round($totalRevenue / $totalOrders, 2) : null;

        $itemsSold = OrderItem::query()
            ->whereHas('order', static function ($query) use ($store, $from, $to, $completedStatuses) {
                $query->where('store_id', $store->getKey())
                    ->whereBetween('created_at', [$from, $to])
                    ->whereIn('order_status', $completedStatuses);
            })
            ->sum('quantity');

        $avgBasket = $totalOrders > 0 ? round($itemsSold / $totalOrders, 2) : null;

        $paymentMix = (clone $completedOrders)
            ->selectRaw('payment_status, COUNT(*) as total_orders, SUM(final_amount) as revenue')
            ->groupBy('payment_status')
            ->orderByDesc('revenue')
            ->get();

        $dailyRevenue = (clone $completedOrders)
            ->selectRaw('DATE(created_at) as day, COUNT(*) as total_orders, SUM(final_amount) as revenue')
            ->groupBy('day')
            ->orderBy('day')
            ->get()
            ->map(static function ($row) {
                $row->day = Carbon::parse($row->day);

                return $row;
            });

        $topProducts = OrderItem::query()
            ->selectRaw('item_name, SUM(quantity) as total_quantity, SUM(subtotal) as total_revenue')
            ->whereHas('order', static function ($query) use ($store, $from, $to, $completedStatuses) {
                $query->where('store_id', $store->getKey())
                    ->whereBetween('created_at', [$from, $to])
                    ->whereIn('order_status', $completedStatuses);
            })
            ->groupBy('item_name')
            ->orderByDesc('total_quantity')
            ->limit(5)
            ->get();

        $topCustomers = (clone $completedOrders)
            ->whereNotNull('user_id')
            ->selectRaw('user_id, COUNT(*) as total_orders, SUM(final_amount) as revenue')
            ->groupBy('user_id')
            ->orderByDesc('revenue')
            ->limit(5)
            ->get();

        if ($topCustomers->isNotEmpty()) {
            $names = User::query()
                ->whereIn('id', $topCustomers->pluck('user_id')->filter()->unique())
                ->get(['id', 'name'])
                ->keyBy('id');

            $topCustomers = $topCustomers->map(static function ($row) use ($names) {
                $row->customer_name = optional($names->get($row->user_id))->name;

                return $row;
            });
        }

        return view('store.insights.sales', [
            'store' => $store,
            'range' => [
                'from' => $from,
                'to' => $to,
                'key' => $periodKey,
            ],
            'summary' => [
                'total_revenue' => $totalRevenue,
                'total_orders' => $totalOrders,
                'avg_order_value' => $avgOrderValue,
                'items_sold' => $itemsSold,
                'avg_basket' => $avgBasket,
            ],
            'paymentMix' => $paymentMix,
            'dailyRevenue' => $dailyRevenue,
            'topProducts' => $topProducts,
            'topCustomers' => $topCustomers,
        ]);
    }

    public function customerReports(Request $request): View
    {
        $store = $this->currentStore($request);
        [$from, $to, $periodKey] = $this->resolveRange($request);

        $completedStatuses = $this->completedStatuses();

        $orders = Order::query()
            ->where('store_id', $store->getKey())
            ->whereBetween('created_at', [$from, $to])
            ->whereIn('order_status', $completedStatuses);

        $customerOrders = (clone $orders)
            ->whereNotNull('user_id')
            ->selectRaw('user_id, COUNT(*) as total_orders, SUM(final_amount) as revenue, MIN(created_at) as first_order_at, MAX(created_at) as last_order_at')
            ->groupBy('user_id')
            ->orderByDesc('revenue')
            ->get();

        $totalCustomers = $customerOrders->count();
        $totalRevenue = $customerOrders->sum('revenue');
        $totalOrders = $customerOrders->sum('total_orders');

        $avgOrdersPerCustomer = $totalCustomers > 0 ? round($totalOrders / $totalCustomers, 2) : null;
        $avgRevenuePerCustomer = $totalCustomers > 0 ? round($totalRevenue / $totalCustomers, 2) : null;

        $customersInPeriod = $customerOrders->pluck('user_id')->filter()->unique();
        $returningCount = 0;

        if ($customersInPeriod->isNotEmpty()) {
            $returningIds = Order::query()
                ->where('store_id', $store->getKey())
                ->whereIn('user_id', $customersInPeriod)
                ->where('created_at', '<', $from)
                ->distinct()
                ->pluck('user_id');
            $returningCount = $returningIds->count();
        }

        $newCustomers = max(0, $totalCustomers - $returningCount);

        if ($customerOrders->isNotEmpty()) {
            $names = User::query()
                ->whereIn('id', $customerOrders->pluck('user_id')->unique())
                ->get(['id', 'name'])
                ->keyBy('id');

            $customerOrders = $customerOrders->map(static function ($row) use ($names) {
                $row->customer_name = optional($names->get($row->user_id))->name;

                return $row;
            });
        }

        $guestOrdersQuery = (clone $orders)->whereNull('user_id');
        $guestMetrics = [
            'orders' => $guestOrdersQuery->count(),
            'revenue' => (clone $guestOrdersQuery)->sum('final_amount'),
        ];

        $topCustomers = $customerOrders
            ->sortByDesc('revenue')
            ->take(5);

        $recentCustomers = $customerOrders
            ->sortByDesc('last_order_at')
            ->take(10);

        return view('store.insights.customers', [
            'store' => $store,
            'range' => [
                'from' => $from,
                'to' => $to,
                'key' => $periodKey,
            ],
            'summary' => [
                'total_customers' => $totalCustomers,
                'new_customers' => $newCustomers,
                'returning_customers' => $returningCount,
                'avg_orders_per_customer' => $avgOrdersPerCustomer,
                'avg_revenue_per_customer' => $avgRevenuePerCustomer,
                'total_revenue' => $totalRevenue,
            ],
            'guestMetrics' => $guestMetrics,
            'topCustomers' => $topCustomers,
            'recentCustomers' => $recentCustomers,
        ]);
    }

    /**
     * Render a shared placeholder layout until analytics modules are ready.
     */
    protected function renderPlaceholder(string $type): View
    {
        $config = [
            'coupons' => [
                'icon' => 'bi-ticket-perforated',
                'title_key' => 'merchant_insights.coupons_title',
                'subtitle_key' => 'merchant_insights.coupons_subtitle',
                'description_key' => 'merchant_insights.coupons_description',
            ],
            'orders' => [
                'icon' => 'bi-graph-up-arrow',
                'title_key' => 'merchant_insights.orders_title',
                'subtitle_key' => 'merchant_insights.orders_subtitle',
                'description_key' => 'merchant_insights.orders_description',
            ],
            'sales' => [
                'icon' => 'bi-cash-stack',
                'title_key' => 'merchant_insights.sales_title',
                'subtitle_key' => 'merchant_insights.sales_subtitle',
                'description_key' => 'merchant_insights.sales_description',
            ],
            'customers' => [
                'icon' => 'bi-people',
                'title_key' => 'merchant_insights.customers_title',
                'subtitle_key' => 'merchant_insights.customers_subtitle',
                'description_key' => 'merchant_insights.customers_description',
            ],
        ];

        abort_unless(isset($config[$type]), 404);

        return view('store.insights.placeholder', [
            'page' => $config[$type],
        ]);
    }

    private function currentStore(Request $request): Store
    {
        $store = $request->attributes->get('currentStore');

        abort_unless($store instanceof Store, 404);

        return $store;
    }

    /**
     * @return array{0: Carbon, 1: Carbon, 2: string}
     */
    private function resolveRange(Request $request): array
    {
        $period = $request->query('period', '30d');
        $end = Carbon::today()->endOfDay();
        $start = Carbon::today()->subDays(29)->startOfDay();

        if ($request->filled('start_date') && $request->filled('end_date')) {
            try {
                $start = Carbon::parse($request->query('start_date'))->startOfDay();
                $end = Carbon::parse($request->query('end_date'))->endOfDay();
                $period = 'custom';
            } catch (\Throwable) {
                // fallback to default
            }
        } else {
            switch ($period) {
                case '7d':
                    $start = Carbon::today()->subDays(6)->startOfDay();
                    $end = Carbon::today()->endOfDay();
                    break;
                case '14d':
                    $start = Carbon::today()->subDays(13)->startOfDay();
                    $end = Carbon::today()->endOfDay();
                    break;
                case '90d':
                    $start = Carbon::today()->subDays(89)->startOfDay();
                    $end = Carbon::today()->endOfDay();
                    break;
                default:
                    $period = '30d';
                    $start = Carbon::today()->subDays(29)->startOfDay();
                    $end = Carbon::today()->endOfDay();
                    break;
            }
        }

        if ($start->greaterThan($end)) {
            [$start, $end] = [$end->copy()->startOfDay(), $start->copy()->endOfDay()];
            $period = 'custom';
        }

        return [$start, $end, $period];
    }

    /**
     * @return array<int, string>
     */
    private function completedStatuses(): array
    {
        return [
            Order::STATUS_DELIVERED,
            Order::STATUS_FINAL_SETTLEMENT,
        ];
    }
}
