<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class NotificationDelivery extends Model
{
    use HasFactory;

    public const STATUS_QUEUED = 'queued';
    public const STATUS_SENT = 'sent';
    public const STATUS_DELIVERED = 'delivered';
    public const STATUS_FAILED = 'failed';
    public const STATUS_SKIPPED = 'skipped';

    protected $fillable = [
        'campaign_id',
        'segment_id',
        'notification_id',
        'user_id',
        'type',
        'fingerprint',
        'collapse_key',
        'deeplink',
        'priority',
        'ttl',
        'status',
        'delivered_at',
        'opened_at',
        'clicked_at',
        'reactivated_at',
        'meta',
        'device',
        'payload',
    ];

    protected $casts = [
        'meta' => 'array',
        'payload' => 'array',
        'device' => 'array',
        'delivered_at' => 'datetime',
        'opened_at' => 'datetime',
        'clicked_at' => 'datetime',
        'reactivated_at' => 'datetime',
    ];

    public function campaign(): BelongsTo
    {
        return $this->belongsTo(Campaign::class);
    }

    public function segment(): BelongsTo
    {
        return $this->belongsTo(CampaignSegment::class, 'segment_id');
    }

    public function notification(): BelongsTo
    {
        return $this->belongsTo(Notifications::class, 'notification_id');
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
