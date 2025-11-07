<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class StoreStaff extends Model
{
    use HasFactory;

    protected $fillable = [
        'store_id',
        'user_id',
        'email',
        'role',
        'status',
        'permissions',
        'invitation_token',
        'invited_by',
        'accepted_at',
        'revoked_at',
    ];

    protected $casts = [
        'permissions' => 'array',
        'accepted_at' => 'datetime',
        'revoked_at' => 'datetime',
    ];

    public function store(): BelongsTo
    {
        return $this->belongsTo(Store::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function inviter(): BelongsTo
    {
        return $this->belongsTo(User::class, 'invited_by');
    }
}
