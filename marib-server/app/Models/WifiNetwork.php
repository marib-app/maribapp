<?php

namespace App\Models;
use Illuminate\Database\Eloquent\Casts\Attribute;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
class WifiNetwork extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'name',
        'slug',
        'description',
        'location_name',
        'latitude',
        'longitude',
        'commission_rate',
        'commission_flat',
        'logo_path',
        'login_screenshot_path',
        'contacts',
        'notes',
        'wallet_id',

        'is_active',
        'meta',
    ];


    protected $hidden = [
        'logo_path',
        'login_screenshot_path',
    ];

    protected $appends = [
        'logo_url',
        'login_screenshot_url',
    ];


    protected $casts = [
        'latitude' => 'float',
        'longitude' => 'float',
        'commission_rate' => 'decimal:2',
        'commission_flat' => 'decimal:2',
        'is_active' => 'boolean',
        'meta' => 'array',
        'contacts' => 'array',


    ];

    public function owner(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id');
    }


    public function wallet(): BelongsTo
    {
        return $this->belongsTo(WalletAccount::class, 'wallet_id');
    }



    public function plans(): HasMany
    {
        return $this->hasMany(WifiPlan::class);
    }

    public function codeBatches(): HasMany
    {
        return $this->hasMany(WifiCodeBatch::class);
    }

    public function codes(): HasMany
    {
        return $this->hasMany(WifiCode::class);
    }


    protected function logoUrl(): Attribute
    {
        return Attribute::make(
            get: fn () => $this->resolveStorageUrl($this->logo_path)
        );
    }

    protected function loginScreenshotUrl(): Attribute
    {
        return Attribute::make(
            get: fn () => $this->resolveStorageUrl($this->login_screenshot_path)
        );
    }



    public function effectiveCommissionRate(?WifiPlan $plan = null): float
    {
        if ($plan && $plan->commission_rate_override !== null) {
            return (float) $plan->commission_rate_override;
        }

        return (float) $this->commission_rate;
    }


    private function resolveStorageUrl(?string $path): ?string
    {
        if (! $path) {
            return null;
        }

        if (Str::startsWith($path, ['http://', 'https://'])) {
            return $path;
        }

        if (! Storage::disk('public')->exists($path)) {
            return null;
        }

        return Storage::disk('public')->url($path);
    }


    protected function contacts(): Attribute
    {
        return Attribute::make(
            set: function ($value) {
                if ($value === null) {
                    return null;
                }

                $contacts = collect(is_string($value) ? preg_split('/[\r\n,;]+/', $value) : Arr::flatten(Arr::wrap($value)))
                    ->map(static function ($contact) {
                        $contact = trim(is_string($contact) ? $contact : (string) $contact);

                        if ($contact === '') {
                            return null;
                        }

                        $normalized = preg_replace('/[^0-9+]/', '', $contact);

                        if ($normalized === '') {
                            return null;
                        }

                        if (str_starts_with($normalized, '++')) {
                            $normalized = '+' . ltrim($normalized, '+');
                        }

                        if (str_starts_with($normalized, '+')) {
                            $normalized = '+' . preg_replace('/\D/', '', substr($normalized, 1));
                        } else {
                            $normalized = preg_replace('/\D/', '', $normalized);
                        }

                        return $normalized ?: null;
                    })
                    ->filter()
                    ->unique()
                    ->values()
                    ->all();

                return $contacts === [] ? null : $contacts;
            }
        );
    }

}