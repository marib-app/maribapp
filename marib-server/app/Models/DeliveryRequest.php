<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class DeliveryRequest extends Model
{
    use HasFactory;

    public const STATUS_PENDING = 'pending';
    public const STATUS_ASSIGNED = 'assigned';
    public const STATUS_DISPATCHED = 'dispatched';
    public const STATUS_DELIVERED = 'delivered';
    public const STATUS_CANCELED = 'canceled';

    protected $fillable = [
        'order_id',
        'status',
        'assigned_to',
        'assigned_at',
        'dispatched_at',
        'delivered_at',
        'source',
        'notes',
        'meta',
    ];

    protected $casts = [
        'assigned_at' => 'datetime',
        'dispatched_at' => 'datetime',
        'delivered_at' => 'datetime',
        'meta' => 'array',
    ];

    public function order(): BelongsTo
    {
        return $this->belongsTo(Order::class);
    }

    public function assignee(): BelongsTo
    {
        return $this->belongsTo(User::class, 'assigned_to');
    }

    public static function recordHandoff(Order $order, ?string $source = null): self
    {
        $payload = [
            'order_id' => $order->getKey(),
        ];

        $request = static::query()->firstOrCreate($payload);
        $request->fill([
            'status' => self::STATUS_PENDING,
            'source' => $source ?? 'manual_payment',
            'notes' => null,
            'meta' => array_filter([
                'payment_method' => $order->payment_method,
                'delivery_payment_timing' => $order->delivery_payment_timing,
            ]),
        ]);
        $request->save();

        return $request;
    }
}
