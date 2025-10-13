<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AdDraft extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'current_step',
        'payload',
        'step_payload',
        'temporary_media',
    ];

    protected $casts = [
        'payload' => 'array',
        'step_payload' => 'array',
        'temporary_media' => 'array',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}