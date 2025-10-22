<?php

namespace App\Services\Payments;

use App\Models\ManualBank;
use App\Models\ManualPaymentRequest;
use App\Models\PaymentTransaction;
use App\Models\WalletTransaction;
use Illuminate\Contracts\Support\Arrayable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Arr;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Str;

class GatewayLabelService
{
    public const BANK_LABEL_JSON_PATHS = [
        '$.payload.bank_name',
        '$.payload.bank.name',
        '$.manual_bank.name',
        '$.manual_bank.bank_name',
        '$.manual_bank.beneficiary_name',
        '$.manual.bank.name',
        '$.manual.bank.bank_name',
        '$.manual.bank.beneficiary_name',
    ];

    private const WALLET_LABEL = 'المحفظة';

    private const EAST_YEMEN_ALIASES = [
        'east_yemen_bank',
        'east-yemen-bank',
        'east',
        'eastyemenbank',
        'bankalsharq',
        'bank_alsharq',
        'bank-alsharq',
        'bank alsharq',
        'bankalsharqbank',
        'bank_alsharq_bank',
        'bank-alsharq-bank',
        'bank alsharq bank',
        'alsharq',
        'al-sharq',
        'al sharq',
    ];

    private const CASH_ALIASES = [
        'cash',
        'cod',
        'cash_on_delivery',
        'cashcollection',
        'cash_collect',
    ];

    private const WALLET_ALIASES = [
        'wallet',
        'wallet_balance',
        'wallet-balance',
        'wallet balance',
        'wallet_gateway',
        'wallet-gateway',
        'wallet gateway',
        'wallet_top_up',
        'wallet-top-up',
        'wallet top up',
        'wallettopup',
        'walletpayment',
        'wallet payment',
        'wallet_payment',
        'wallet-payment',
    ];

    /**
     * @var array<int, ManualPaymentRequest>
     */
    private array $manualPaymentRequestCache = [];

    /**
     * @var array<int, PaymentTransaction>
     */
    private array $paymentTransactionCache = [];

    /**
     * @var array<int, WalletTransaction>
     */
    private array $walletTransactionCache = [];

    /**
     * @var array<int, array<int, string>>
     */
    private array $manualBankLookupCache = [];

    public function labelForTransaction(?PaymentTransaction $transaction, array $context = []): string
    {
        if (! $transaction instanceof PaymentTransaction) {
            return '';
        }

        $channel = $this->resolveChannel(
            Arr::get($context, 'channel'),
            $this->normalizeGateway($transaction->payment_gateway, $transaction->manual_payment_request_id !== null),
            $transaction->payable_type
        );

        if ($channel === 'wallet') {
            return self::WALLET_LABEL;
        }

        if ($channel === 'manual_banks') {
            $candidates = array_merge(
                $this->manualBankCandidatesFromContext($context),
                $this->manualBankCandidatesFromTransaction($transaction, $context)
            );

            $label = $this->firstLabel($candidates);

            return $label ?? '';
        }

        $gatewayKey = Arr::get($context, 'gateway_key');
        if (! is_string($gatewayKey) || trim($gatewayKey) === '') {
            $gatewayKey = $this->normalizeGateway($transaction->payment_gateway, $transaction->manual_payment_request_id !== null);
        }

        return $gatewayKey !== null ? trim((string) $gatewayKey) : '';
    }

    public function labelForRow(object|array $row): string
    {
        if ($row instanceof PaymentTransaction) {
            return $this->labelForTransaction($row);
        }

        if ($row instanceof ManualPaymentRequest) {
            return $this->labelForManualPaymentRequest($row);
        }

        if ($row instanceof WalletTransaction) {
            return $this->labelForWalletTransaction($row);
        }

        $data = $this->convertRowToArray($row);

        $channel = $this->resolveChannel(
            Arr::get($data, 'channel'),
            $this->normalizeGateway(
                Arr::get($data, 'payment_gateway', Arr::get($data, 'gateway_key')),
                (bool) Arr::get($data, 'manual_payment_request_id')
            ),
            Arr::get($data, 'payable_type')
        );

        if ($channel === 'wallet') {
            return self::WALLET_LABEL;
        }

        if ($channel === 'manual_banks') {
            $candidates = array_merge(
                $this->manualBankCandidatesFromContext($data),
                $this->manualBankCandidatesFromIdentifiers($data)
            );

            $label = $this->firstLabel($candidates);

            return $label ?? '';
        }

        $gatewayKey = Arr::get($data, 'gateway_key');
        if (! is_string($gatewayKey) || trim($gatewayKey) === '') {
            $gatewayKey = $this->normalizeGateway(
                Arr::get($data, 'payment_gateway'),
                (bool) Arr::get($data, 'manual_payment_request_id')
            );
        }

        if (! is_string($gatewayKey) || trim($gatewayKey) === '') {
            $gatewayKey = Arr::get($data, 'gateway_name');
        }

        return is_string($gatewayKey) ? trim($gatewayKey) : '';
    }

