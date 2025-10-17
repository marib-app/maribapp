<?php

namespace App\Models;

use App\Enums\NotificationFrequency;
use Illuminate\Database\Eloquent\Casts\Attribute;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class UserPreference extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'favorite_governorate_id',
        'currency_watchlist',
        'metal_watchlist',
        'notification_frequency',
        'currency_notification_regions',


    ];

    protected $casts = [
        'currency_watchlist' => 'array',
        'metal_watchlist' => 'array',
        'currency_notification_regions' => 'array',


    ];

    protected static function booted(): void
    {
        static::creating(function (self $preference) {
            if (empty($preference->notification_frequency)) {
                $preference->notification_frequency = NotificationFrequency::DAILY->value;
            }
        });
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function favoriteGovernorate(): BelongsTo
    {
        return $this->belongsTo(Governorate::class, 'favorite_governorate_id');
    }

    public function currencyWatchlist(): Attribute
    {
        return Attribute::make(
            get: function ($value) {
                $decoded = is_array($value) ? $value : (json_decode($value, true) ?: []);
                return collect($decoded)
                    ->map(static fn ($id) => (int) $id)
                    ->filter(static fn ($id) => $id > 0)
                    ->values()
                    ->all();
            },
            set: static fn ($value) => collect($value ?? [])
                ->map(static fn ($id) => (int) $id)
                ->filter(static fn ($id) => $id > 0)
                ->unique()
                ->values()
                ->all(),
        );
    }

    public function currencyNotificationRegions(): Attribute
    {
        return Attribute::make(
            get: function ($value) {
                $decoded = is_array($value) ? $value : (json_decode($value, true) ?: []);

                return collect($decoded)
                    ->mapWithKeys(static function ($code, $currencyId) {
                        $id = (int) $currencyId;
                        if ($id <= 0) {
                            return [];
                        }

                        $normalizedCode = is_string($code) ? trim($code) : '';
                        if ($normalizedCode === '') {
                            return [];
                        }

                        return [$id => $normalizedCode];
                    })
                    ->all();
            },
            set: static function ($value) {
                $decoded = is_array($value) ? $value : (json_decode($value, true) ?: []);

                return collect($decoded)
                    ->mapWithKeys(static function ($code, $currencyId) {
                        $id = (int) $currencyId;
                        if ($id <= 0) {
                            return [];
                        }

                        $normalizedCode = is_string($code) ? trim($code) : '';
                        if ($normalizedCode === '') {
                            return [];
                        }

                        return [$id => $normalizedCode];
                    })
                    ->all();
            }
        );
    }


    public function metalWatchlist(): Attribute
    {
        return Attribute::make(
            get: function ($value) {
                $decoded = is_array($value) ? $value : (json_decode($value, true) ?: []);
                return collect($decoded)
                    ->map(static fn ($id) => (int) $id)
                    ->filter(static fn ($id) => $id > 0)
                    ->values()
                    ->all();
            },
            set: static fn ($value) => collect($value ?? [])
                ->map(static fn ($id) => (int) $id)
                ->filter(static fn ($id) => $id > 0)
                ->unique()
                ->values()
                ->all(),
        );
    }

    public function getNotificationFrequencyAttribute(?string $value): string
    {
        $frequency = NotificationFrequency::tryFrom($value ?? '') ?? NotificationFrequency::DAILY;

        return $frequency->value;
    }

    public function setNotificationFrequencyAttribute(?string $value): void
    {
        $frequency = NotificationFrequency::tryFrom((string) $value) ?? NotificationFrequency::DAILY;
        $this->attributes['notification_frequency'] = $frequency->value;
    }
}