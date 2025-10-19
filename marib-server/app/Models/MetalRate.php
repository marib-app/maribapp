<?php

namespace App\Models;

use Carbon\CarbonInterface;
use Illuminate\Database\Eloquent\Collections\Collection;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Str;

class MetalRate extends Model
{
    use HasFactory;

    public const TYPE_GOLD = 'gold';
    public const TYPE_SILVER = 'silver';

    protected $fillable = [
        'metal_type',
        'karat',
        'buy_price',
        'sell_price',
        'source',
        'icon_path',
        'icon_alt',
        'icon_uploaded_by',
        'icon_uploaded_at',
        'icon_removed_by',
        'icon_removed_at',
        'quoted_at',
    ];

    protected $casts = [
        'karat' => 'decimal:2',
        'buy_price' => 'decimal:3',
        'sell_price' => 'decimal:3',
        'quoted_at' => 'datetime',
        'icon_uploaded_at' => 'datetime',
        'icon_removed_at' => 'datetime',
    ];

    public function updates(): HasMany
    {
        return $this->hasMany(MetalRateUpdate::class);
    }

    public function pendingUpdates(): HasMany
    {
        return $this->updates()->where('status', MetalRateUpdate::STATUS_PENDING);
    }

    public function scopeForType($query, string $type)
    {
        return $query->where('metal_type', $type);
    }

    public function refreshDueSchedules(): ?MetalRateUpdate
    {
        /** @var Collection<int, MetalRateUpdate> $due */
        $due = $this->pendingUpdates()
            ->where('scheduled_for', '<=', now())
            ->orderBy('scheduled_for')
            ->limit(1)
            ->get();

        if ($due->isEmpty()) {
            return null;
        }

        /** @var MetalRateUpdate $update */
        $update = $due->first();
        $this->applyScheduledUpdate($update);

        return $update;
    }

    public function applyScheduledUpdate(MetalRateUpdate $update): void
    {
        $this->forceFill([
            'buy_price' => $update->buy_price,
            'sell_price' => $update->sell_price,
            'source' => $update->source,
            'quoted_at' => $update->scheduled_for instanceof CarbonInterface
                ? $update->scheduled_for
                : now(),
        ])->save();

        $update->markApplied();
    }

    public function getDisplayNameAttribute(): string
    {
        $typeName = match ($this->metal_type) {
            self::TYPE_GOLD => __('ذهب'),
            self::TYPE_SILVER => __('فضة'),
            default => Str::headline($this->metal_type),
        };

        if ($this->metal_type === self::TYPE_GOLD && $this->karat !== null) {
            $karatValue = Str::of((string) $this->karat)->rtrim('0')->rtrim('.');
            return __('ذهب عيار :karat', ['karat' => $karatValue]);
        }

        return $typeName;
    }
}