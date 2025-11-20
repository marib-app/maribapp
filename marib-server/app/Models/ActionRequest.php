<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ActionRequest extends Model
{
    use HasFactory;

    public $incrementing = false;

    protected $keyType = 'string';

    protected $fillable = [
        'id',
        'user_id',
        'kind',
        'entity',
        'entity_id',
        'amount',
        'currency',
        'status',
        'due_at',
        'expires_at',
        'meta',
        'hmac_token',
        'used_at',
        'used_ip',
        'used_device',
    ];

    protected $casts = [
        'amount' => 'decimal:2',
        'meta' => 'array',
        'due_at' => 'datetime',
        'expires_at' => 'datetime',
        'used_at' => 'datetime',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
