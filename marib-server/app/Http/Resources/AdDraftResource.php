<?php

namespace App\Http\Resources;

use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\AdDraft */
class AdDraftResource extends JsonResource
{
    public function toArray($request): array
    {
        return [
            'id' => $this->id ? (string) $this->id : null,
            'user_id' => $this->user_id,
            'current_step' => $this->current_step,
            'payload' => $this->payload ?? [],
            'step_payload' => $this->step_payload ?? [],
            'temporary_media' => $this->temporary_media ?? [],
            'created_at' => optional($this->created_at)->toIso8601String(),
            'updated_at' => optional($this->updated_at)->toIso8601String(),
        ];
    }
}