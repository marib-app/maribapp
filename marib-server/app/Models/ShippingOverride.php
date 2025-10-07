<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class ShippingOverride extends Model
{
    use HasFactory;

    protected $fillable = [
        'scope_type',
        'scope_id',
        'order_id',
        'user_id',
        'department',
        'region',
        'delivery_fee',
        'delivery_surcharge',
        'delivery_discount',
        'notes',
        'metadata',
        'starts_at',
        'ends_at',
    ];

    protected $casts = [
        'delivery_fee' => 'float',
        'delivery_surcharge' => 'float',
        'delivery_discount' => 'float',
        'metadata' => 'array',
        'starts_at' => 'datetime',
        'ends_at' => 'datetime',
    ];

    public function scopeActive(Builder $query): Builder
    {
        return $query->where(function (Builder $builder) {
            $builder->whereNull('starts_at')->orWhere('starts_at', '<=', now());
        })->where(function (Builder $builder) {
            $builder->whereNull('ends_at')->orWhere('ends_at', '>=', now());
        });
    }
}