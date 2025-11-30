<?php

namespace App\Models\Wifi;

use App\Enums\Wifi\WifiNetworkStatus;
use App\Models\User;
use App\Models\WalletAccount;
use App\Models\Wifi\WifiCode;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Str;

class WifiNetwork extends Model
{
    use HasFactory;

    protected $table = 'wifi_networks';

    /**
     * @var array<int, string>
     */
    protected $fillable = [
        'user_id',
        'wallet_account_id',
        'name',
        'slug',
        'status',
        'reference_code',
        'latitude',
        'longitude',
        'coverage_radius_km',
        'address',
        'icon_path',
        'login_screenshot_path',
        'description',
        'notes',
        'currencies',
        'contacts',
        'meta',
        'settings',
        'statistics',
    ];

    protected $casts = [
        'status' => WifiNetworkStatus::class,
        'latitude' => 'float',
        'longitude' => 'float',
        'coverage_radius_km' => 'float',
        'currencies' => 'array',
        'contacts' => 'array',
        'meta' => 'array',
        'settings' => 'array',
        'statistics' => 'array',
    ];

    protected $attributes = [
        'status' => WifiNetworkStatus::INACTIVE,
    ];

    protected static function booted(): void
    {
        static::saving(function (self $network): void {
            if (! blank($network->slug)) {
                $network->slug = Str::slug($network->slug);
            }
        });

        static::creating(function (self $network): void {
            if (blank($network->slug) && ! blank($network->name)) {
                $network->slug = static::generateUniqueSlug($network->name);
            }

            if (blank($network->reference_code)) {
                $network->reference_code = static::generateReferenceCode();
            }
        });
    }

    protected static function generateUniqueSlug(string $name): string
    {
        $base = Str::slug($name) ?: Str::random(8);
        $slug = $base;
        $suffix = 1;

        while (static::where('slug', $slug)->exists()) {
            $slug = $base . '-' . $suffix++;
        }

        return $slug;
    }

    protected static function generateReferenceCode(): string
    {
        do {
            $code = Str::upper(Str::random(10));
        } while (static::where('reference_code', $code)->exists());

        return $code;
    }

    public function owner(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    public function walletAccount(): BelongsTo
    {
        return $this->belongsTo(WalletAccount::class, 'wallet_account_id');
    }

    public function plans(): HasMany
    {
        return $this->hasMany(WifiPlan::class, 'wifi_network_id');
    }

    public function reports(): HasMany
    {
        return $this->hasMany(WifiReport::class, 'wifi_network_id');
    }

    public function reputationCounters(): HasMany
    {
        return $this->hasMany(ReputationCounter::class, 'wifi_network_id');
    }

    public function codes(): HasMany
    {
        return $this->hasMany(WifiCode::class, 'wifi_network_id');
    }
}
