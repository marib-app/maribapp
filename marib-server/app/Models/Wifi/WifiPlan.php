<?php

namespace App\Models\Wifi;

use App\Enums\Wifi\WifiPlanStatus;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Str;

class WifiPlan extends Model
{
    use HasFactory;

    protected $table = 'wifi_plans';

    /**
     * @var array<int, string>
     */
    protected $fillable = [
        'wifi_network_id',
        'name',
        'slug',
        'status',
        'price',
        'currency',
        'duration_days',
        'data_cap_gb',
        'is_unlimited',
        'sort_order',
        'description',
        'notes',
        'benefits',
        'meta',
    ];

    protected $casts = [
        'status' => WifiPlanStatus::class,
        'price' => 'decimal:4',
        'data_cap_gb' => 'decimal:3',
        'is_unlimited' => 'boolean',
        'benefits' => 'array',
        'meta' => 'array',
    ];

    protected $attributes = [
        'status' => WifiPlanStatus::UPLOADED,
        'is_unlimited' => false,
        'sort_order' => 0,
    ];

    protected static function booted(): void
    {
        static::saving(function (self $plan): void {
            if (! blank($plan->slug)) {
                $plan->slug = Str::slug($plan->slug);
            }
        });

        static::creating(function (self $plan): void {
            if (blank($plan->slug) && ! blank($plan->name)) {
                $plan->slug = static::generateUniqueSlug($plan->name, $plan->wifi_network_id);
            }
        });
    }

    protected static function generateUniqueSlug(string $name, ?int $networkId): string
    {
        $base = Str::slug($name) ?: Str::random(8);
        $slug = $base;
        $suffix = 1;

        $query = static::query();
        if ($networkId !== null) {
            $query->where('wifi_network_id', $networkId);
        }

        while ((clone $query)->where('slug', $slug)->exists()) {
            $slug = $base . '-' . $suffix++;
        }

        return $slug;
    }

    public function setCurrencyAttribute(?string $value): void
    {
        $this->attributes['currency'] = $value !== null ? strtoupper($value) : null;
    }

    public function network(): BelongsTo
    {
        return $this->belongsTo(WifiNetwork::class, 'wifi_network_id');
    }

    public function codeBatches(): HasMany
    {
        return $this->hasMany(WifiCodeBatch::class, 'wifi_plan_id');
    }

    public function codes(): HasMany
    {
        return $this->hasMany(WifiCode::class, 'wifi_plan_id');
    }
}