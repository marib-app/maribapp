<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\DepartmentTicket;
use App\Models\Item;
use App\Models\Order;
use App\Models\Store;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Cache;

class WebExperienceController extends Controller
{
    public function __invoke(): JsonResponse
    {
        $config = config('web_experience', []);

        if (empty($config)) {
            return response()->json([
                'message' => 'Web experience dataset is missing.',
            ], 503);
        }

        $metrics = Cache::remember('web_experience_metrics', 600, function (): array {
            return $this->compileMetrics();
        });

        return response()->json([
            'copy' => $config['copy'] ?? [],
            'features' => $config['features'] ?? [],
            'services' => $config['services'] ?? [],
            'testimonials' => $config['testimonials'] ?? [],
            'timeline' => $config['timeline'] ?? [],
            'faq' => $config['faq'] ?? [],
            'heroBadges' => $config['heroBadges'] ?? $config['hero_badges'] ?? [],
            'stats' => $metrics['stats'],
            'insights' => $metrics['insights'],
            'liveMetrics' => $metrics['live_metrics'],
        ]);
    }

    private function compileMetrics(): array
    {
        $now = Carbon::now();

        return [
            'stats' => $this->compileStats(),
            'insights' => $this->compileInsights($now),
            'live_metrics' => $this->compileLiveMetrics($now),
        ];
    }

    private function compileStats(): array
    {
        $template = collect(config('web_experience.stats', []));

        if ($template->isEmpty()) {
            return [];
        }

        $listingsCount = (int) Item::approved()->count();
        $storesCount = (int) Store::query()
            ->where(function ($query) {
                $query->where('status', 'approved')
                    ->orWhereNotNull('approved_at');
            })
            ->count();

        $citiesCount = (int) Item::approved()
            ->whereNotNull('city')
            ->distinct()
            ->count('city');

        $supportSessions = (int) DepartmentTicket::where('created_at', '>=', now()->subDays(7))->count();

        $map = [
            'listings' => $listingsCount,
            'stores' => $storesCount,
            'cities' => $citiesCount,
            'support' => $supportSessions,
        ];

        return $template
            ->map(function (array $stat) use ($map) {
                $id = $stat['id'] ?? null;
                if ($id !== null && array_key_exists($id, $map)) {
                    $stat['value'] = $map[$id];
                }

                return $stat;
            })
            ->values()
            ->all();
    }

    private function compileInsights(Carbon $now): array
    {
        $template = collect(config('web_experience.insights', []));

        if ($template->isEmpty()) {
            return [];
        }

        $ordersCurrentRangeStart = $now->copy()->subDays(7);
        $ordersPreviousRangeStart = $now->copy()->subDays(14);

        $ordersCurrent = (int) Order::where('created_at', '>=', $ordersCurrentRangeStart)->count();
        $ordersPrevious = (int) Order::whereBetween('created_at', [$ordersPreviousRangeStart, $ordersCurrentRangeStart])->count();

        $ticketsCurrentQuery = DepartmentTicket::where('created_at', '>=', $ordersCurrentRangeStart);
        $ticketsCurrentTotal = (int) $ticketsCurrentQuery->count();
        $ticketsCurrentResolved = (int) (clone $ticketsCurrentQuery)->where('status', DepartmentTicket::STATUS_RESOLVED)->count();
        $responseCurrent = $ticketsCurrentTotal > 0
            ? round(($ticketsCurrentResolved / $ticketsCurrentTotal) * 100)
            : 0;

        $ticketsPreviousQuery = DepartmentTicket::whereBetween('created_at', [$ordersPreviousRangeStart, $ordersCurrentRangeStart]);
        $ticketsPreviousTotal = (int) $ticketsPreviousQuery->count();
        $ticketsPreviousResolved = (int) (clone $ticketsPreviousQuery)->where('status', DepartmentTicket::STATUS_RESOLVED)->count();
        $responsePrevious = $ticketsPreviousTotal > 0
            ? round(($ticketsPreviousResolved / $ticketsPreviousTotal) * 100)
            : 0;

        $retentionCurrent = $this->retentionRate($now->copy()->subDays(30), $now);
        $retentionPrevious = $this->retentionRate($now->copy()->subDays(60), $now->copy()->subDays(30));

        $values = [
            'orders' => [
                'value' => $ordersCurrent,
                'change' => $this->formatChange($ordersCurrent, $ordersPrevious),
            ],
            'response' => [
                'value' => $responseCurrent,
                'change' => $this->formatChange($responseCurrent, $responsePrevious),
            ],
            'retention' => [
                'value' => $retentionCurrent,
                'change' => $this->formatChange($retentionCurrent, $retentionPrevious),
            ],
        ];

        return $template
            ->map(function (array $insight) use ($values) {
                $id = $insight['id'] ?? null;
                if ($id !== null && array_key_exists($id, $values)) {
                    $insight['value'] = $values[$id]['value'];
                    $insight['change'] = $values[$id]['change'];
                }

                return $insight;
            })
            ->values()
            ->all();
    }

    private function compileLiveMetrics(Carbon $now): array
    {
        $activeOrders = (int) Order::whereIn('order_status', $this->inProgressStatuses())
            ->where('created_at', '>=', $now->copy()->subHours(12))
            ->count();

        $openTickets = (int) DepartmentTicket::where('status', '!=', DepartmentTicket::STATUS_RESOLVED)
            ->where('updated_at', '>=', $now->copy()->subHours(12))
            ->count();

        $defaults = config('web_experience.liveMetrics', config('web_experience.live_metrics', []));

        return [
            'orders' => $activeOrders > 0 ? $activeOrders : (int) ($defaults['orders'] ?? 0),
            'support' => $openTickets > 0 ? $openTickets : (int) ($defaults['support'] ?? 0),
        ];
    }

    private function retentionRate(Carbon $start, Carbon $end): int
    {
        $orders = Order::query()
            ->whereBetween('created_at', [$start, $end])
            ->whereNotNull('user_id');

        $uniqueCustomers = (int) (clone $orders)->distinct()->count('user_id');

        if ($uniqueCustomers === 0) {
            return 0;
        }

        $repeatCustomers = (int) (clone $orders)
            ->select('user_id')
            ->groupBy('user_id')
            ->havingRaw('COUNT(*) > 1')
            ->count();

        return (int) round(($repeatCustomers / $uniqueCustomers) * 100);
    }

    private function formatChange(int|float $current, int|float $previous): string
    {
        if ($previous <= 0) {
            if ($current === 0.0) {
                return '0%';
            }

            return '+100%';
        }

        $delta = (($current - $previous) / $previous) * 100;
        $rounded = round($delta);
        $sign = $rounded > 0 ? '+' : '';

        return sprintf('%s%d%%', $sign, (int) $rounded);
    }

    /**
     * @return array<int, string>
     */
    private function inProgressStatuses(): array
    {
        return [
            Order::STATUS_PENDING,
            Order::STATUS_DEPOSIT_PAID,
            Order::STATUS_UNDER_REVIEW,
            Order::STATUS_CONFIRMED,
            Order::STATUS_PROCESSING,
            Order::STATUS_PREPARING,
            Order::STATUS_READY_FOR_DELIVERY,
            Order::STATUS_OUT_FOR_DELIVERY,
            Order::STATUS_ON_HOLD,
        ];
    }
}
