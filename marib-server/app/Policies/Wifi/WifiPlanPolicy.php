<?php

namespace App\Policies\Wifi;

use App\Models\User;
use App\Models\Wifi\WifiPlan;

class WifiPlanPolicy
{
    public function viewAny(User $user): bool
    {
        return true;
    }

    public function view(User $user, WifiPlan $plan): bool
    {
        return $this->ownsPlan($user, $plan);
    }

    public function create(User $user): bool
    {
        return true;
    }

    public function update(User $user, WifiPlan $plan): bool
    {
        return $this->ownsPlan($user, $plan);
    }

    public function delete(User $user, WifiPlan $plan): bool
    {
        return $this->ownsPlan($user, $plan);
    }

    protected function ownsPlan(User $user, WifiPlan $plan): bool
    {
        $network = $plan->relationLoaded('network')
            ? $plan->network
            : $plan->network()->select('id', 'user_id')->first();

        return $network !== null && $network->user_id === $user->id;
    }
}