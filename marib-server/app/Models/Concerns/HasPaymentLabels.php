<?php

namespace App\Models\Concerns;

use App\Models\ManualPaymentRequest;
use App\Models\PaymentTransaction;
use App\Support\Payments\PaymentLabelService;

trait HasPaymentLabels
{
    private ?array $paymentLabelCache = null;

    public function getGatewayLabelAttribute(): ?string
    {
        return $this->resolvePaymentLabels()['gateway_label'] ?? null;
    }

    public function getChannelLabelAttribute(): ?string
    {
        return $this->resolvePaymentLabels()['gateway_label'] ?? null;
    }

    public function getGatewayKeyAttribute(): ?string
    {
        return $this->resolvePaymentLabels()['gateway_key'] ?? null;
    
    
    }

    public function getBankLabelAttribute(): ?string
    {
        return $this->resolvePaymentLabels()['bank_name'] ?? null;
    }

    public function getManualBankNameAttribute(): ?string
    {
        return $this->resolvePaymentLabels()['bank_name'] ?? null;
    
    }

    private function resolvePaymentLabels(): array
    {
        if ($this->paymentLabelCache !== null) {
            return $this->paymentLabelCache;
        }

        if ($this instanceof PaymentTransaction) {
            $this->paymentLabelCache = PaymentLabelService::forPaymentTransaction($this);
        } elseif ($this instanceof ManualPaymentRequest) {
            $this->paymentLabelCache = PaymentLabelService::forManualPaymentRequest($this);
        } else {
            $this->paymentLabelCache = [
                'gateway_key' => null,
                'gateway_label' => null,
                'bank_name' => null,
                'channel_label' => null,
                'bank_label' => null,
            ];
        }

        return $this->paymentLabelCache;
    }
}