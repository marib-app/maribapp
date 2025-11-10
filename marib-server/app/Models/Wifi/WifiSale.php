<?php

namespace App\Models\Wifi;

use App\Models\User;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class WifiSale extends Model
{
    use HasFactory;

    protected $table = 'wifi_sales';

    protected $fillable = [
        'wifi_network_id',
        'wifi_plan_id',
        'user_id',
        'amount_gross',
        'commission_rate',
        'commission_amount',
        'owner_share_amount',
        'currency',
        'payment_reference',
        'paid_at',
        'meta',
    ];

    protected $casts = [
        'amount_gross' => 'decimal:4',
        'commission_rate' => 'decimal:4',
        'commission_amount' => 'decimal:4',
        'owner_share_amount' => 'decimal:4',
        'paid_at' => 'datetime',
        'meta' => 'array',
    ];

    public function network(): BelongsTo
    {
        return $this->belongsTo(WifiNetwork::class, 'wifi_network_id');
    }

    public function plan(): BelongsTo
    {
        return $this->belongsTo(WifiPlan::class, 'wifi_plan_id');
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
