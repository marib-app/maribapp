<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class StoreWorkingHour extends Model
{
    use HasFactory;

    protected $fillable = [
        'store_id',
        'weekday',
        'is_open',
        'opens_at',
        'closes_at',
    ];

    protected $casts = [
        'weekday' => 'integer',
        'is_open' => 'boolean',
    ];

    public function store(): BelongsTo
    {
        return $this->belongsTo(Store::class);
    }
}
