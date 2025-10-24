<?php

namespace App\Models;

use App\Events\MetalRateUpdated;
use App\Services\MetalRateQuoteService;
use Carbon\CarbonInterface;
use Illuminate\Database\Eloquent\Collections\Collection;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Support\Str;

class MetalRate extends Model
{
    use HasFactory;

    public const TYPE_GOLD = 'gold';
    public const TYPE_SILVER = 'silver';

    protected $fillable = [
        'metal_type',
        'karat',
        'icon_path',
        'icon_alt',
        'icon_uploaded_by',
        'icon_uploaded_at',
        'icon_removed_by',
        'icon_removed_at',
    ];

    protected $casts = [
        'karat' => 'decimal:2',
        'buy_price' => 'decimal:3',
        'sell_price' => 'decimal:3',
        'quoted_at' => 'datetime',
        'icon_uploaded_at' => 'datetime',
        'icon_removed_at' => 'datetime',
    ];

    public function updates(): HasMany
    {
        return $this->hasMany(MetalRateUpdate::class);
    }

    public function quotes(): HasMany
    {
        return $this->hasMany(MetalRateQuote::class);
    }

    public function defaultQuote(): HasOne
    {
        return $this->hasOne(MetalRateQuote::class)->where('is_default', true);
    }


    public function pendingUpdates(): HasMany
    {
        return $this->updates()->where('status', MetalRateUpdate::STATUS_PENDING);
    }

    public function scopeForType($query, string $type)
    {
        return $query->where('metal_type', $type);
    }

    public function refreshDueSchedules(): ?MetalRateUpdate
    {
        /** @var Collection<int, MetalRateUpdate> $due */
        $due = $this->pendingUpdates()
            ->where('scheduled_for', '<=', now())
            ->orderBy('scheduled_for')
            ->limit(1)
            ->get();

        if ($due->isEmpty()) {
            return null;
        }

        /** @var MetalRateUpdate $update */
        $update = $due->first();
        $this->applyScheduledUpdate($update);

        return $update;
    }

    public function applyScheduledUpdate(MetalRateUpdate $update): void
    {
        $quotedAt = $update->scheduled_for instanceof CarbonInterface
            ? $update->scheduled_for
            : now();

        /** @var MetalRateQuoteService $quoteService */
        $quoteService = app(MetalRateQuoteService::class);
        $defaultGovernorateId = $quoteService->resolveDefaultGovernorateId();

        $quoteService->syncQuotes(
            $this,
            [[
                'governorate_id' => $defaultGovernorateId,
                'sell_price' => $update->sell_price,
                'buy_price' => $update->buy_price,
                'source' => $update->source,
                'quoted_at' => $quotedAt,
            ]],
            $defaultGovernorateId,
            $update->created_by
        );

        $update->markApplied();


        $this->load('quotes.governorate');

        $quotesPayload = $this->quotes
            ->map(static function ($quote) {
                $governorate = $quote->relationLoaded('governorate')
                    ? $quote->governorate
                    : $quote->governorate()->first();

                return [
                    'governorate_id' => (int) $quote->governorate_id,
                    'governorate_code' => $governorate?->code
                        ? Str::upper((string) $governorate->code)
                        : null,
                    'governorate_name' => $governorate?->name,
                    'sell_price' => $quote->sell_price !== null
                        ? (string) $quote->sell_price
                        : null,
                    'buy_price' => $quote->buy_price !== null
                        ? (string) $quote->buy_price
                        : null,
                    'is_default' => (bool) $quote->is_default,
                ];
            })
            ->values()
            ->all();

        $eventGovernorateId = (int) ($this->quotes->firstWhere('is_default', true)?->governorate_id
            ?? $this->quotes->first()?->governorate_id
            ?? $defaultGovernorateId);

        if (!empty($quotesPayload) && $eventGovernorateId > 0) {
            MetalRateUpdated::dispatch(
                $this->getKey(),
                $quotesPayload,
                $eventGovernorateId
            );
        }

    }

    public function getDisplayNameAttribute(): string
    {
        $typeName = match ($this->metal_type) {
            self::TYPE_GOLD => __('ذهب'),
            self::TYPE_SILVER => __('فضة'),
            default => Str::headline($this->metal_type),
        };

        if ($this->metal_type === self::TYPE_GOLD && $this->karat !== null) {
            $karatValue = Str::of((string) $this->karat)->rtrim('0')->rtrim('.');
            return __('ذهب عيار :karat', ['karat' => $karatValue]);
        }

        return $typeName;
    }



    /**
     * @return array{0: MetalRateQuote|null, 1: Governorate|null, 2: bool}
     */
    public function resolveQuoteForGovernorate(?Governorate $requestedGovernorate): array
    {
        /** @var Collection<int, MetalRateQuote> $quotes */
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

    public function applyDefaultQuoteSnapshot(?MetalRateQuote $quote): void
    {
        if (!$quote) {
            return;
        }

        $quotedAt = $quote->quoted_at instanceof CarbonInterface ? $quote->quoted_at : now();

        $this->forceFill([
            'sell_price' => $quote->sell_price,
            'buy_price' => $quote->buy_price,
            'source' => $quote->source,
            'quoted_at' => $quotedAt,
        ])->save();
    }

}