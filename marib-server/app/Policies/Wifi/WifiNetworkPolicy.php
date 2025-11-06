<?php

namespace App\Policies\Wifi;

use App\Models\User;
use App\Models\Wifi\WifiNetwork;

class WifiNetworkPolicy
{
    public function viewAny(User $user): bool
    {
        return true;
    }

    public function view(User $user, WifiNetwork $network): bool
    {
        return $user->id === $network->user_id;
    }

    public function create(User $user): bool
    {
        return true;
    }

    public function update(User $user, WifiNetwork $network): bool
    {
        return $user->id === $network->user_id;
    }

    public function delete(User $user, WifiNetwork $network): bool
    {
        return $user->id === $network->user_id;
    }

    public function stats(User $user, WifiNetwork $network): bool
    {
        return $this->view($user, $network);
    }
}