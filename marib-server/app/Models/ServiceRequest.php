<?php

namespace App\Models;
use App\Models\AdminNotification;
use App\Models\Concerns\NotifiesAdminOnApprovalStatus;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;
use function __;
use function url;


class ServiceRequest extends Model
{
    use HasFactory;
    use NotifiesAdminOnApprovalStatus;

    use SoftDeletes;

    protected $fillable = [
        'service_id',
        'user_id',
        'status',
        'payment_status',
        'payment_transaction_id',
        'payload',
        'note',
        'rejected_reason',
        'request_number',
    ];

    protected $casts = [
        'payload' => 'array',
    ];

    /** الخدمة المرتبطة بالطلب */
    public function service(): BelongsTo
    {
        return $this->belongsTo(Service::class);
    }

    /** المستخدم الذي أرسل الطلب */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    protected function getAdminNotificationType(): string
    {
        return AdminNotification::TYPE_SERVICE_REQUEST;
    }

    protected function getAdminNotificationTitle(): string
    {
        $serviceTitle = $this->service?->title ?? __('Service #:id', ['id' => $this->service_id]);
        $requester = $this->user?->name ?? __('User #:id', ['id' => $this->user_id]);

        return __('Service request #:id for :service by :user', [
            'id'      => $this->getKey(),
            'service' => $serviceTitle,
            'user'    => $requester,
        ]);
    }

    protected function getAdminNotificationLink(): ?string
    {
        return route('service.requests.review', $this->getKey());
    }

    protected function getAdminNotificationMeta(): array
    {
        return [
            'service_id' => $this->service_id,
            'user_id'    => $this->user_id,
            'status'     => $this->status,
        ];
    }

    protected function getAdminNotificationPendingStatus(): string
    {
        return 'review';
    }

    protected function getAdminNotificationResolvedStatuses(): array
    {
        return ['approved', 'rejected'];
    }

}
