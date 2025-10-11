<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class DepartmentDelegateAudit extends Model
{
    use HasFactory;

    public const EVENT_ASSIGNED = 'assigned';
    public const EVENT_REMOVED = 'removed';

    protected $fillable = [
        'department',
        'actor_id',
        'event',
        'reason',
        'difference',
    ];

    protected $casts = [
        'difference' => 'array',
    ];
}