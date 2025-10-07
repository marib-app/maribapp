<?php

namespace App\Services;

use App\Models\Slider;
use App\Models\SliderMetric;
use Carbon\Carbon;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

class SliderMetricService
{
    public const EVENT_IMPRESSION = 'impression';
    public const EVENT_CLICK = 'click';

    public function recordImpression(Slider $slider, ?int $userId, ?string $sessionId, ?Carbon $occurredAt = null): SliderMetric
    {
        return $this->recordEvent($slider, self::EVENT_IMPRESSION, $userId, $sessionId, $occurredAt);
    }

    public function recordClick(Slider $slider, ?int $userId, ?string $sessionId, ?Carbon $occurredAt = null): SliderMetric
    {
        return $this->recordEvent($slider, self::EVENT_CLICK, $userId, $sessionId, $occurredAt);
    }

    public function summarizeForSliders(iterable $sliderIds, ?Carbon $startDate = null, ?Carbon $endDate = null): Collection
    {
        $ids = collect($sliderIds)->filter()->map(fn ($id) => (int) $id)->unique()->values();

        if ($ids->isEmpty()) {
            return collect();
        }

        $rows = $this->baseAggregateQuery($startDate, $endDate)
            ->addSelect('slider_id')
            ->whereIn('slider_id', $ids)
            ->groupBy('slider_id')
            ->get();

        return $rows->mapWithKeys(function ($row) {
            $impressions = (int) ($row->impressions ?? 0);
            $clicks = (int) ($row->clicks ?? 0);

            return [
                (int) $row->slider_id => [
                    'impressions' => $impressions,
                    'clicks'      => $clicks,
                    'ctr'         => $this->calculateCtr($impressions, $clicks),
                ],
            ];
        });
    }

    public function getDailyAggregates(?Carbon $startDate = null, ?Carbon $endDate = null): Collection
    {
        $rows = $this->baseAggregateQuery($startDate, $endDate)
            ->addSelect(DB::raw('DATE(occurred_at) as date'))
            ->groupBy(DB::raw('DATE(occurred_at)'))
            ->orderBy('date')
            ->get();

        return $this->formatAggregateRows($rows, 'date');
    }

    public function getWeeklyAggregates(?Carbon $startDate = null, ?Carbon $endDate = null): Collection
    {
        $rows = $this->baseAggregateQuery($startDate, $endDate)
            ->addSelect(DB::raw("YEAR(occurred_at) as year"))
            ->addSelect(DB::raw("WEEK(occurred_at, 3) as week"))
            ->groupBy(DB::raw('YEAR(occurred_at)'), DB::raw('WEEK(occurred_at, 3)'))
            ->orderBy('year')
            ->orderBy('week')
            ->get()
            ->map(function ($row) {
                $row->label = sprintf('%d-W%02d', (int) $row->year, (int) $row->week);

                return $row;
            });

        return $this->formatAggregateRows($rows, 'label');
    }

    public function getStatusAggregates(?Carbon $startDate = null, ?Carbon $endDate = null): Collection
    {
        $rows = $this->baseAggregateQuery($startDate, $endDate)
            ->join('sliders', 'slider_metrics.slider_id', '=', 'sliders.id')
            ->addSelect('sliders.status as status')
            ->groupBy('sliders.status')
            ->orderBy('sliders.status')
            ->get();

        return $this->formatAggregateRows($rows, 'status');
    }

    public function getInterfaceTypeAggregates(?Carbon $startDate = null, ?Carbon $endDate = null): Collection
    {
        $rows = $this->baseAggregateQuery($startDate, $endDate)
            ->join('sliders', 'slider_metrics.slider_id', '=', 'sliders.id')
            ->addSelect('sliders.interface_type as interface_type')
            ->groupBy('sliders.interface_type')
            ->orderBy('sliders.interface_type')
            ->get();

        return $this->formatAggregateRows($rows, 'interface_type');
    }

    protected function recordEvent(Slider $slider, string $eventType, ?int $userId, ?string $sessionId, ?Carbon $occurredAt = null): SliderMetric
    {
        $occurredAt ??= Carbon::now();

        return SliderMetric::create([
            'slider_id'   => $slider->getKey(),
            'user_id'     => $userId,
            'session_id'  => $sessionId,
            'event_type'  => $eventType,
            'occurred_at' => $occurredAt,
        ]);
    }

    protected function baseAggregateQuery(?Carbon $startDate, ?Carbon $endDate): Builder
    {
        return SliderMetric::query()
            ->selectRaw($this->eventCountSelect())
            ->when($startDate, fn (Builder $query) => $query->where('occurred_at', '>=', $startDate))
            ->when($endDate, fn (Builder $query) => $query->where('occurred_at', '<=', $endDate));
    }

    protected function eventCountSelect(): string
    {
        return sprintf(
            "SUM(CASE WHEN event_type = '%s' THEN 1 ELSE 0 END) AS impressions, " .
            "SUM(CASE WHEN event_type = '%s' THEN 1 ELSE 0 END) AS clicks",
            self::EVENT_IMPRESSION,
            self::EVENT_CLICK,
        );
    }

    protected function formatAggregateRows(Collection $rows, string $labelKey): Collection
    {
        return $rows->map(function ($row) use ($labelKey) {
            $impressions = (int) ($row->impressions ?? 0);
            $clicks = (int) ($row->clicks ?? 0);

            return [
                $labelKey    => $row->{$labelKey} ?? null,
                'impressions'=> $impressions,
                'clicks'     => $clicks,
                'ctr'        => $this->calculateCtr($impressions, $clicks),
            ];
        })->values();
    }

    protected function calculateCtr(int $impressions, int $clicks): float
    {
        if ($impressions <= 0) {
            return 0.0;
        }

        return round(($clicks / $impressions) * 100, 2);
    }
}