<?php

namespace App\Http\Resources;

use Illuminate\Http\Resources\Json\JsonResource;

class SliderResource extends JsonResource
{ 
    /**
     * Transform the resource into an array.
     */
    public function toArray($request): array
    {
        $targetSummary = $this->targetSummary();

        return [
            'id'                => (int) $this->id,
            'image'             => $this->image,
            'sequence'          => (int) $this->sequence,
            'interface_type'    => $this->interface_type,
            'interface_type_label' => $this->destinationTypeLabel(),
            'third_party_link'  => $this->third_party_link,
            'action_type'       => $this->action_type,
            'action_payload'    => $this->action_payload ?? null,
            'target_type'       => $this->target_type ?? $this->model_type,
            'target_id'         => $this->target_id ?? $this->model_id,
            'destination'       => [
                'type'  => $this->destinationKind(),
                'label' => $this->destinationLabel(),
                'url'   => $this->destinationUrl(),
            ],
            'target'            => $targetSummary,
            'model_type'        => $this->model_type,
            'model_id'          => $this->model_id,
            'model'             => $this->whenLoaded('model'),
            'target_model'      => $this->whenLoaded('target'),
            'created_at'        => optional($this->created_at)->toISOString(),
            'updated_at'        => optional($this->updated_at)->toISOString(),
        ];
    }
}