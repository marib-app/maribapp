<?php

namespace App\Http\Resources;


use App\Services\MetalIconStorageService;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\MetalRate */
class MetalRateResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {

        $resolvedQuote = $this->whenLoaded('resolvedQuote', fn () => $this->resolvedQuote);
        $resolvedGovernorate = $this->whenLoaded('resolvedGovernorate', fn () => $this->resolvedGovernorate);
        $usedFallback = (bool) $this->getAttribute('resolved_quote_used_fallback');


        return [
            'id' => $this->id,
            'metal_type' => $this->metal_type,
            'karat' => $this->karat !== null ? (float) $this->karat : null,
            'display_name' => $this->display_name,
            'buy_price' => $resolvedQuote?->buy_price !== null ? (float) $resolvedQuote->buy_price : ($this->buy_price !== null ? (float) $this->buy_price : null),
            'sell_price' => $resolvedQuote?->sell_price !== null ? (float) $resolvedQuote->sell_price : ($this->sell_price !== null ? (float) $this->sell_price : null),
            'source' => $resolvedQuote?->source ?? $this->source,
            'icon_url' => app(MetalIconStorageService::class)->getUrl($this->icon_path),
            'icon_alt' => $this->icon_alt,

            'updated_at' => $this->updated_at?->toIso8601String(),
            'created_at' => $this->created_at?->toIso8601String(),
            'quote_governorate_code' => $resolvedGovernorate?->code,
            'quote_governorate_name' => $resolvedGovernorate?->name,
            'quote_is_default' => (bool) ($resolvedQuote?->is_default ?? false),
            'quote_used_fallback' => $usedFallback,
            'quotes' => $this->whenLoaded('quotes', function () {
                return $this->quotes->map(function ($quote) {
                    $governorate = $quote->relationLoaded('governorate') ? $quote->governorate : $quote->governorate()->first();

                    return [
                        'governorate_id' => $quote->governorate_id,
                        'governorate' => $governorate ? [
                            'code' => $governorate->code,
                            'name' => $governorate->name,
                        ] : null,
                        'sell_price' => $quote->sell_price !== null ? (float) $quote->sell_price : null,
                        'buy_price' => $quote->buy_price !== null ? (float) $quote->buy_price : null,
                        'source' => $quote->source,
                        'quoted_at' => $quote->quoted_at?->toIso8601String(),
                        'is_default' => (bool) $quote->is_default,
                    ];
                });
            }),

        ];
    }
}