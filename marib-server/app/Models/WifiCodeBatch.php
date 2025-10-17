<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class WifiCodeBatch extends Model
{
    use HasFactory;

    public const STATUS_PENDING = 'pending';
    public const STATUS_PROCESSED = 'processed';
    public const STATUS_APPROVED = 'approved';
    public const STATUS_REJECTED = 'rejected';

    
    protected $fillable = [
        'wifi_network_id',
        'wifi_plan_id',
        'uploaded_by',
        'original_filename',
        'total_rows',
        'accepted_rows',
        'rejected_rows',
        'status',
        'processed_at',
        'meta',
    ];

    protected $casts = [
        'total_rows' => 'integer',
        'accepted_rows' => 'integer',
        'rejected_rows' => 'integer',
        'processed_at' => 'datetime',
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

    public function uploader(): BelongsTo
    {
        return $this->belongsTo(User::class, 'uploaded_by');
    }

    public function codes(): HasMany
    {
        return $this->hasMany(WifiCode::class);
    }
}