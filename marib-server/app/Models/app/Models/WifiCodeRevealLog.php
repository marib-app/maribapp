<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class WifiCodeRevealLog extends Model
{
    use HasFactory;

    protected $fillable = [
        'wifi_code_id',
        'user_id',
        'action',
        'ip_address',
        'user_agent',
        'meta',
    ];

    protected $casts = [
        'meta' => 'array',
    ];

    public function code(): BelongsTo
    {
        return $this->belongsTo(WifiCode::class, 'wifi_code_id');
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}