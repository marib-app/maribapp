<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\StoreSetting */
class StoreSettingResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'closure_mode' => $this->closure_mode,
            'is_manually_closed' => (bool) $this->is_manually_closed,
            'manual_closure_reason' => $this->manual_closure_reason,
            'manual_closure_expires_at' => optional($this->manual_closure_expires_at)?->toIso8601String(),
            'min_order_amount' => $this->min_order_amount,
            'allow_pickup' => (bool) $this->allow_pickup,
            'allow_delivery' => (bool) $this->allow_delivery,
            'allow_manual_payments' => (bool) $this->allow_manual_payments,
            'allow_wallet' => (bool) $this->allow_wallet,
            'allow_cod' => (bool) $this->allow_cod,
            'auto_accept_orders' => (bool) $this->auto_accept_orders,
            'order_acceptance_buffer_minutes' => $this->order_acceptance_buffer_minutes,
            'delivery_radius_km' => $this->delivery_radius_km,
            'checkout_notice' => $this->checkout_notice,
            'preferences' => $this->preferences ?? [],
        ];
    }
}
