<?php

namespace App\Services;




class DeliveryPricingResult

{




    public function __construct(
        public readonly float $total,
        /** @var array<int, mixed> */
        public readonly array $breakdown = [],
        /** @var array<string, mixed> */
        public readonly array $rawData = [],
        public readonly ?int $ruleId = null,
        public readonly ?int $tierId = null,
        /** @var array<string, mixed> */
        public readonly array $paymentOptions = [],
        /** @var array<string, mixed> */
        public readonly array $timingCodes = [],
        public readonly ?string $suggestedTiming = null,
        public readonly string $currency = 'YER',
        public readonly bool $freeApplied = false,


    ) {

    }

    /**
     * @param array<string, mixed> $data
     */
    public static function fromArray(array $data): self
    {
        $rawData = $data['raw_data'] ?? $data['raw'] ?? $data;
        $payment = $data['payment'] ?? $data['payment_options'] ?? [];
        if (! is_array($payment)) {
            $payment = [];
        }

        $timing = $data['timing'] ?? [];
        if (! is_array($timing)) {
            $timing = [];
        }

        $timingCodes = $data['timing_codes'] ?? ($timing['codes'] ?? []);
        if (! is_array($timingCodes)) {
            $timingCodes = [];
        }

        $suggestedTiming = $data['suggested_timing'] ?? ($timing['suggested'] ?? null);
        if (! is_string($suggestedTiming) || $suggestedTiming === '') {
            $suggestedTiming = null;
        }


        $ruleId = $data['rule_id'] ?? null;
        $tierId = $data['tier_id'] ?? null;

        return new self(
            total: (float) ($data['total'] ?? $data['amount'] ?? 0.0),
            breakdown: is_array($data['breakdown'] ?? null) ? $data['breakdown'] : [],
            rawData: is_array($rawData) ? $rawData : [],
            ruleId: is_numeric($ruleId) ? (int) $ruleId : null,
            tierId: is_numeric($tierId) ? (int) $tierId : null,
            paymentOptions: $payment,
            timingCodes: $timingCodes,
            suggestedTiming: $suggestedTiming,
            currency: (string) ($data['currency'] ?? 'YER'),
            freeApplied: (bool) ($data['free_applied'] ?? false),
        );    
        





    }

    public function getTotal(): float



    {
        return $this->total;



    }

    /**
     * @return array<int, mixed>
     */
    public function getBreakdown(): array
    
    
    {
        return $this->breakdown;
    }


    
    /**
     * @return array<string, mixed>
     */
    public function getRawData(): array



    {
        return $this->rawData;
    }

    public function getRuleId(): ?int
    {
        return $this->ruleId;
    }

    public function getTierId(): ?int

    {
        return $this->tierId;
    }

    /**
     * @return array<string, mixed>
     */
    public function getPaymentOptions(): array
    {
        return $this->paymentOptions;
    }

    public function allowsPayNow(): bool
    {
        return (bool) ($this->paymentOptions['allow_pay_now'] ?? false);
    }

    public function allowsPayOnDelivery(): bool
    {
        return (bool) ($this->paymentOptions['allow_pay_on_delivery'] ?? false);
    }

    public function getCodFee(): ?float
    {
        $codFee = $this->paymentOptions['cod_fee'] ?? null;

        if ($codFee === null || $codFee === '') {
            return null;
        }

        return (float) $codFee;
    }

    /**
     * @return array<string, mixed>
     */
    public function getTimingCodes(): array
    {
        return $this->timingCodes;
    }

    public function getSuggestedTiming(): ?string
    {
        $suggested = $this->suggestedTiming;

        if ($suggested === null || $suggested === '') {
            return null;
        }

        return $suggested;
    
    }

}