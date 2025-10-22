<?php

namespace App\Support\Payments;

use App\Models\ManualPaymentRequest;
use App\Models\PaymentTransaction;
use Illuminate\Support\Arr;
use Illuminate\Support\Str;

class PaymentLabelService
{
    public const MANUAL_GATEWAY_LABEL = 'تحويل بنكي';

    /**
     * Resolve the presentation labels for a payment transaction.
     */
    public function forPaymentTransaction(PaymentTransaction $transaction): array
    {
        $gatewayRaw = $transaction->payment_gateway;
        $normalizedGateway = $this->normalizeGateway($gatewayRaw);
        $canonicalGateway = ManualPaymentRequest::canonicalGateway($gatewayRaw);

        $isManual = $this->isManualGateway(
            $canonicalGateway,
            $normalizedGateway,
            $transaction->manual_payment_request_id !== null
        );

        if ($isManual) {
            $manualRequest = $transaction->manualPaymentRequest;
            $manualBankName = $this->resolveManualBankName(
                $manualRequest,
                is_array($transaction->meta) ? $transaction->meta : []
            );

            $bankLabel = $manualBankName ?? self::MANUAL_GATEWAY_LABEL;

            return [
                'gateway_label' => self::MANUAL_GATEWAY_LABEL,
                'bank_label' => $bankLabel,
            ];
        }

        $gatewayLabel = $this->resolveNonManualGatewayLabel(
            $canonicalGateway,
            $normalizedGateway,
            $gatewayRaw,
            is_array($transaction->meta) ? $transaction->meta : []
        );

        return [
            'gateway_label' => $gatewayLabel,
            'bank_label' => '',
        ];
    }

    /**
     * Resolve the presentation labels for a manual payment request.
     */
    public function forManualPaymentRequest(ManualPaymentRequest $manualPaymentRequest): array
    {
        $manualBankName = $this->resolveManualBankName(
            $manualPaymentRequest,
            is_array($manualPaymentRequest->meta) ? $manualPaymentRequest->meta : []
        );

        return [
            'gateway_label' => self::MANUAL_GATEWAY_LABEL,
            'bank_label' => $manualBankName ?? self::MANUAL_GATEWAY_LABEL,
        ];
    }

    private function normalizeGateway(?string $gateway): ?string
    {
        if (! is_string($gateway)) {
            return null;
        }

        $normalized = Str::of($gateway)->trim()->lower()->value();

        return $normalized === '' ? null : $normalized;
    }

    private function isManualGateway(?string $canonical, ?string $normalized, bool $hasManualRequest): bool
    {
        if ($canonical === 'manual_bank' || $canonical === 'manual_banks') {
            return true;
        }

        if ($normalized !== null) {
            $aliases = ManualPaymentRequest::manualBankGatewayAliases();

            if (in_array($normalized, $aliases, true)) {
                return true;
            }
        }

        return $hasManualRequest;
    }

    private function resolveManualBankName(?ManualPaymentRequest $manualPaymentRequest, array $meta): ?string
    {
        $candidates = [];

        if ($manualPaymentRequest) {
            $manualBank = $manualPaymentRequest->manualBank;

            if ($manualBank) {
                $candidates[] = $manualBank->name;
                $candidates[] = $manualBank->beneficiary_name ?? null;
            }

            $candidates[] = $manualPaymentRequest->bank_name;

            if (is_array($manualPaymentRequest->meta)) {
                $meta = array_merge($meta, $manualPaymentRequest->meta);
            }
        }

        $metaPaths = [
            'payload.bank_name',
            'payload.bank.name',
            'payload.bank.bank_name',
            'manual.bank.name',
            'manual.bank.bank_name',
            'manual.bank.beneficiary_name',
            'manual_bank.name',
            'manual_bank.bank_name',
            'manual_bank.beneficiary_name',
            'manual.bank_name',
            'bank.name',
            'bank.bank_name',
            'bank.beneficiary_name',
            'manualBank.name',
            'manualBank.bank_name',
            'manualBank.beneficiary_name',
        ];

        foreach ($metaPaths as $path) {
            $candidates[] = data_get($meta, $path);
        }

        foreach ($candidates as $candidate) {
            $name = $this->sanitizeBankName($candidate);

            if ($name !== null) {
                return $name;
            }
        }

        return null;
    }

    private function sanitizeBankName($value): ?string
    {
        if (! is_string($value)) {
            return null;
        }

        $trimmed = trim($value);

        if ($trimmed === '') {
            return null;
        }

        $normalized = Str::of($trimmed)->lower()->value();

        if (in_array($normalized, ManualPaymentRequest::manualBankGatewayAliases(), true)) {
            return null;
        }

        return $trimmed;
    }

    private function resolveNonManualGatewayLabel(?string $canonical, ?string $normalized, ?string $raw, array $meta): string
    {
        $canonical = $canonical === 'manual_bank' ? 'manual_banks' : $canonical;

        return match ($canonical) {
            'east_yemen_bank' => trans('East Yemen Bank'),
            'wallet' => trans('Wallet'),
            'cash' => trans('Cash'),
            default => $this->fallbackGatewayLabel($normalized, $raw, $meta),
        };
    }

    private function fallbackGatewayLabel(?string $normalized, ?string $raw, array $meta): string
    {
        $provider = $this->normalizeGateway(Arr::get($meta, 'provider'));

        if (in_array($provider, ['alsharq', 'bank_alsharq'], true)) {
            return trans('East Yemen Bank');
        }

        $channel = $this->normalizeGateway(Arr::get($meta, 'channel'));

        if (in_array($channel, ['alsharq', 'bank_alsharq'], true)) {
            return trans('East Yemen Bank');
        }

        if (is_string($raw) && trim($raw) !== '') {
            return Str::of($raw)
                ->replace(['_', '-'], ' ')
                ->trim()
                ->title()
                ->value();
        }

        if ($normalized !== null && $normalized !== '') {
            return Str::of($normalized)
                ->replace(['_', '-'], ' ')
                ->trim()
                ->title()
                ->value();
        }

        return trans('Bank Transfer');
    }
}