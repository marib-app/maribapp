<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Store;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Storage;

class StoreDashboardController extends Controller
{
    public function summary(Request $request): JsonResponse
    {
        $user = $request->user();

        if (! $user || ! $user->isSeller()) {
            return response()->json([
                'message' => __('غير مصرح لك بالوصول إلى لوحة المتجر.'),
            ], 403);
        }

        /** @var Store|null $store */
        $store = $user->stores()
            ->with(['settings', 'workingHours', 'policies', 'staff', 'gatewayAccounts.storeGateway'])
            ->latest()
            ->first();

        if (! $store) {
            return response()->json([
                'message' => __('لم يتم تسجيل متجر لهذا الحساب حتى الآن.'),
            ], 404);
        }

        $timezone = $store->timezone ?: config('app.timezone', 'UTC');
        $todayStart = Carbon::now($timezone)->startOfDay()->copy();
        $todayEnd = Carbon::now($timezone)->endOfDay()->copy();

        $overview = [
            'today' => $this->buildSummary($store, $todayStart->copy(), $todayEnd->copy()),
            'week' => $this->buildSummary(
                $store,
                $todayStart->copy()->subDays(6),
                $todayEnd->copy()
            ),
            'month' => $this->buildSummary(
                $store,
                $todayStart->copy()->subDays(29),
                $todayEnd->copy()
            ),
        ];

        $statusCard = $this->buildStatusCard($store);
        $operatingState = $this->resolveOperatingState($store);

        return response()->json([
            'store' => [
                'id' => $store->id,
                'name' => $store->name,
                'status' => $store->status,
                'timezone' => $store->timezone,
                'logo_url' => $this->logoUrl($store->logo_path),
            ],
            'overview' => $overview,
            'status' => array_merge($statusCard, $operatingState),
            'working_hours' => $store->workingHours
                ->map(fn ($hour) => [
                    'weekday' => $hour->weekday,
                    'is_open' => (bool) $hour->is_open,
                    'opens_at' => $hour->opens_at,
                    'closes_at' => $hour->closes_at,
                ])->values(),
            'policies' => $store->policies
                ->map(fn ($policy) => [
                    'type' => $policy->policy_type,
                    'title' => $policy->title,
                    'content' => $policy->content,
                ])->values(),
            'staff' => $store->staff
                ->map(fn ($member) => [
                    'email' => $member->email,
                    'status' => $member->status,
                    'role' => $member->role,
                ])->values()->first(),
            'gateway_accounts' => $store->gatewayAccounts
                ->map(fn ($account) => [
                    'id' => $account->id,
                    'beneficiary_name' => $account->beneficiary_name,
                    'account_number' => $account->account_number,
                    'is_active' => (bool) $account->is_active,
                    'store_gateway' => $account->storeGateway
                        ? [
                            'id' => $account->storeGateway->id,
                            'name' => $account->storeGateway->name,
                            'logo_url' => $account->storeGateway->logo_url,
                        ]
                        : null,
                ])->values(),
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

        $closureModeMap = [
            'browse' => 'browse_only',
            'browse_only' => 'browse_only',
            'full' => 'full',
        ];

        $closureMode = $closureModeMap[$settings?->closure_mode ?? 'full'] ?? 'full';

        return [
            'status' => $store->status,
            'is_manually_closed' => (bool) ($settings?->is_manually_closed ?? false),
            'closure_mode' => $closureMode,
            'closure_reason' => $settings?->manual_closure_reason,
            'closure_expires_at' => $settings?->manual_closure_expires_at?->toIso8601String(),
            'min_order_amount' => $settings?->min_order_amount,
            'allow_delivery' => (bool) ($settings?->allow_delivery ?? true),
            'allow_pickup' => (bool) ($settings?->allow_pickup ?? true),
            'allow_manual_payments' => (bool) ($settings?->allow_manual_payments ?? true),
            'allow_wallet' => (bool) ($settings?->allow_wallet ?? false),
            'allow_cod' => (bool) ($settings?->allow_cod ?? false),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function resolveOperatingState(Store $store): array
    {
        $settings = $store->settings;
        $hours = $store->workingHours;
        $timezone = $store->timezone ?: config('app.timezone', 'UTC');
        $now = Carbon::now($timezone);

        if ($settings?->is_manually_closed) {
            return [
                'is_open_now' => false,
                'next_open_at' => $settings->manual_closure_expires_at?->toIso8601String(),
            ];
        }

        $byWeekday = $hours->keyBy('weekday');
        $currentEntry = $byWeekday->get($now->dayOfWeek);

        if ($currentEntry && $currentEntry->is_open) {
            [$start, $end] = $this->buildWindowForDay($currentEntry, $now);

            if ($start && $end) {
                if ($now->between($start, $end, true)) {
                    return [
                        'is_open_now' => true,
                        'next_open_at' => null,
                    ];
                }

                if ($now->lt($start)) {
                    return [
                        'is_open_now' => false,
                        'next_open_at' => $start->toIso8601String(),
                    ];
                }
            }
        }

        $nextOpen = $this->findNextOpenWindow($byWeekday, $now);

        return [
            'is_open_now' => false,
            'next_open_at' => $nextOpen?->toIso8601String(),
        ];
    }

    /**
     * @param  Collection<int, \App\Models\StoreWorkingHour>  $hours
     */
    private function findNextOpenWindow(Collection $hours, Carbon $now): ?Carbon
    {
        $timezone = $now->getTimezone();

        for ($offset = 1; $offset <= 7; $offset++) {
            $weekday = ($now->dayOfWeek + $offset) % 7;
            $entry = $hours->get($weekday);

            if ($entry && $entry->is_open && $entry->opens_at) {
                $targetDate = $now->copy()->addDays($offset)->setTimezone($timezone);
                [$start] = $this->buildWindowForDay($entry, $targetDate);

                if ($start) {
                    return $start;
                }
            }
        }

        return null;
    }

    /**
     * @return array{0: ?Carbon, 1: ?Carbon} indexed by [starts_at, ends_at]
     */
    private function buildWindowForDay($entry, Carbon $reference): array
    {
        $timezone = $reference->getTimezone();

        if (! $entry->opens_at || ! $entry->closes_at) {
            return [null, null];
        }

        try {
            $start = Carbon::parse($entry->opens_at, $timezone)
                ->setDate($reference->year, $reference->month, $reference->day);
            $end = Carbon::parse($entry->closes_at, $timezone)
                ->setDate($reference->year, $reference->month, $reference->day);

            if ($end->lessThanOrEqualTo($start)) {
                $end->addDay();
            }

            return [$start, $end];
        } catch (\Throwable) {
            return [null, null];
        }
    }

    private function logoUrl(?string $path): ?string
    {
        if (! $path) {
            return null;
        }

        if (filter_var($path, FILTER_VALIDATE_URL)) {
            return $path;
        }

        try {
            return Storage::url($path);
        } catch (\Throwable) {
            return url($path);
        }
    }
}
