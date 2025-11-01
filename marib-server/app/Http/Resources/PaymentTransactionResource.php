<?php

namespace App\Http\Resources;


use App\Models\Order;
use App\Support\ManualPayments\TransferDetailsResolver;
use App\Support\Payments\PaymentLabelService;
use Illuminate\Database\Eloquent\Model as EloquentModel;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Http\Resources\MissingValue;

class PaymentTransactionResource extends JsonResource
{
    public function toArray($request): array
    {

        $resource = $this->resource;
        if ($resource instanceof EloquentModel && ! $resource->relationLoaded('order')) {
            $resource->load('order');
        }
        if ($resource instanceof EloquentModel) {
            $resource->loadMissing(['manualPaymentRequest.manualBank']);
        }

        $manualPaymentRequest = $this->whenLoaded('manualPaymentRequest');

        if ($manualPaymentRequest instanceof MissingValue) {
            $manualPaymentRequest = null;
        }
        $manualBank = $manualPaymentRequest?->manualBank;
        $order = $resource instanceof EloquentModel ? $resource->order : null;

        $labels = $resource instanceof EloquentModel
            ? PaymentLabelService::forPaymentTransaction($resource)
            : [
                'gateway_key' => null,
                'gateway_label' => null,
                'bank_name' => null,
                'channel_label' => null,
                'bank_label' => null,
            ];

        if ($resource instanceof EloquentModel) {
            $transferDetails = TransferDetailsResolver::forPaymentTransaction($resource)->toArray();
        } else {
            $transferDetails = TransferDetailsResolver::forRow($resource)->toArray();
        }

        return [
            'id' => $this->id,
            'receipt_no' => $this->receipt_no,
            'status' => $this->payment_status,
            'amount' => isset($this->amount) ? (float) $this->amount : null,
            'currency' => $this->currency,
            'payment_gateway' => $this->payment_gateway,
            'gateway_code' => $this->gateway_code,
            'gateway_key' => $labels['gateway_key'],
            'gateway_label' => $labels['gateway_label'],
            'gateway_display' => $labels['gateway_label'],
            'channel_label' => $labels['gateway_label'],

            'bank_label' => $labels['bank_name'],
            'bank_name' => $labels['bank_name'],

            'created_at' => optional($this->created_at)->toIso8601String(),

            'order' => OrderResource::make($order instanceof Order ? $order : null),

            'manual_payment_request' => $manualPaymentRequest ? [
                'id' => $manualPaymentRequest->id,
                'status' => $manualPaymentRequest->status,
                'bank' => $manualBank ? [
                    'id' => $manualBank->id,
                    'name' => $manualBank->name,
                    'logo_url' => $manualBank->logo_url ?? null,
                ] : null,
            ] : null,
            'transfer_details' => $transferDetails,


        ];
    }
}
