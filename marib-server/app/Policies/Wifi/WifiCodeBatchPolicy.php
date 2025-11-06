<?php

namespace App\Policies\Wifi;

use App\Models\User;
use App\Models\Wifi\WifiCodeBatch;

class WifiCodeBatchPolicy
{
    public function view(User $user, WifiCodeBatch $batch): bool
    {
        return $this->ownsBatch($user, $batch);
    }

    public function update(User $user, WifiCodeBatch $batch): bool
    {
        return $this->ownsBatch($user, $batch);
    }

    public function delete(User $user, WifiCodeBatch $batch): bool
    {
        return $this->ownsBatch($user, $batch);
    }

    protected function ownsBatch(User $user, WifiCodeBatch $batch): bool
    {
        $plan = $batch->relationLoaded('plan')
            ? $batch->plan
            : $batch->plan()->with('network:id,user_id')->first();

        if (! $plan) {
            return false;
        }

        $network = $plan->relationLoaded('network') ? $plan->network : $plan->network()->select('id', 'user_id')->first();

        return $network !== null && $network->user_id === $user->id;
    }
}