    private function labelForManualPaymentRequest(ManualPaymentRequest $manualPaymentRequest): string
    {
        $context = [
            'manual_payment_request' => $manualPaymentRequest,
            'manual_bank_id' => $manualPaymentRequest->manual_bank_id,
            'manual_bank_name' => $manualPaymentRequest->bank_name,
        ];

        $candidates = array_merge(
            $this->manualBankCandidatesFromContext($context),
            $this->manualBankCandidatesFromManualPaymentRequest($manualPaymentRequest)
        );

        $label = $this->firstLabel($candidates);

        return $label ?? '';
    }

    private function labelForWalletTransaction(WalletTransaction $walletTransaction): string
    {
        return self::WALLET_LABEL;
    }

    private function manualBankCandidatesFromTransaction(PaymentTransaction $transaction, array $context = []): array
    {
        $candidates = [];

        $candidates = array_merge($candidates, $this->candidatesFromMeta($transaction->meta));

        if ($transaction->relationLoaded('manualPaymentRequest')) {
            $manualPaymentRequest = $transaction->manualPaymentRequest;
        } else {
            $manualPaymentRequest = Arr::get($context, 'manual_payment_request');
        }

        if (! $manualPaymentRequest instanceof ManualPaymentRequest && $transaction->manual_payment_request_id) {
            $manualPaymentRequest = $this->manualPaymentRequestById((int) $transaction->manual_payment_request_id);
        }

        if ($manualPaymentRequest instanceof ManualPaymentRequest) {
            $candidates = array_merge(
                $candidates,
                $this->manualBankCandidatesFromManualPaymentRequest($manualPaymentRequest)
            );
        }

        if (! $transaction->relationLoaded('walletTransaction')) {
            $walletTransaction = Arr::get($context, 'wallet_transaction');
        } else {
            $walletTransaction = $transaction->walletTransaction;
        }

        if (! $walletTransaction instanceof WalletTransaction && $transaction->payableIsWalletTransaction()) {
            $walletTransaction = $this->walletTransactionById((int) $transaction->payable_id);
        }

        if ($walletTransaction instanceof WalletTransaction) {
            $candidates = array_merge(
                $candidates,
                $this->manualBankCandidatesFromWalletTransaction($walletTransaction)
            );
        }

        $manualBankId = Arr::get($context, 'manual_bank_id');
        if (! $manualBankId && $manualPaymentRequest instanceof ManualPaymentRequest) {
            $manualBankId = $manualPaymentRequest->manual_bank_id;
        }

        $candidates = array_merge($candidates, $this->manualBankNamesById($manualBankId));

        return $candidates;
    }

    private function manualBankCandidatesFromManualPaymentRequest(ManualPaymentRequest $manualPaymentRequest): array
    {
        $candidates = [];

        if ($manualPaymentRequest->relationLoaded('manualBank')) {
            $manualBank = $manualPaymentRequest->manualBank;
        } else {
            $manualBank = null;
        }

        if ($manualBank instanceof ManualBank) {
            $candidates[] = $manualBank->name;
            $candidates[] = $manualBank->beneficiary_name;
        }

        $candidates[] = $manualPaymentRequest->bank_name;

        $candidates = array_merge($candidates, $this->candidatesFromMeta($manualPaymentRequest->meta));

        $candidates = array_merge($candidates, $this->manualBankNamesById($manualPaymentRequest->manual_bank_id));

        return $candidates;
    }

    private function manualBankCandidatesFromWalletTransaction(WalletTransaction $walletTransaction): array
    {
        $candidates = [];

        $candidates = array_merge($candidates, $this->candidatesFromMeta($walletTransaction->meta));

        if ($walletTransaction->manual_payment_request_id) {
            $manualPaymentRequest = $this->manualPaymentRequestById((int) $walletTransaction->manual_payment_request_id);
            if ($manualPaymentRequest instanceof ManualPaymentRequest) {
                $candidates = array_merge(
                    $candidates,
                    $this->manualBankCandidatesFromManualPaymentRequest($manualPaymentRequest)
                );
            }
        }

        return $candidates;
    }

