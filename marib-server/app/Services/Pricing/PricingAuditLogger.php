<?php

namespace App\Services\Pricing;

use App\Models\Pricing\PricingAudit;
use App\Models\Pricing\PricingDistanceRule;
use App\Models\Pricing\PricingPolicy;
use App\Models\Pricing\PricingWeightTier;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\Auth;

class PricingAuditLogger
{
    public function record(
        ?PricingPolicy $policy,
        ?PricingWeightTier $tier,
        ?PricingDistanceRule $rule,
        string $action,
        ?array $oldValues = null,
        ?array $newValues = null,
        ?string $notes = null
    ): PricingAudit {
        $payload = [
            'pricing_policy_id' => $policy?->getKey() ?? $tier?->pricing_policy_id,
            'pricing_weight_tier_id' => $tier?->getKey() ?? $rule?->pricing_weight_tier_id,
            'pricing_distance_rule_id' => $rule?->getKey(),
            'action' => $action,
            'old_values' => $oldValues ? Arr::except($oldValues, ['updated_at', 'created_at']) : null,
            'new_values' => $newValues ? Arr::except($newValues, ['updated_at', 'created_at']) : null,
            'notes' => $notes,
            'performed_by' => Auth::id(),
        ];

        return PricingAudit::create($payload);
    }
}