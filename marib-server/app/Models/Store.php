<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Support\Facades\Storage;

class Store extends Model
{
    use HasFactory;
    use SoftDeletes;

    protected $fillable = [
        'user_id',
        'name',
        'description',
        'slug',
        'status',
        'status_changed_at',
        'rejection_reason',
        'financial_policy_type',
        'financial_policy_payload',
        'contact_email',
        'contact_phone',
        'contact_whatsapp',
        'location_address',
        'location_latitude',
        'location_longitude',
        'location_city',
        'location_state',
        'location_country',
        'location_notes',
        'logo_path',
        'banner_path',
        'timezone',
        'approved_at',
        'approved_by',
        'suspended_at',
        'suspended_by',
        'meta',
    ];

    protected $casts = [
        'financial_policy_payload' => 'array',
        'location_latitude' => 'float',
        'location_longitude' => 'float',
        'status_changed_at' => 'datetime',
        'approved_at' => 'datetime',
        'suspended_at' => 'datetime',
        'meta' => 'array',
    ];

    public function owner(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    public function approvedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'approved_by');
    }

    public function suspendedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'suspended_by');
    }

    public function settings(): HasOne
    {
        return $this->hasOne(StoreSetting::class);
    }

    public function workingHours(): HasMany
    {
        return $this->hasMany(StoreWorkingHour::class);
    }

    public function policies(): HasMany
    {
        return $this->hasMany(StorePolicy::class);
    }

    public function staff(): HasMany
    {
        return $this->hasMany(StoreStaff::class);
    }

    public function statusLogs(): HasMany
    {
        return $this->hasMany(StoreStatusLog::class);
    }

    public function dailyMetrics(): HasMany
    {
        return $this->hasMany(StoreDailyMetric::class);
    }

    public function gatewayAccounts(): HasMany
    {
        return $this->hasMany(StoreGatewayAccount::class);
    }

    public function followers(): HasMany
    {
        return $this->hasMany(StoreFollower::class);
    }

    public function items(): HasMany
    {
        return $this->hasMany(Item::class);
    }

    public function orders(): HasMany
    {
        return $this->hasMany(Order::class);
    }

    public function manualPaymentRequests(): HasMany
    {
        return $this->hasMany(ManualPaymentRequest::class);
    }

    public function getLogoPathAttribute($value): ?string
    {
        if (empty($value)) {
            return null;
        }

        if (filter_var($value, FILTER_VALIDATE_URL)) {
            return $value;
        }

        return url(Storage::url($value));
    }

    public function getBannerPathAttribute($value): ?string
    {
        if (empty($value)) {
            return null;
        }

        if (filter_var($value, FILTER_VALIDATE_URL)) {
            return $value;
        }

        return url(Storage::url($value));
    }
}
