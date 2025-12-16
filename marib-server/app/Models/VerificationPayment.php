<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class VerificationPayment extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'verification_request_id',
        'verification_plan_id',
        'amount',
        'currency',
        'status',
        'starts_at',
        'expires_at',
        'meta',
    ];

    protected $casts = [
        'meta' => 'array',
        'starts_at' => 'datetime',
        'expires_at' => 'datetime',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function plan()
    {
        return $this->belongsTo(VerificationPlan::class, 'verification_plan_id');
    }

    public function request()
    {
        return $this->belongsTo(VerificationRequest::class, 'verification_request_id');
    }
}
