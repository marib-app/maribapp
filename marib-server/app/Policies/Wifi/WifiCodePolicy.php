<?php

namespace App\Policies\Wifi;

use App\Models\User;
use App\Models\Wifi\WifiCode;

class WifiCodePolicy
{
    public function view(User $user, WifiCode $code): bool
    {
        return $this->ownsCode($user, $code);
    }

    public function update(User $user, WifiCode $code): bool
    {
        return $this->ownsCode($user, $code);
    }

    protected function ownsCode(User $user, WifiCode $code): bool
    {
        $plan = $code->relationLoaded('plan')
            ? $code->plan
            : $code->plan()->with('network:id,user_id')->first();

        if (! $plan) {
            return false;
        }

        $network = $plan->relationLoaded('network') ? $plan->network : $plan->network()->select('id', 'user_id')->first();

        return $network !== null && $network->user_id === $user->id;
    }
}