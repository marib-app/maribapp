<?php

namespace App\Models\Pricing;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PricingDistanceRule extends Model
{
    use HasFactory;


    public const PRICE_TYPE_FLAT = 'flat';
    public const PRICE_TYPE_PER_KM = 'per_km';

    public const APPLIES_TO_POLICY = 'policy';
    public const APPLIES_TO_WEIGHT_TIER = 'weight_tier';

    protected $fillable = [
        'pricing_policy_id',


        'pricing_weight_tier_id',
        'min_distance',
        'max_distance',
        'price',
        'currency',
        'is_free_shipping',
        'status',
        'price_type',
        'applies_to',
        'sort_order',
        'notes',
        


    ];

    protected $casts = [
        'min_distance' => 'float',
        'max_distance' => 'float',
        'price' => 'float',
        'is_free_shipping' => 'boolean',
        'status' => 'boolean',

        'sort_order' => 'integer',
    ];

    protected $attributes = [
        'price_type' => self::PRICE_TYPE_FLAT,
        'applies_to' => self::APPLIES_TO_WEIGHT_TIER,

    ];

    public function weightTier(): BelongsTo
    {
        return $this->belongsTo(PricingWeightTier::class, 'pricing_weight_tier_id');
    }



    public function policy(): BelongsTo
    {
        return $this->belongsTo(PricingPolicy::class, 'pricing_policy_id');
    }



    public function scopeActive($query)
    {
        return $query->where('status', true)
            ->where(function ($query) {
                $query->where(function ($tierQuery) {
                    $tierQuery->where('applies_to', self::APPLIES_TO_WEIGHT_TIER)
                        ->whereHas('weightTier', function ($weightTierQuery) {
                            $weightTierQuery->where('status', true)
                                ->whereHas('policy', function ($policyQuery) {
                                    $policyQuery->where('status', PricingPolicy::STATUS_ACTIVE);
                                });
                        });
                })->orWhere(function ($policyQuery) {
                    $policyQuery->where('applies_to', self::APPLIES_TO_POLICY)
                        ->whereHas('policy', function ($policyRelation) {
                            $policyRelation->where('status', PricingPolicy::STATUS_ACTIVE);
                        });
                });


            });
    }

    public function scopeDepartment($query, ?string $department)
    {
        if ($department === null) {
            return $query;
        }

        return $query->where(function ($query) use ($department) {
            $query->whereHas('weightTier.policy', function ($policyQuery) use ($department) {
                $policyQuery->where('department', $department);
            })->orWhereHas('policy', function ($policyQuery) use ($department) {
                $policyQuery->where('department', $department);
            });


        });
    }
}