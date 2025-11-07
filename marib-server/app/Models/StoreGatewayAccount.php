<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class StoreGatewayAccount extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'store_gateway_id',
        'store_id',
        'beneficiary_name',
        'account_number',
        'is_active',
    ];

    protected $casts = [
        'is_active' => 'boolean',
    ];

    public function storeGateway(): BelongsTo
    {
        return $this->belongsTo(StoreGateway::class);
    }

    public function store(): BelongsTo
    {
        return $this->belongsTo(Store::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
