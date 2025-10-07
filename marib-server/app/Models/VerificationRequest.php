<?php

namespace App\Models;
use App\Models\AdminNotification;
use App\Models\Concerns\NotifiesAdminOnApprovalStatus;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use function __;
use function url;


class VerificationRequest extends Model
{
    use HasFactory;
    use NotifiesAdminOnApprovalStatus;


    protected $fillable = [
        'verification_field_value_id',
        'user_id',
        'status',
        'rejection_reason'
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function verification_field_values()
    {
        return $this->hasMany(VerificationFieldValue::class, 'verification_request_id', 'id');
    }

    public function scopeOwner($query){
        return $query->where('user_id', auth()->id());
    }

    protected function getAdminNotificationType(): string
    {
        return AdminNotification::TYPE_SELLER_VERIFICATION;
    }

    protected function getAdminNotificationTitle(): string
    {
        $requester = $this->user?->name ?? __('User #:id', ['id' => $this->user_id]);

        return __('Seller verification request #:id from :user', [
            'id'   => $this->getKey(),
            'user' => $requester,
        ]);
    }

    protected function getAdminNotificationLink(): ?string
    {
        return url(sprintf('/seller-verification/verification-details/%d', $this->getKey()));
    }

    protected function getAdminNotificationMeta(): array
    {
        return [
            'user_id' => $this->user_id,
            'status'  => $this->status,
        ];
    }

    protected function getAdminNotificationPendingStatuses(): array
    {
        return ['pending', 'resubmitted'];
    }

    protected function getAdminNotificationResolvedStatuses(): array
    {
        return ['approved', 'rejected'];
    }


}
