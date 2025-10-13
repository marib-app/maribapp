<?php

namespace App\Models;

use App\Models\User;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class MetalRateUpdate extends Model
{
    use HasFactory;

    public const STATUS_PENDING = 'pending';
    public const STATUS_APPLIED = 'applied';
    public const STATUS_CANCELLED = 'cancelled';

    protected $fillable = [
        'metal_rate_id',
        'buy_price',
        'sell_price',
        'source',
        'scheduled_for',
        'status',
        'applied_at',
        'cancelled_at',
        'created_by',
    ];

    protected $casts = [
        'buy_price' => 'decimal:3',
        'sell_price' => 'decimal:3',
        'scheduled_for' => 'datetime',
        'applied_at' => 'datetime',
        'cancelled_at' => 'datetime',
    ];

    public function metalRate(): BelongsTo
    {
        return $this->belongsTo(MetalRate::class);
    }

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    public function scopePending($query)
    {
        return $query->where('status', self::STATUS_PENDING);
    }

    public function markApplied(): void
    {
        $this->forceFill([
            'status' => self::STATUS_APPLIED,
            'applied_at' => now(),
        ])->save();
    }

    public function cancel(): void
    {
        $this->forceFill([
            'status' => self::STATUS_CANCELLED,
            'cancelled_at' => now(),
        ])->save();
    }

    public static function applyDueUpdates(): void
    {
        $dueUpdates = static::query()
            ->pending()
            ->where('scheduled_for', '<=', now())
            ->with('metalRate')
            ->orderBy('scheduled_for')
            ->get();

        foreach ($dueUpdates as $update) {
            if (!$update->metalRate) {
                $update->cancel();
                continue;
            }

            $update->metalRate->applyScheduledUpdate($update);
        }
    }
}