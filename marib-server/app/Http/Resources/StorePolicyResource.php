<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\StorePolicy */
class StorePolicyResource extends JsonResource
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
            'policy_type' => $this->policy_type,
            'title' => $this->title,
            'content' => $this->content,
            'is_required' => (bool) $this->is_required,
            'is_active' => (bool) $this->is_active,
            'display_order' => $this->display_order,
        ];
    }
}
