<?php

namespace App\Models;

use App\Models\Concerns\CreatesAdminNotificationOnCreation;
use App\Models\AdminNotification;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use function __;
use function url;

class ServiceReviewReport extends Model
{
    use HasFactory;
    use CreatesAdminNotificationOnCreation;

    protected $fillable = [
        'service_review_id',
        'reporter_id',
        'reason',
        'message',
        'status',
    ];

    protected $casts = [
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    public function review(): BelongsTo
    {
        return $this->belongsTo(ServiceReview::class, 'service_review_id');
    }

    public function reporter(): BelongsTo
    {
        return $this->belongsTo(User::class, 'reporter_id');
    }

    protected function getAdminNotificationType(): string
    {
        return AdminNotification::TYPE_SERVICE_REVIEW_REPORT;
    }

    protected function getAdminNotificationTitle(): string
    {
        $review = $this->review;
        $serviceTitle = $review?->service?->title ?? __('Service #:id', ['id' => $review?->service_id]);
        $reporter = $this->reporter?->name ?? __('User #:id', ['id' => $this->reporter_id]);

        return __('New report on service review for :service by :user', [
            'service' => $serviceTitle,
            'user' => $reporter,
        ]);
    }

    protected function getAdminNotificationLink(): ?string
    {
        return url('/service-reviews');
    }

    protected function getAdminNotificationMeta(): array
    {
        return [
            'service_review_id' => $this->service_review_id,
            'reporter_id' => $this->reporter_id,
            'status' => $this->status,
        ];
    }
}