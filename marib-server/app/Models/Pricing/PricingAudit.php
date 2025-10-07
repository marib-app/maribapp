<?php

namespace App\Models\Pricing;

use App\Models\User;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PricingAudit extends Model
{
    use HasFactory;

    protected $fillable = [
        'pricing_policy_id',
        'pricing_weight_tier_id',
        'pricing_distance_rule_id',
        'action',
        'old_values',
        'new_values',
        'notes',
        'performed_by',
    ];

    protected $casts = [
        'old_values' => 'array',
        'new_values' => 'array',
    ];

    public function policy(): BelongsTo
    {
        return $this->belongsTo(PricingPolicy::class, 'pricing_policy_id');
    }

    public function weightTier(): BelongsTo
    {
        return $this->belongsTo(PricingWeightTier::class, 'pricing_weight_tier_id');
    }

    public function distanceRule(): BelongsTo
    {
        return $this->belongsTo(PricingDistanceRule::class, 'pricing_distance_rule_id');
    }

    public function actor(): BelongsTo
    {
        return $this->belongsTo(User::class, 'performed_by');
    }
}