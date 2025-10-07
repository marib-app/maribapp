<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builders\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Support\Str;

class Campaign extends Model
{
    use HasFactory;
    use SoftDeletes;

    public const STATUS_DRAFT = 'draft';
    public const STATUS_SCHEDULED = 'scheduled';
    public const STATUS_ACTIVE = 'active';
    public const STATUS_PAUSED = 'paused';
    public const STATUS_COMPLETED = 'completed';

    public const TRIGGER_MANUAL = 'manual';
    public const TRIGGER_SCHEDULED = 'scheduled';
    public const TRIGGER_EVENT = 'event';

    protected $table = 'marketing_campaigns';

    protected $fillable = [
        'name',
        'slug',
        'status',
        'trigger_type',
        'event_key',
        'scheduled_at',
        'timezone',
        'notification_title',
        'notification_body',
        'cta_label',
        'cta_destination',
        'metadata',
        'last_dispatched_at',
    ];

    protected $casts = [
        'metadata' => 'array',
        'scheduled_at' => 'datetime',
        'last_dispatched_at' => 'datetime',
    ];

    protected static function booted(): void
    {
        static::creating(function (self $campaign): void {
            if (empty($campaign->slug)) {
                $campaign->slug = Str::slug($campaign->name) . '-' . Str::random(6);
            }
        });
    }

    public function segments(): HasMany
    {
        return $this->hasMany(CampaignSegment::class);
    }

    public function events(): HasMany
    {
        return $this->hasMany(CampaignEvent::class);
    }

    public function deliveries(): HasMany
    {
        return $this->hasMany(NotificationDelivery::class);
    }

    public function scopeActive(Builder $query): Builder
    {
        return $query->where('status', self::STATUS_ACTIVE);
    }

    public function isScheduled(): bool
    {
        return $this->trigger_type === self::TRIGGER_SCHEDULED && $this->scheduled_at !== null;
    }

    public function isEventDriven(): bool
    {
        return $this->trigger_type === self::TRIGGER_EVENT && !empty($this->event_key);
    }
}