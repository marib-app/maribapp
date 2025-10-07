<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Str;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Casts\Attribute;
use Illuminate\Support\Collection;







class WifiPlan extends Model
{
    use HasFactory;

    protected $fillable = [
        'wifi_network_id',
        'name',
        'description',
        'duration_minutes',
        'data_allowance_mb',
        'validity_days',
        'speed_mbps',
        'price',
        'currency',
        'commission_rate_override',
        'is_active',
        'meta',
    ];

    protected $casts = [
        'duration_minutes' => 'integer',
        'data_allowance_mb' => 'integer',
        'validity_days' => 'integer',
        'speed_mbps' => 'float',
        'price' => 'decimal:2',
        'commission_rate_override' => 'decimal:2',
        'is_active' => 'boolean',
        'meta' => 'array',
    ];


    protected $appends = [
        'data_allowance_gb',
        'data_allowance_label',
        'validity_label',
        'speed_label',
        'gross_revenue_amount',
        'owner_net_amount',

    ];

    public function network(): BelongsTo
    {
        return $this->belongsTo(WifiNetwork::class, 'wifi_network_id');
    }

    public function codeBatches(): HasMany
    {
        return $this->hasMany(WifiCodeBatch::class);
    }

    public function codes(): HasMany
    {
        return $this->hasMany(WifiCode::class);
    }




    public function scopeWithCodeMetrics(Builder $query): Builder
    {
        return $query->withCount([
            'codes as available_count' => fn ($relation) => $relation->where('status', WifiCode::STATUS_AVAILABLE),
            'codes as sold_count' => fn ($relation) => $relation->whereIn('status', [
                WifiCode::STATUS_ALLOCATED,
                WifiCode::STATUS_REDEEMED,
            ]),
            'codes as total_codes',
        ]);
    }



    public function scopeWithRevenueAggregates(Builder $query): Builder
    {
        $driver = $query->getModel()->getConnection()->getDriverName();
        $grossExpression = static::revenueSumExpression($driver, 'gross_amount');
        $netExpression = static::revenueSumExpression($driver, 'net_amount');

        $codeTable = (new WifiCode())->getTable();
        $planTable = $query->getModel()->getTable();

        return $query->addSelect([
            'gross_revenue_amount' => WifiCode::query()
                ->selectRaw($grossExpression)
                ->whereColumn("{$codeTable}.wifi_plan_id", "{$planTable}.id")
                ->whereIn('status', [WifiCode::STATUS_ALLOCATED, WifiCode::STATUS_REDEEMED]),
            'owner_net_amount' => WifiCode::query()
                ->selectRaw($netExpression)
                ->whereColumn("{$codeTable}.wifi_plan_id", "{$planTable}.id")
                ->whereIn('status', [WifiCode::STATUS_ALLOCATED, WifiCode::STATUS_REDEEMED]),
        ]);
    }

    

    public static function hydrateRevenueAggregates(Collection $plans): void
    {
        if ($plans->isEmpty()) {
            return;
        }

        $planIds = $plans
            ->pluck('id')
            ->filter()
            ->unique()
            ->values();

        if ($planIds->isEmpty()) {
            return;
        }

        $driver = $plans->first()->getConnection()->getDriverName();

        $grossExpression = static::revenueSumExpression($driver, 'gross_amount');
        $netExpression = static::revenueSumExpression($driver, 'net_amount');

        $rows = WifiCode::query()
            ->selectRaw("wifi_plan_id, {$grossExpression} as gross_revenue_amount, {$netExpression} as owner_net_amount")
            ->whereIn('wifi_plan_id', $planIds)
            ->whereIn('status', [WifiCode::STATUS_ALLOCATED, WifiCode::STATUS_REDEEMED])
            ->groupBy('wifi_plan_id')
            ->get()
            ->keyBy('wifi_plan_id');

        foreach ($plans as $plan) {
            $row = $rows->get($plan->getKey());

            $plan->setAttribute('gross_revenue_amount', $row?->gross_revenue_amount ?? 0.0);
            $plan->setAttribute('owner_net_amount', $row?->owner_net_amount ?? 0.0);
        }
    }

    protected static function revenueSumExpression(string $driver, string $field): string
    {
        return match ($driver) {
            'pgsql' => "COALESCE(SUM(((meta->>'{$field}')::numeric)), 0)",
            'sqlite' => "COALESCE(SUM(CAST(json_extract(meta, '$.{$field}') AS REAL)), 0)",
            default => "COALESCE(SUM(CAST(JSON_UNQUOTE(JSON_EXTRACT(meta, '$.{$field}')) AS DECIMAL(18,2))), 0)",
        };
    }





    


    protected function dataAllowanceGb(): Attribute
    {
        return Attribute::make(
            get: fn ($value, array $attributes) => isset($attributes['data_allowance_mb'])
                ? round(((int) $attributes['data_allowance_mb']) / 1024, 2)
                : null
        );
    }

    protected function dataAllowanceLabel(): Attribute
    {
        return Attribute::make(
            get: function ($value, array $attributes) {
                $allowance = $attributes['data_allowance_mb'] ?? null;

                if ($allowance === null) {
                    return null;
                }

                $allowance = (int) $allowance;

                if ($allowance >= 1024) {
                    $gigabytes = $allowance / 1024;
                    $formatted = $this->formatDecimal($gigabytes);

                    return sprintf('%s GB', $formatted);
                }

                return sprintf('%s MB', number_format($allowance));
            }
        );
    }

    protected function validityLabel(): Attribute
    {
        return Attribute::make(
            get: function ($value, array $attributes) {
                $validity = $attributes['validity_days'] ?? null;

                if ($validity === null) {
                    return null;
                }

                $days = (int) $validity;
                $label = Str::plural('day', $days);

                return sprintf('%s %s', number_format($days), $label);
            }
        );
    }

    protected function speedLabel(): Attribute
    {
        return Attribute::make(
            get: function ($value, array $attributes) {
                $speed = $attributes['speed_mbps'] ?? null;

                if ($speed === null) {
                    return null;
                }

                $formatted = $this->formatDecimal((float) $speed);

                return sprintf('%s Mbps', $formatted);
            }
        );
    }

    protected function formatDecimal(float $value, int $precision = 2): string
    {
        $formatted = number_format($value, $precision, '.', '');

        return rtrim(rtrim($formatted, '0'), '.') ?: '0';
    }



    protected function grossRevenueAmount(): Attribute
    {
        return Attribute::make(
            get: fn ($value, array $attributes) => $this->resolveRevenueAttribute($attributes, 'gross_revenue_amount', 'gross_amount')
        );
    }

    protected function ownerNetAmount(): Attribute
    {
        return Attribute::make(
            get: fn ($value, array $attributes) => $this->resolveRevenueAttribute($attributes, 'owner_net_amount', 'net_amount')
        );
    }

    protected function resolveRevenueAttribute(array $attributes, string $attributeKey, string $metaKey): float
    {
        if (array_key_exists($attributeKey, $attributes) && $attributes[$attributeKey] !== null) {
            return round((float) $attributes[$attributeKey], 2);
        }

        if ($this->relationLoaded('codes')) {
            $sum = $this->codes
                ->whereIn('status', [WifiCode::STATUS_ALLOCATED, WifiCode::STATUS_REDEEMED])
                ->sum(fn (WifiCode $code) => (float) data_get($code->meta, $metaKey, 0));

            return round($sum, 2);
        }

        return 0.0;
    }

}