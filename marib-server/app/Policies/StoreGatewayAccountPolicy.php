<?php

namespace App\Policies;

use App\Models\StoreGatewayAccount;
use App\Models\User;
use Illuminate\Auth\Access\HandlesAuthorization;

class StoreGatewayAccountPolicy
{
    use HandlesAuthorization;

    public function viewAny(User $user): bool
    {
        return $user->exists;
    }

    public function view(User $user, StoreGatewayAccount $storeGatewayAccount): bool
    {
        return $storeGatewayAccount->user_id === $user->id;
    }

    public function create(User $user): bool
    {
        return $user->exists;
    }

    public function update(User $user, StoreGatewayAccount $storeGatewayAccount): bool
    {
        return $storeGatewayAccount->user_id === $user->id;
    }

    public function delete(User $user, StoreGatewayAccount $storeGatewayAccount): bool
    {
        return $storeGatewayAccount->user_id === $user->id;
    }
}