<?php

namespace App\Http\Resources;
use App\Models\WalletTransaction;

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

        if (
            $paymentTransaction instanceof EloquentModel
            && $paymentTransaction->payableIsWalletTransaction()
            && !$paymentTransaction->relationLoaded('walletTransaction')
        ) {
            
            $paymentTransaction->load('walletTransaction');
        }



        $order = $paymentTransaction?->order;
        $walletTransaction = ($paymentTransaction instanceof EloquentModel
            && $paymentTransaction->payableIsWalletTransaction())
            ? $paymentTransaction->walletTransaction
            : null;
            
            $gatewayKey = $paymentTransaction?->payment_gateway
            ?? data_get($this->meta, 'gateway')
            ?? 'manual_bank';


        $paymentStatus = $this->normalizePaymentStatus($paymentTransaction?->payment_status);
        $manualReference = $this->reference
            ?? data_get($this->meta, 'reference')
            ?? data_get($paymentTransaction?->meta, 'manual.reference');
        $walletMeta = $paymentTransaction?->meta ?? [];
        if (empty($walletMeta)) {
            $walletMeta = is_array($this->meta) ? $this->meta : [];
        }

        $walletSnapshot = array_filter([
            'transaction_id' => data_get($walletMeta, 'wallet.transaction_id'),
            'idempotency_key' => data_get($walletMeta, 'wallet.idempotency_key'),
            'balance_after' => data_get($walletMeta, 'wallet.balance_after'),
        ], static fn ($value) => $value !== null && $value !== '');

        if ($walletTransaction instanceof WalletTransaction) {
            $walletSnapshot = array_merge([
                'transaction_id' => $walletTransaction->getKey(),
                'wallet_account_id' => $walletTransaction->wallet_account_id,
                'amount' => (float) $walletTransaction->amount,
                'currency' => $walletTransaction->currency,
            ], $walletSnapshot);
        }


        return [
            'id' => $this->id,
            'manual_payment_id' => (string) $this->id,


            'user_id' => $this->user_id,
            'manual_bank' => $manualBank ? array_merge($manualBank->toArray(), [
                'logo_url' => $this->generateSignedUrl($manualBank->logo ?? null),
                'qr_code_url' => $this->generateSignedUrl($manualBank->qr_code ?? null),
            ]) : null,
            'amount' => $this->whenNotNull($this->amount, fn() => (float) $this->amount),
            'currency' => $this->currency,
            'payment_gateway' => $gatewayKey,


            'reference' => $this->reference,
            'manual_reference' => $manualReference,
            'user_note' => $this->user_note,
            'admin_note' => $this->admin_note,
            'status' => $this->status,
            'payment_status' => $paymentStatus,
            'transaction_status' => $paymentStatus,

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
                'status' => $paymentStatus,
                'amount' => (float) $paymentTransaction->amount,
                'currency' => $paymentTransaction->currency,
                'receipt_url' => $this->generateSignedUrl($paymentTransaction->receipt_path ?? $this->receipt_path),

                'order' => $order ? [
                    'id' => $order->id,
                    'order_number' => $order->order_number,
                    'payment_status' => $order->payment_status,
                ] : null,

                'wallet_transaction' => $walletTransaction instanceof WalletTransaction ? [
                    'id' => $walletTransaction->getKey(),
                    'wallet_account_id' => $walletTransaction->wallet_account_id,
                    'amount' => (float) $walletTransaction->amount,
                    'currency' => $walletTransaction->currency,
                ] : null,


            ] : null,
            'wallet' => empty($walletSnapshot) ? null : $walletSnapshot,
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
