<?php

namespace App\Models;

use Carbon\CarbonInterface;
use Illuminate\Database\Eloquent\Collections\Collection;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Storage;

class CurrencyRate extends Model
{
    use HasFactory;

    protected $table = 'currency_rates';

    protected $fillable = [
        'currency_name',
        'sell_price' => 'decimal:4',
        'buy_price' => 'decimal:4',
        'last_updated_at',
        'icon_path',
        'icon_alt',
        'icon_uploaded_by',
        'icon_uploaded_at',
        'icon_removed_by',
        'icon_removed_at',
    ];

    protected $casts = [
        'last_updated_at' => 'datetime',
        'sell_price' => 'decimal:2',
        'buy_price' => 'decimal:2',
        'icon_uploaded_at' => 'datetime',
        'icon_removed_at' => 'datetime',
    ];

    protected $appends = [
        'icon_url',
    ];

    public function getIconUrlAttribute(): ?string
    {
        if (empty($this->icon_path)) {
            return null;
        }

        return Storage::disk('public')->url($this->icon_path);
    }
    public function quotes(): HasMany
    {
        return $this->hasMany(CurrencyRateQuote::class);
    }

    public function defaultQuote(): HasOne
    {
        return $this->hasOne(CurrencyRateQuote::class)->where('is_default', true);
    }



    public function hourlyHistories(): HasMany
    {
        return $this->hasMany(CurrencyRateHourlyHistory::class);
    }

    public function dailyHistories(): HasMany
    {
        return $this->hasMany(CurrencyRateDailyHistory::class);
    }



    /**
     * @return array{0: CurrencyRateQuote|null, 1: Governorate|null, 2: bool}
     */
    public function resolveQuoteForGovernorate(?Governorate $requestedGovernorate): array
    {
        /** @var Collection<int, CurrencyRateQuote> $quotes */
        $quotes = $this->relationLoaded('quotes')
            ? $this->quotes
            : $this->quotes()->with('governorate')->get();

        $resolvedQuote = null;
        $usedFallback = false;

        if ($requestedGovernorate) {
            $resolvedQuote = $quotes->firstWhere('governorate_id', $requestedGovernorate->id);
        }

        if (!$resolvedQuote) {
            $resolvedQuote = $quotes->firstWhere('is_default', true);
            if ($requestedGovernorate && $resolvedQuote) {
                $usedFallback = true;
            }
        }

        if (!$resolvedQuote) {
            $resolvedQuote = $quotes->first();
            if ($requestedGovernorate && $resolvedQuote) {
                $usedFallback = true;
            }
        }

        $governorate = $resolvedQuote?->relationLoaded('governorate')
            ? $resolvedQuote->governorate
            : ($resolvedQuote?->governorate()->first());

        return [$resolvedQuote, $governorate, $usedFallback];
    }

    public function applyDefaultQuoteSnapshot(?CurrencyRateQuote $quote): void
    {
        if (!$quote) {
            return;
        }

        $quotedAt = $quote->quoted_at instanceof CarbonInterface ? $quote->quoted_at : now();

        $this->forceFill([
            'sell_price' => $quote->sell_price,
            'buy_price' => $quote->buy_price,
            'last_updated_at' => $quotedAt,
        ])->save();
    }
}
