<?php

namespace App\Http\Resources;

use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Database\Eloquent\Model as EloquentModel;

class PaymentTransactionResource extends JsonResource
{
    public function toArray($request): array
    {

        $resource = $this->resource;
        if ($resource instanceof EloquentModel && !$resource->relationLoaded('order')) {
            $resource->load('order');
        }

        $manualPaymentRequest = $this->whenLoaded('manualPaymentRequest');
        $manualBank = $manualPaymentRequest?->manualBank;
        $order = $resource instanceof EloquentModel ? $resource->order : null;


        return [
            'id' => $this->id,
            'status' => $this->payment_status,
            'amount' => isset($this->amount) ? (float) $this->amount : null,
            'currency' => $this->currency,
            'payment_gateway' => $this->payment_gateway,
            'gateway_code' => $this->gateway_code,
            'gateway_label' => $this->gateway_label,

            'created_at' => optional($this->created_at)->toIso8601String(),

            'order' => $order ? [
                'id' => $order->id,
                'order_number' => $order->order_number,
                'payment_status' => $order->payment_status,
            ] : null,

            'manual_payment_request' => $manualPaymentRequest ? [
                'id' => $manualPaymentRequest->id,
                'status' => $manualPaymentRequest->status,
                'bank' => $manualBank ? [
                    'id' => $manualBank->id,
                    'name' => $manualBank->name,
                    'logo_url' => $manualBank->logo_url ?? null,
                ] : null,
            ] : null,
        ];
    }
}