    private function manualBankCandidatesFromContext(array $context): array
    {
        $candidates = [];

        foreach (['manual_bank_name', 'bank_label', 'channel_label'] as $key) {
            $value = Arr::get($context, $key);
            if (is_string($value)) {
                $candidates[] = $value;
            }
        }

        $manualBankId = Arr::get($context, 'manual_bank_id');
        $candidates = array_merge($candidates, $this->manualBankNamesById($manualBankId));

        if ($contextManualRequest = Arr::get($context, 'manual_payment_request')) {
            if ($contextManualRequest instanceof ManualPaymentRequest) {
                $candidates = array_merge(
                    $candidates,
                    $this->manualBankCandidatesFromManualPaymentRequest($contextManualRequest)
                );
            } elseif ($contextManualRequest instanceof Arrayable) {
                $candidates[] = Arr::get($contextManualRequest->toArray(), 'bank_name');
            } elseif (is_array($contextManualRequest)) {
                $candidates[] = Arr::get($contextManualRequest, 'bank_name');
            }
        }

        return $candidates;
    }

    private function manualBankCandidatesFromIdentifiers(array $data): array
    {
        $candidates = [];

        $manualRequestId = Arr::get($data, 'manual_payment_request_id');
        if ($manualRequestId) {
            $manualPaymentRequest = $this->manualPaymentRequestById((int) $manualRequestId);
            if ($manualPaymentRequest instanceof ManualPaymentRequest) {
                $candidates = array_merge(
                    $candidates,
                    $this->manualBankCandidatesFromManualPaymentRequest($manualPaymentRequest)
                );
            }
        }

        $paymentTransactionId = Arr::get($data, 'payment_transaction_id');
        if ($paymentTransactionId) {
            $transaction = $this->paymentTransactionById((int) $paymentTransactionId);
            if ($transaction instanceof PaymentTransaction) {
                $candidates = array_merge(
                    $candidates,
                    $this->manualBankCandidatesFromTransaction($transaction, $data)
                );
            }
        }

        $walletTransactionId = Arr::get($data, 'wallet_transaction_id');
        if ($walletTransactionId) {
            $walletTransaction = $this->walletTransactionById((int) $walletTransactionId);
            if ($walletTransaction instanceof WalletTransaction) {
                $candidates = array_merge(
                    $candidates,
                    $this->manualBankCandidatesFromWalletTransaction($walletTransaction)
                );
            }
        }

        return $candidates;
    }

    private function candidatesFromMeta($meta): array
    {
        if ($meta instanceof Collection) {
            $meta = $meta->toArray();
        }

        if (! is_array($meta)) {
            return [];
        }

        $candidates = [];

        foreach (self::BANK_LABEL_JSON_PATHS as $jsonPath) {
            $dotPath = $this->jsonPathToDotPath($jsonPath);
            $value = data_get($meta, $dotPath);
            if (is_string($value)) {
                $candidates[] = $value;
            }
        }

        return $candidates;
    }

    private function manualBankNamesById($manualBankId): array
    {
        if (! $manualBankId) {
            return [];
        }

        $manualBankId = (int) $manualBankId;

        if (isset($this->manualBankLookupCache[$manualBankId])) {
            return $this->manualBankLookupCache[$manualBankId];
        }

        $names = Cache::remember(
            'manual_bank_name:' . $manualBankId,
            300,
            static function () use ($manualBankId) {
                $manualBank = ManualBank::query()->find($manualBankId, ['name', 'beneficiary_name']);

                if (! $manualBank instanceof ManualBank) {
                    return [];
                }

                return array_filter([
                    $manualBank->name,
                    $manualBank->beneficiary_name,
                ], static fn ($value) => is_string($value) && trim($value) !== '');
            }
        );

        $this->manualBankLookupCache[$manualBankId] = is_array($names) ? $names : [];

        return $this->manualBankLookupCache[$manualBankId];
    }

    private function jsonPathToDotPath(string $jsonPath): string
    {
        return preg_replace('/^\$\.?/', '', $jsonPath) ?? '';
    }

    private function convertRowToArray(object|array $row): array
    {
        if (is_array($row)) {
            return $row;
        }

        if ($row instanceof Arrayable) {
            return $row->toArray();
        }

        if ($row instanceof Model) {
            return $row->getAttributes();
        }

        return (array) $row;
    }

