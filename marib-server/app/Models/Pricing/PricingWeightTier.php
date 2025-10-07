<?php

namespace App\Models\Pricing;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class PricingWeightTier extends Model
{
    use HasFactory;
 
    protected $fillable = [
        'pricing_policy_id',
        'name',
        'min_weight',
        'max_weight',
        'base_price',
        'status',
        'price_per_km',
        'flat_fee',
        'sort_order',
        'notes',

    ];

    protected $casts = [
        'min_weight' => 'float',
        'max_weight' => 'float',
        'base_price' => 'float',
        'status' => 'boolean',

        'price_per_km' => 'float',
        'flat_fee' => 'float',
        'sort_order' => 'integer',

    ];

    public function policy(): BelongsTo
    {
        return $this->belongsTo(PricingPolicy::class, 'pricing_policy_id');
    }

    public function distanceRules(): HasMany
    {
        return $this->hasMany(PricingDistanceRule::class, 'pricing_weight_tier_id')
            ->where('applies_to', PricingDistanceRule::APPLIES_TO_WEIGHT_TIER);
        
        
        }

    public function audits(): HasMany
    {
        return $this->hasMany(PricingAudit::class, 'pricing_weight_tier_id');
    }

    public function scopeActive($query)
    {
        return $query->where('status', true);
    }
}