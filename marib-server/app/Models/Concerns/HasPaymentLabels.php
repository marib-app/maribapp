<?php

namespace App\Models\Concerns;

use App\Models\ManualPaymentRequest;
use App\Models\PaymentTransaction;
use App\Support\Payments\PaymentLabelService;

trait HasPaymentLabels
{
    private ?array $paymentLabelCache = null;

    public function getGatewayLabelAttribute(): string
    {
        return $this->resolvePaymentLabels()['gateway_label'] ?? '';
    }

    public function getBankLabelAttribute(): string
    {
        return $this->resolvePaymentLabels()['bank_label'] ?? '';
    }

    private function resolvePaymentLabels(): array
    {
        if ($this->paymentLabelCache !== null) {
            return $this->paymentLabelCache;
        }

        /** @var PaymentLabelService $service */
        $service = app(PaymentLabelService::class);

        if ($this instanceof PaymentTransaction) {
            $this->paymentLabelCache = $service->forPaymentTransaction($this);
        } elseif ($this instanceof ManualPaymentRequest) {
            $this->paymentLabelCache = $service->forManualPaymentRequest($this);
        } else {
            $this->paymentLabelCache = [
                'gateway_label' => '',
                'bank_label' => '',
            ];
        }

        return $this->paymentLabelCache;
    }
}