<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ReferralAttempt extends Model
{
    use HasFactory;

    protected $fillable = [
        'code',
        'status',
        'referrer_id',
        'referred_user_id',
        'referral_id',
        'challenge_id',
        'lat',
        'lng',
        'admin_area',
        'device_time',
        'contact',
        'request_ip',
        'user_agent',
        'awarded_points',
        'exception_message',
        'meta',
    ];

    protected $casts = [
        'lat' => 'float',
        'lng' => 'float',
        'awarded_points' => 'integer',
        'meta' => 'array',
    ];

    public function referrer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'referrer_id');
    }

    public function referredUser(): BelongsTo
    {
        return $this->belongsTo(User::class, 'referred_user_id');
    }

    public function referral(): BelongsTo
    {
        return $this->belongsTo(Referral::class);
    }

    public function challenge(): BelongsTo
    {
        return $this->belongsTo(Challenge::class);
    }
}