    private function firstLabel(array $candidates): ?string
    {
        foreach ($candidates as $candidate) {
            $sanitized = $this->sanitizeManualBankValue($candidate);
            if ($sanitized !== null) {
                return $sanitized;
            }
        }

        return null;
    }

    private function sanitizeManualBankValue($value): ?string
    {
        if (! is_string($value)) {
            return null;
        }

        $trimmed = trim($value);

        if ($trimmed === '') {
            return null;
        }

        $normalized = Str::lower($trimmed);

        static $aliases;
        if ($aliases === null) {
            $aliases = ManualPaymentRequest::manualBankGatewayAliases();
        }

        if (in_array($normalized, $aliases, true)) {
            return null;
        }

        return $trimmed;
    }

    private function resolveChannel(?string $channel, ?string $normalizedGateway, ?string $payableType): string
    {
        if (is_string($channel) && trim($channel) !== '') {
            return $this->normalizeChannel($channel);
        }

        return $this->channelFromGateway($normalizedGateway, $payableType);
    }

    private function normalizeChannel(string $channel): string
    {
        $normalized = Str::lower(trim($channel));

        switch ($normalized) {
            case 'wallet':
                return 'wallet';
            case 'east_yemen_bank':
            case 'east-yemen-bank':
                return 'east_yemen_bank';
            case 'cash':
                return 'cash';
            default:
                return 'manual_banks';
        }
    }

    private function channelFromGateway(?string $normalizedGateway, ?string $payableType): string
    {
        if (is_string($normalizedGateway)) {
            $normalizedGateway = Str::lower(trim($normalizedGateway));
        }

        if ($normalizedGateway !== null) {
            if (in_array($normalizedGateway, self::EAST_YEMEN_ALIASES, true)) {
                return 'east_yemen_bank';
            }

            static $manualAliases;
            if ($manualAliases === null) {
                $manualAliases = ManualPaymentRequest::manualBankGatewayAliases();
            }

            if (in_array($normalizedGateway, $manualAliases, true)) {
                return 'manual_banks';
            }

            if (in_array($normalizedGateway, self::WALLET_ALIASES, true)) {
                return 'wallet';
            }

            if (in_array($normalizedGateway, self::CASH_ALIASES, true)) {
                return 'cash';
            }
        }

        if (is_string($payableType) && Str::contains(Str::lower($payableType), 'wallet')) {
            return 'wallet';
        }

        return 'manual_banks';
    }

    private function normalizeGateway($gateway, bool $hasManualRequest): ?string
    {
        if (! is_string($gateway)) {
            return $hasManualRequest ? 'manual_bank' : null;
        }

        $trimmed = trim($gateway);

        if ($trimmed === '') {
            return $hasManualRequest ? 'manual_bank' : null;
        }

        return Str::lower($trimmed);
    }

    private function manualPaymentRequestById(int $id): ?ManualPaymentRequest
    {
        if (isset($this->manualPaymentRequestCache[$id])) {
            return $this->manualPaymentRequestCache[$id];
        }

        $manualPaymentRequest = ManualPaymentRequest::query()
            ->with('manualBank:id,name,beneficiary_name')
            ->find($id);

        $this->manualPaymentRequestCache[$id] = $manualPaymentRequest instanceof ManualPaymentRequest
            ? $manualPaymentRequest
            : null;

        return $this->manualPaymentRequestCache[$id];
    }

    private function paymentTransactionById(int $id): ?PaymentTransaction
    {
        if (isset($this->paymentTransactionCache[$id])) {
            return $this->paymentTransactionCache[$id];
        }

        $transaction = PaymentTransaction::query()
            ->with(['manualPaymentRequest.manualBank:id,name,beneficiary_name', 'walletTransaction'])
            ->find($id);

        $this->paymentTransactionCache[$id] = $transaction instanceof PaymentTransaction
            ? $transaction
            : null;

        return $this->paymentTransactionCache[$id];
    }

    private function walletTransactionById(int $id): ?WalletTransaction
    {
        if (isset($this->walletTransactionCache[$id])) {
            return $this->walletTransactionCache[$id];
        }

        $walletTransaction = WalletTransaction::query()->find($id);

        $this->walletTransactionCache[$id] = $walletTransaction instanceof WalletTransaction
            ? $walletTransaction
            : null;

        return $this->walletTransactionCache[$id];
    }


}
