<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\StoreStaff */
class StoreStaffResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'email' => $this->email,
            'role' => $this->role,
            'status' => $this->status,
            'permissions' => $this->permissions ?? [],
            'invited_by' => $this->invited_by,
            'invitation_token' => $this->invitation_token,
            'accepted_at' => optional($this->accepted_at)?->toIso8601String(),
            'revoked_at' => optional($this->revoked_at)?->toIso8601String(),
        ];
    }
}
