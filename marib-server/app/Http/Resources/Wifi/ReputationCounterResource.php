<?php

namespace App\Http\Resources\Wifi;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\Wifi\ReputationCounter */
class ReputationCounterResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'network_id' => $this->wifi_network_id,
            'metric' => $this->metric,
            'score' => $this->score !== null ? (float) $this->score : null,
            'value' => $this->value,
            'meta' => $this->meta,
            'period_start' => $this->when($this->period_start, fn () => $this->period_start?->toDateString()),
            'period_end' => $this->when($this->period_end, fn () => $this->period_end?->toDateString()),
            'created_at' => $this->when($this->created_at, fn () => $this->created_at->toIso8601String()),
            'updated_at' => $this->when($this->updated_at, fn () => $this->updated_at->toIso8601String()),
        ];
    }
}