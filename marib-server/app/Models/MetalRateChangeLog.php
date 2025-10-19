<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class MetalRateChangeLog extends Model
{
    use HasFactory;

    protected $fillable = [
        'metal_rate_id',
        'governorate_id',
        'change_type',
        'previous_values',
        'new_values',
        'changed_by',
        'changed_at',
    ];

    protected $casts = [
        'previous_values' => 'array',
        'new_values' => 'array',
        'changed_at' => 'datetime',
    ];
}