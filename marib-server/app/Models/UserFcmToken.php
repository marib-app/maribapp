<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class UserFcmToken extends Model {
    use HasFactory;

    protected $fillable = [
        'fcm_token',
        'user_id',
        'created_at',
        'updated_at',
        'platform_type',
        'last_activity_at'
    ];


    protected $casts = [
        'last_activity_at' => 'datetime',
    ];

    protected static function booted(): void
    {
        static::saving(static function (self $token): void {
            if ($token->isDirty('last_activity_at')) {
                return;
            }

            if (! $token->exists || $token->isDirty('fcm_token') || $token->isDirty('user_id')) {
                $token->last_activity_at = now();
            }
        });
    }


    public function user() {
        return $this->belongsTo(User::class);
    }
}
