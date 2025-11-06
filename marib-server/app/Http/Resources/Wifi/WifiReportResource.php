<?php

namespace App\Http\Resources\Wifi;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\Wifi\WifiReport */
class WifiReportResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'network_id' => $this->wifi_network_id,
            'reported_by' => $this->reported_by,
            'assigned_to' => $this->assigned_to,
            'status' => $this->status?->value,
            'category' => $this->category,
            'priority' => $this->priority,
            'title' => $this->title,
            'description' => $this->description,
            'resolution_notes' => $this->resolution_notes,
            'attachments' => $this->attachments,
            'meta' => $this->meta,
            'reported_at' => $this->when($this->reported_at, fn () => $this->reported_at?->toIso8601String()),
            'resolved_at' => $this->when($this->resolved_at, fn () => $this->resolved_at?->toIso8601String()),
            'created_at' => $this->when($this->created_at, fn () => $this->created_at->toIso8601String()),
            'updated_at' => $this->when($this->updated_at, fn () => $this->updated_at->toIso8601String()),
        ];
    }
}