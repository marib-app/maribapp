<?php

namespace App\Models;

use App\Models\Pricing\PricingDistanceRule;
use App\Models\Pricing\PricingPolicy;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class DeliveryPrice extends PricingDistanceRule
{






    protected $table = 'pricing_distance_rules';



    protected $with = ['weightTier.policy', 'policy'];


    protected $appends = [


        'size',
        'department',



    ];

    public function weightTier(): BelongsTo
    {
        return parent::weightTier();
    }

    /**
     * نطاق للسجلات النشطة
     */
    public function getSizeAttribute(): ?string
    {
        return $this->weightTier?->name;
    }


    public function getDepartmentAttribute(): ?string
    {
        return $this->weightTier?->policy?->department ?? $this->policy?->department;
    }



    public function scopeForSize($query, string $size)

    {
        return $query->whereHas('weightTier', function ($tierQuery) use ($size) {
            $tierQuery->where('name', $size);
        });
    }

    public function scopeForPolicy($query, PricingPolicy $policy)
    {
        return $query->where(function ($query) use ($policy) {
            $query->whereHas('weightTier', function ($tierQuery) use ($policy) {
                $tierQuery->where('pricing_policy_id', $policy->getKey());
            })->orWhere('pricing_policy_id', $policy->getKey());

            
        });
    
    
    }
}