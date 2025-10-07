<?php

namespace App\Services\Wifi;

use App\Models\WifiCode;
use Illuminate\Database\Query\Builder;
use Illuminate\Support\Arr;
use Illuminate\Support\Collection;

class WifiCodeSummaryService
{
    /**
     * Build a nested summary keyed by network and plan identifiers.
     *
     * @param  \Illuminate\Support\Collection|array  $networkIds
     * @param  array  $filters
     * @return array<int, array<int, array<string, int>>>
     */
    public function planSummary(Collection|array $networkIds, array $filters = []): array
    {
        $networkIds = $this->normalizeIds($networkIds);

        if ($networkIds->isEmpty()) {
            return [];
        }

        $query = WifiCode::query()
            ->selectRaw('wifi_network_id, wifi_plan_id, status, COUNT(*) as aggregate')
            ->whereIn('wifi_network_id', $networkIds)
            ->groupBy('wifi_network_id', 'wifi_plan_id', 'status');

        $this->applyStatusFilter($query, Arr::get($filters, 'status'));

        if ($planIds = Arr::get($filters, 'plan_ids')) {
            $planIds = Arr::wrap($planIds);
            if (! empty($planIds)) {
                $query->whereIn('wifi_plan_id', $planIds);
            }
        }

        $summary = [];

        foreach ($query->get() as $row) {
            $networkId = (int) $row->wifi_network_id;
            $planId = (int) $row->wifi_plan_id;
            $status = (string) $row->status;
            $count = (int) $row->aggregate;

            $summary[$networkId][$planId][$status] = $count;
            $summary[$networkId][$planId]['total'] =
                ($summary[$networkId][$planId]['total'] ?? 0) + $count;
        }

        return $this->ensurePlanSummaryShape($summary);
    }

    /**
     * Build a summary keyed by network identifiers.
     *
     * @param  \Illuminate\Support\Collection|array  $networkIds
     * @param  array  $filters
     * @return array<int, array<string, int>>
     */
    public function networkSummary(Collection|array $networkIds, array $filters = []): array
    {
        $networkIds = $this->normalizeIds($networkIds);

        if ($networkIds->isEmpty()) {
            return [];
        }

        $query = WifiCode::query()
            ->selectRaw('wifi_network_id, status, COUNT(*) as aggregate')
            ->whereIn('wifi_network_id', $networkIds)
            ->groupBy('wifi_network_id', 'status');

        $this->applyStatusFilter($query, Arr::get($filters, 'status'));

        if ($planIds = Arr::get($filters, 'plan_ids')) {
            $planIds = Arr::wrap($planIds);
            if (! empty($planIds)) {
                $query->whereIn('wifi_plan_id', $planIds);
            }
        }

        $summary = [];

        foreach ($query->get() as $row) {
            $networkId = (int) $row->wifi_network_id;
            $status = (string) $row->status;
            $count = (int) $row->aggregate;

            $summary[$networkId][$status] = $count;
            $summary[$networkId]['total'] = ($summary[$networkId]['total'] ?? 0) + $count;
        }

        return $this->ensureNetworkSummaryShape($summary);
    }

    /**
     * @param  \Illuminate\Support\Collection|array  $ids
     * @return \Illuminate\Support\Collection<int, int>
     */
    protected function normalizeIds(Collection|array $ids): Collection
    {
        return collect($ids)
            ->flatten()
            ->filter(fn ($value) => is_numeric($value))
            ->map(fn ($value) => (int) $value)
            ->unique()
            ->values();
    }

    protected function applyStatusFilter(Builder $query, mixed $status): void
    {
        $statuses = Arr::wrap($status);
        $statuses = array_values(array_filter($statuses, fn ($value) => is_string($value) && $value !== ''));

        if ($statuses !== []) {
            $query->whereIn('status', $statuses);
        }
    }

    /**
     * Ensure every plan summary exposes the expected keys even when zero.
     *
     * @param  array  $summary
     * @return array
     */
    protected function ensurePlanSummaryShape(array $summary): array
    {
        foreach ($summary as $networkId => $plans) {
            foreach ($plans as $planId => $totals) {
                $summary[$networkId][$planId] = $this->ensureNetworkSummaryShape($totals);
            }
        }

        return $summary;
    }

    /**
     * Normalise the totals array to always expose recognised keys.
     *
     * @param  array  $totals
     * @return array
     */
    protected function ensureNetworkSummaryShape(array $totals): array
    {
        $available = (int) ($totals[WifiCode::STATUS_AVAILABLE] ?? 0);
        $allocated = (int) ($totals[WifiCode::STATUS_ALLOCATED] ?? 0);
        $redeemed = (int) ($totals[WifiCode::STATUS_REDEEMED] ?? 0);
        $total = (int) ($totals['total'] ?? ($available + $allocated + $redeemed));

        return [
            WifiCode::STATUS_AVAILABLE => $available,
            WifiCode::STATUS_ALLOCATED => $allocated,
            WifiCode::STATUS_REDEEMED => $redeemed,
            'total' => $total,
        ];
    }
}