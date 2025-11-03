<?php

namespace App\Models;

use Carbon\CarbonInterface;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\MorphTo;
use Illuminate\Database\Eloquent\Relations\Relation;
use Illuminate\Database\Eloquent\Model as BaseModel;
use App\Models\ServiceReviewReport;



class AdminNotification extends Model
{
    use HasFactory;

    public const STATUS_PENDING = 'pending';
    public const STATUS_RESOLVED = 'resolved';

    public const TYPE_MANUAL_PAYMENT_REQUEST = 'manual_payment_request';
    public const TYPE_USER_REPORT = 'user_report';
    public const TYPE_SERVICE_REQUEST = 'service_request';
    public const TYPE_SELLER_VERIFICATION = 'seller_verification_request';
    public const TYPE_ITEM_REVIEW = 'item_review';
    public const TYPE_SERVICE_REVIEW_REPORT = 'service_review_report';
    public const TYPE_CURRENCY_DATA_ALERT = 'currency_data_alert';

    protected $table = 'admin_notifications';

    public $timestamps = false;

    protected $fillable = [
        'type',
        'entity_id',
        'title',
        'status',
        'link',
        'meta',
        'created_at',
        'admin_seen_at',
    ];

    protected $casts = [
        'created_at'    => 'datetime',
        'admin_seen_at' => 'datetime',
        'meta'          => 'array',
    ];

    protected static function booted(): void
    {
        Relation::morphMap([
            self::TYPE_MANUAL_PAYMENT_REQUEST => ManualPaymentRequest::class,
            self::TYPE_USER_REPORT            => UserReports::class,
            self::TYPE_SERVICE_REQUEST        => ServiceRequest::class,
            self::TYPE_SELLER_VERIFICATION    => VerificationRequest::class,
            self::TYPE_ITEM_REVIEW            => Item::class,
            self::TYPE_SERVICE_REVIEW_REPORT  => ServiceReviewReport::class,
            self::TYPE_CURRENCY_DATA_ALERT    => CurrencyRate::class,

        ], true);
    }

    public function entity(): MorphTo
    {
        return $this->morphTo(null, 'type', 'entity_id');
    }

    public function scopePending($query)
    {
        return $query->where('status', self::STATUS_PENDING);
    }

    public static function storePendingFor(BaseModel $entity, string $type, string $title, ?string $link = null, array $meta = []): self
    {
        $attributes = [
            'title'        => $title,
            'status'       => self::STATUS_PENDING,
            'link'         => $link,
            'meta'         => empty($meta) ? null : $meta,
            'admin_seen_at'=> null,
            'created_at'   => now(),
        ];

        $notification = static::query()->updateOrCreate(
            [
                'type'      => $type,
                'entity_id' => $entity->getKey(),
            ],
            $attributes
        );

        $notification->setRelation('entity', $entity);

        return $notification;
    }

    public static function resolveFor(BaseModel $entity, string $type): ?self
    {
        $notification = static::query()
            ->where('type', $type)
            ->where('entity_id', $entity->getKey())
            ->first();

        if ($notification) {
            $notification->markAsSeen();

        }

        return $notification;
    }

    public function markAsSeen(?CarbonInterface $seenAt = null): bool
    {
        if ($this->admin_seen_at) {
            return false;
        }

        $this->forceFill([
            'status'        => self::STATUS_RESOLVED,
            'admin_seen_at' => $seenAt ?? now(),
        ]);

        return $this->save();
    }

    public function toFeedItem(): array
    {
        return [
            'id'            => $this->getKey(),
            'type'          => $this->type,
            'title'         => $this->title,
            'status'        => $this->status,
            'link'          => $this->link,
            'created_at'    => $this->created_at?->toIso8601String(),
            'admin_seen_at' => $this->admin_seen_at?->toIso8601String(),
            'meta'          => $this->meta,
        ];
    }
}