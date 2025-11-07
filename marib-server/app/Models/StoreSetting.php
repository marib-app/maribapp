<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class StoreSetting extends Model
{
    use HasFactory;

    protected $fillable = [
        'store_id',
        'closure_mode',
        'is_manually_closed',
        'manual_closure_reason',
        'manual_closure_expires_at',
        'min_order_amount',
        'allow_pickup',
        'allow_delivery',
        'allow_manual_payments',
        'allow_wallet',
        'allow_cod',
        'auto_accept_orders',
        'order_acceptance_buffer_minutes',
        'delivery_radius_km',
        'checkout_notice',
        'preferences',
    ];

    protected $casts = [
        'is_manually_closed' => 'boolean',
        'manual_closure_expires_at' => 'datetime',
        'min_order_amount' => 'float',
        'allow_pickup' => 'boolean',
        'allow_delivery' => 'boolean',
        'allow_manual_payments' => 'boolean',
        'allow_wallet' => 'boolean',
        'allow_cod' => 'boolean',
        'auto_accept_orders' => 'boolean',
        'delivery_radius_km' => 'float',
        'preferences' => 'array',
    ];

    public function store(): BelongsTo
    {
        return $this->belongsTo(Store::class);
    }
}
