<?php

namespace App\Services;

use App\Models\Category;
use App\Models\DepartmentTicket;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\PaymentTransaction;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\DB;
use App\Support\Payments\PaymentLabelService;

class DepartmentReportService
{
    public const DEPARTMENT_SHEIN = 'shein';
    public const DEPARTMENT_COMPUTER = 'computer';
    public const DEPARTMENT_STORE = 'store';
    public const DEPARTMENT_SERVICES = 'services';

    public function getGeneralOrderStats(): array
    {
        return [
            'total' => Order::count(),
            'today' => Order::whereDate('created_at', today())->count(),
            'week' => Order::where('created_at', '>=', now()->subWeek())->count(),
            'month' => Order::where('created_at', '>=', now()->subMonth())->count(),
            'completed' => Order::where('order_status', Order::STATUS_DELIVERED)->count(),
            'processing' => Order::where('order_status', Order::STATUS_PROCESSING)->count(),
            'canceled' => Order::where('order_status', Order::STATUS_CANCELED)->count(),
            'total_sales' => Order::where('order_status', Order::STATUS_DELIVERED)->sum('final_amount'),
        ];
    }

    public function getDepartmentMetrics(string $department): array
    {
        $categoryIds = $this->resolveCategoryIds($department);

        if (empty($categoryIds)) {
            return $this->emptyMetrics();
        }

        $ordersQuery = Order::query()
            ->whereHas('items.item', static function (Builder $query) use ($categoryIds) {
                $query->whereIn('category_id', $categoryIds);
            });

        $deliveredOrders = (clone $ordersQuery)->where('order_status', Order::STATUS_DELIVERED);
        $totalOrders = (clone $ordersQuery)->count();
        $totalSales = (clone $deliveredOrders)->sum('final_amount');
        $totalDelivered = (clone $deliveredOrders)->count();
        $totalProcessing = (clone $ordersQuery)->where('order_status', Order::STATUS_PROCESSING)->count();
        $totalCanceled = (clone $ordersQuery)->where('order_status', Order::STATUS_CANCELED)->count();
        $averageOrderValue = $totalDelivered > 0 ? round($totalSales / $totalDelivered, 2) : 0;

        $productsSold = OrderItem::query()
            ->whereHas('item', static function (Builder $query) use ($categoryIds) {
                $query->whereIn('category_id', $categoryIds);
            })
            ->sum('quantity');

        $paymentsTotal = PaymentTransaction::query()
            ->whereHas('order.items.item', static function (Builder $query) use ($categoryIds) {
                $query->whereIn('category_id', $categoryIds);
            })
            ->sum('amount');

        $ordersByStatus = (clone $ordersQuery)
            ->select('order_status', DB::raw('count(*) as total'))
            ->groupBy('order_status')
            ->get();

        $ordersByPaymentMethod = (clone $ordersQuery)
            ->select('payment_method', DB::raw('count(*) as total'))
            ->groupBy('payment_method')
            ->get()
            ->map(function ($row) {
                $labels = PaymentLabelService::forPayload([
                    'payment_method' => $row->payment_method,
                    'payment_gateway' => $row->payment_method,
                ]);

                $row->payment_gateway_key = $labels['gateway_key'];
                $row->payment_gateway_label = $labels['gateway_label'];
                $row->bank_name = $labels['bank_name'];

                return $row;
            });

        $dailySales = (clone $deliveredOrders)
            ->select(
                DB::raw('DATE(created_at) as date'),
                DB::raw('COUNT(*) as total_orders'),
                DB::raw('SUM(final_amount) as total_amount')
            )
            ->where('created_at', '>=', now()->subDays(30))
            ->groupBy('date')
            ->orderBy('date')
            ->get();

        $recentOrders = (clone $ordersQuery)
            ->with(['user:id,name,email,mobile'])
            ->latest('created_at')
            ->limit(10)
            ->get();

        $uniqueCustomers = (clone $ordersQuery)->distinct('user_id')->count('user_id');

        $openTickets = DepartmentTicket::query()
            ->where('department', $department)
            ->where('status', DepartmentTicket::STATUS_OPEN)
            ->count();

        return [
            'department' => $department,
            'category_ids' => $categoryIds,
            'total_orders' => $totalOrders,
            'delivered_orders' => $totalDelivered,
            'processing_orders' => $totalProcessing,
            'canceled_orders' => $totalCanceled,
            'total_sales' => $totalSales,
            'payments_total' => $paymentsTotal,
            'average_order_value' => $averageOrderValue,
            'products_sold' => $productsSold,
            'unique_customers' => $uniqueCustomers,
            'orders_by_status' => $ordersByStatus,
            'orders_by_payment_method' => $ordersByPaymentMethod,
            'daily_sales' => $dailySales,
            'recent_orders' => $recentOrders,
            'open_tickets' => $openTickets,
        ];
    }

    public function getDepartmentSnapshot(string $department): array
    {
        $metrics = $this->getDepartmentMetrics($department);

        return Arr::only($metrics, [
            'department',
            'total_orders',
            'total_sales',
            'delivered_orders',
            'processing_orders',
            'open_tickets',
        ]);
    }

    public function availableDepartments(): array
    {
        return [
            self::DEPARTMENT_SHEIN => __('departments.shein'),
            self::DEPARTMENT_COMPUTER => __('departments.computer'),
            self::DEPARTMENT_STORE => __('departments.store'),
            self::DEPARTMENT_SERVICES => __('departments.services'),


        ];
    }

    public function resolveCategoryIds(string $department): array
    {
        $rootIds = collect(Arr::wrap(config("cart.department_roots.$department")))
            ->map(static fn ($id) => $id !== null ? (int) $id : null)
            ->filter(static fn ($id) => $id !== null && $id > 0)
            ->unique()
            ->values()
            ->all();

        if ($rootIds === []) {
            return [];
        }

        return $this->gatherCategoryTreeIds($rootIds, $rootIds);
    }

    protected function gatherCategoryTreeIds(array $rootIds = [], array $parentIds = []): array
    {
        $collected = collect($rootIds)->filter()->unique();
        $queue = collect($parentIds)->filter();

        while ($queue->isNotEmpty()) {
            $children = Category::query()
                ->whereIn('parent_category_id', $queue->all())
                ->pluck('id');

            $newChildren = $children->diff($collected);

            if ($newChildren->isEmpty()) {
                break;
            }

            $collected = $collected->merge($newChildren)->unique();
            $queue = $newChildren;
        }

        return $collected->map(static fn ($id) => (int) $id)->values()->all();
    }

    protected function emptyMetrics(): array
    {
        return [
            'department' => null,
            'category_ids' => [],
            'total_orders' => 0,
            'delivered_orders' => 0,
            'processing_orders' => 0,
            'canceled_orders' => 0,
            'total_sales' => 0,
            'payments_total' => 0,
            'average_order_value' => 0,
            'products_sold' => 0,
            'unique_customers' => 0,
            'orders_by_status' => collect(),
            'orders_by_payment_method' => collect(),
            'daily_sales' => collect(),
            'recent_orders' => collect(),
            'open_tickets' => 0,
        ];
    }
}
