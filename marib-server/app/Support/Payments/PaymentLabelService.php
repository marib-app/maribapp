<?php

namespace App\Support\Payments;

use App\Models\ManualPaymentRequest;
use App\Models\PaymentTransaction;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\Log;

use Illuminate\Support\Str;


class PaymentLabelService
{
    /**
     * Resolve consistent channel/bank display labels for a payment transaction.
     *
     * @return array{channel_label: string|null, bank_label: string|null}
     */
    public static function forPaymentTransaction(PaymentTransaction $transaction): array

    {
        $normalizedGateway = self::normalizeGatewayKey($transaction->payment_gateway);

        if ($normalizedGateway === 'wallet') {

            return [
                'channel_label' => 'المحفظة',
                'bank_label' => null,
            ];
        }

        if (self::isManualBankGateway($normalizedGateway) || $transaction->manual_payment_request_id) {
            $bankName = self::resolveBankNameFromTransaction($transaction);

            if ($bankName === null || $bankName === '') {
                Log::warning('Bank name missing for manual bank transaction channel label.', [
                    'payment_transaction_id' => $transaction->getKey(),
                    'payment_gateway' => $transaction->payment_gateway,
                    'manual_payment_request_id' => $transaction->manual_payment_request_id,
                ]);
            }
            $label = $bankName ? trim($bankName) : '';

            return [
                'channel_label' => $label,
                'bank_label' => $label !== '' ? $label : null,
            ];
        }
        $gatewayName = self::resolveGatewayName($transaction, $normalizedGateway);

        return [
            'channel_label' => $gatewayName,
            'bank_label' => null,
        ];

    }

    /**
     * Resolve consistent channel/bank display labels for a manual payment request model.
     *
     * @return array{channel_label: string|null, bank_label: string|null}
     */
    public static function forManualPaymentRequest(ManualPaymentRequest $manualPaymentRequest): array
    
    {
        $bankName = $manualPaymentRequest->relationLoaded('manualBank')
            ? $manualPaymentRequest->manualBank?->name
            : $manualPaymentRequest->manualBank()->value('name');

        if (! is_string($bankName) || trim($bankName) === '') {
            Log::warning('Bank name missing for manual payment request channel label.', [
                'manual_payment_request_id' => $manualPaymentRequest->getKey(),
            ]);
            $bankName = '';

        }
        $label = trim((string) $bankName);

        return [
            'channel_label' => $label,
            'bank_label' => $label !== '' ? $label : null,
        ];
    }

    private static function resolveBankNameFromTransaction(PaymentTransaction $transaction): ?string

    {
        $meta = is_array($transaction->meta) ? $transaction->meta : [];

        $candidates = [
            'payload.bank_name',
            'payload.manual_bank_name',
            'payload.bank.name',
            'manual.bank.name',
            'manual.bank.bank_name',
            'manual.bank.beneficiary_name',
            'manual_bank.name',
            'manual_bank.bank_name',
            'bank.name',
            'bank.bank_name',
            'bank_name',
        ];


        foreach ($candidates as $path) {
            $value = data_get($meta, $path);
            if (is_string($value) && trim($value) !== '') {
                return trim($value);
            }
        }

        if ($transaction->relationLoaded('manualPaymentRequest')) {
            $manualPaymentRequest = $transaction->manualPaymentRequest;
        } else {
            $manualPaymentRequest = null;
        }

        if ($manualPaymentRequest instanceof ManualPaymentRequest) {
            $manualPaymentRequest->loadMissing('manualBank');
            $manualBankName = $manualPaymentRequest->manualBank?->name ?? $manualPaymentRequest->bank_name;
            if (is_string($manualBankName) && trim($manualBankName) !== '') {
                return trim($manualBankName);
            }
        } elseif ($transaction->manual_payment_request_id) {
            $manualPaymentRequest = ManualPaymentRequest::query()


                ->with('manualBank:id,name')
                ->find($transaction->manual_payment_request_id);

            $manualBankName = $manualPaymentRequest?->manualBank?->name ?? $manualPaymentRequest?->bank_name;
            if (is_string($manualBankName) && trim($manualBankName) !== '') {
                return trim($manualBankName);


            }
        }

        return null;
    }


    private static function resolveGatewayName(PaymentTransaction $transaction, ?string $normalizedGateway): string
    {
        $meta = is_array($transaction->meta) ? $transaction->meta : [];

        $candidates = array_filter([
            $transaction->payment_gateway_name ?? null,
            data_get($meta, 'gateway_display_name'),
            data_get($meta, 'gateway_name'),
            data_get($meta, 'manual.gateway_display_name'),
            data_get($meta, 'manual.gateway_name'),
            $normalizedGateway,
        ], static fn ($value) => is_string($value) && trim($value) !== '');

        if ($transaction->relationLoaded('manualPaymentRequest') && $transaction->manualPaymentRequest) {
            $manualMeta = is_array($transaction->manualPaymentRequest->meta)
                ? $transaction->manualPaymentRequest->meta
                : [];

            $candidates = array_merge($candidates, array_filter([
                data_get($manualMeta, 'gateway_display_name'),
                data_get($manualMeta, 'gateway_name'),
                $transaction->manualPaymentRequest->gateway_name ?? null,
            ], static fn ($value) => is_string($value) && trim($value) !== ''));
        }

        foreach ($candidates as $candidate) {
            $label = trim((string) $candidate);
            if ($label !== '') {
                return $label;
            }
        }

        if ($normalizedGateway !== null) {
            $mapped = Arr::get(self::gatewayDisplayMap(), $normalizedGateway);
            if (is_string($mapped) && trim($mapped) !== '') {
                return trim($mapped);
            }
        }

        return '';
    }

    private static function normalizeGatewayKey(?string $gateway): ?string
    {
        if (! is_string($gateway)) {
            return null;
        }

        $trimmed = trim($gateway);

        if ($trimmed === '') {
            return null;
        }

        $canonical = ManualPaymentRequest::canonicalGateway($trimmed);

        if ($canonical !== null && $canonical !== '') {
            return Str::lower($canonical);
        }

        return Str::lower($trimmed);
    }

    private static function isManualBankGateway(?string $normalizedGateway): bool
    {
        if ($normalizedGateway === null) {
            return false;
        }

        static $manualGateways;

        if ($manualGateways === null) {
            $manualGateways = ManualPaymentRequest::manualBankGatewayAliases();
        }

        return in_array($normalizedGateway, $manualGateways, true) || $normalizedGateway === 'manual_bank';
    }

    /**
     * @return array<string, string>
     */
    private static function gatewayDisplayMap(): array
    {
        return [
            'wallet' => 'المحفظة',
            'east_yemen_bank' => 'East Yemen Bank',
            'cash' => 'Cash',
        ];
    }

}
