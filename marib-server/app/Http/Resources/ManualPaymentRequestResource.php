<?php

namespace App\Http\Resources;

use Illuminate\Database\Eloquent\Model as EloquentModel;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\Storage; 
use Throwable;

class ManualPaymentRequestResource extends JsonResource
{
    public function toArray($request): array
    {
        $paymentTransaction = $this->whenLoaded('paymentTransaction');

        if ($paymentTransaction instanceof EloquentModel && !$paymentTransaction->relationLoaded('order')) {
            $paymentTransaction->load('order');
        }

        $manualBank = $this->whenLoaded('manualBank');
        $payable = $this->whenLoaded('payable');

        $order = $paymentTransaction?->order;
        $gatewayKey = $paymentTransaction?->payment_gateway
            ?? data_get($this->meta, 'gateway')
            ?? 'manual_bank';

        return [
            'id' => $this->id,
            'user_id' => $this->user_id,
            'manual_bank' => $manualBank ? array_merge($manualBank->toArray(), [
                'logo_url' => $this->generateSignedUrl($manualBank->logo ?? null),
                'qr_code_url' => $this->generateSignedUrl($manualBank->qr_code ?? null),
            ]) : null,
            'amount' => $this->whenNotNull($this->amount, fn() => (float) $this->amount),
            'currency' => $this->currency,
            'payment_gateway' => $gatewayKey,


            'reference' => $this->reference,
            'user_note' => $this->user_note,
            'admin_note' => $this->admin_note,
            'status' => $this->status,
            'transaction_status' => $this->normalizePaymentStatus($paymentTransaction?->payment_status),


            'receipt_url' => $this->generateSignedUrl($this->receipt_path),
            'payable' => $payable ? [
                'id' => $this->payable_id,
                'type' => class_basename($this->payable_type),
                'name' => $payable->name ?? null,
            ] : ($this->payable_id ? [
                'id' => $this->payable_id,
                'type' => class_basename((string) $this->payable_type),
            ] : null),
            'payment_transaction' => $paymentTransaction ? [
                'id' => $paymentTransaction->id,
                'status' => $this->normalizePaymentStatus($paymentTransaction->payment_status),
                'amount' => (float) $paymentTransaction->amount,
                'currency' => $paymentTransaction->currency,
                'receipt_url' => $this->generateSignedUrl($paymentTransaction->receipt_path ?? $this->receipt_path),

                'order' => $order ? [
                    'id' => $order->id,
                    'order_number' => $order->order_number,
                    'payment_status' => $order->payment_status,
                ] : null,

            ] : null,
            'reviewed_by' => $this->reviewed_by,
            'reviewed_at' => optional($this->reviewed_at)->toIso8601String(),
            'created_at' => optional($this->created_at)->toIso8601String(),
            'updated_at' => optional($this->updated_at)->toIso8601String(),
            'department' => $this->department ?? null,


        ];
    }

    protected function generateSignedUrl(?string $path): ?string
    {
        if (empty($path)) {
            return null;
        }

        $disk = Storage::disk('public');

        try {
            if (method_exists($disk, 'temporaryUrl')) {
                return $disk->temporaryUrl($path, now()->addMinutes(10));
            }
        } catch (Throwable) {
            // Driver may not support temporary URLs; fall back to standard URL below.
        }

        return url($disk->url($path));
    }



    private function normalizePaymentStatus(?string $status): ?string
    {
        if ($status === null) {
            return null;
        }

        $normalized = strtolower(trim($status));

        return match ($normalized) {
            'pending', 'processing', 'in_progress', 'in-progress', 'awaiting', 'waiting', 'on-hold' => 'pending',
            'succeed', 'success', 'succeeded', 'successful', 'approved', 'completed', 'complete', 'paid', 'done', 'captured' => 'approved',
            'failed', 'fail', 'failure', 'rejected', 'declined', 'denied', 'canceled', 'cancelled', 'void', 'refunded', 'error' => 'rejected',
            default => 'pending',
        };
    }
}
