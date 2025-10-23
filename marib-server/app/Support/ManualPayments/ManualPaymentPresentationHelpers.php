<?php

namespace App\Support\ManualPayments;

use App\Models\ManualBank;
use App\Models\ManualPaymentRequest;
use Carbon\Carbon;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;
use Throwable;

trait ManualPaymentPresentationHelpers
{
    protected array $manualPaymentColumnSupportCache = [];

    protected array $manualPaymentRequestLookupCache = [];
    protected array $manualPaymentRequestByTransactionLookupCache = [];

    protected array $manualBankLookupCache = [];

    protected ?bool $manualBankTableSupported = null;

    protected function parseDateOrNull($value): ?Carbon
    {
        if (empty($value)) {
            return null;
        }

        try {
            return Carbon::parse($value);
        } catch (Throwable) {
            return null;
        }
    }

    protected function manualPaymentStatusIcon(?string $status): string
    {
        return match ($this->normalizeManualPaymentStatus($status)) {
            ManualPaymentRequest::STATUS_APPROVED => 'fa-solid fa-circle-check',
            ManualPaymentRequest::STATUS_REJECTED => 'fa-solid fa-circle-xmark',
            ManualPaymentRequest::STATUS_UNDER_REVIEW => 'fa-solid fa-magnifying-glass',
            default => 'fa-solid fa-hourglass-half',
        };
    }

    protected function manualPaymentStatusBadge(?string $status): string
    {
        return match ($this->normalizeManualPaymentStatus($status)) {
            ManualPaymentRequest::STATUS_APPROVED => 'bg-success',
            ManualPaymentRequest::STATUS_REJECTED => 'bg-danger',
            ManualPaymentRequest::STATUS_UNDER_REVIEW => 'bg-info text-dark',
            default => 'bg-warning text-dark',
        };
    }

    protected function manualPaymentStatusIconMap(): array
    {
        return [
            ManualPaymentRequest::STATUS_PENDING => 'fa-solid fa-clock text-warning',
            ManualPaymentRequest::STATUS_UNDER_REVIEW => 'fa-solid fa-magnifying-glass text-primary',
            ManualPaymentRequest::STATUS_APPROVED => 'fa-solid fa-circle-check text-success',
            ManualPaymentRequest::STATUS_REJECTED => 'fa-solid fa-circle-xmark text-danger',
            'submitted' => 'fa-solid fa-file-circle-plus text-primary',
            'default' => 'fa-solid fa-circle text-secondary',
        ];
    }

    protected function manualPaymentStatusLabel(?string $status): string
    {
        return match ($this->normalizeManualPaymentStatus($status)) {
            ManualPaymentRequest::STATUS_APPROVED => trans('Approved'),
            ManualPaymentRequest::STATUS_REJECTED => trans('Rejected'),
            ManualPaymentRequest::STATUS_UNDER_REVIEW => trans('Under Review'),
            default => trans('Pending'),
        };
    }

    protected function normalizeManualPaymentStatus($status): ?string
    {
        if (! is_string($status)) {
            return null;
        }

        $normalized = strtolower(trim($status));

        if ($normalized === '' || $normalized === 'null') {
            return null;
        }

        $canonical = ManualPaymentRequest::normalizeStatus($normalized);

        if ($canonical !== null) {
            return $canonical;
        }

        return in_array($normalized, [
            ManualPaymentRequest::STATUS_PENDING,
            ManualPaymentRequest::STATUS_APPROVED,
            ManualPaymentRequest::STATUS_REJECTED,
            ManualPaymentRequest::STATUS_UNDER_REVIEW,
        ], true) ? $normalized : null;
    }

    protected function paymentRequestChannelLabel(?string $channel, ?string $manualBankName = null): string
    {
        $manualBankName = is_string($manualBankName) ? trim($manualBankName) : null;

        if ($manualBankName !== null && $manualBankName !== '') {
            $aliases = ManualPaymentRequest::manualBankGatewayAliases();

            if (! in_array(strtolower($manualBankName), $aliases, true)) {
                return $manualBankName;
            }
        }

        $normalized = $this->normalizePaymentRequestChannel($channel);

        if ($normalized !== null) {
            return match ($normalized) {
                'east_yemen_bank' => trans('East Yemen Bank'),
                'manual_banks' => $manualBankName ?? ManualBank::defaultDisplayName(),
                'wallet' => trans('Wallet'),
                'cash' => trans('Cash'),
                default => $manualBankName ?? ManualBank::defaultDisplayName(),
            };
        }

        if (is_string($channel) && $channel !== '') {
            return Str::of($channel)
                ->replace(['_', '-'], ' ')
                ->trim()
                ->title()
                ->value();
        }

        return $manualBankName ?? ManualBank::defaultDisplayName();
    }

    protected function paymentRequestDepartmentLabel(?string $department): string
    {
        if (! is_string($department) || $department === '') {
            return trans('Unknown Department');
        }

        return match ($department) {
            \App\Services\DepartmentReportService::DEPARTMENT_SHEIN => trans('departments.shein'),
            \App\Services\DepartmentReportService::DEPARTMENT_COMPUTER => trans('departments.computer'),
            \App\Services\DepartmentReportService::DEPARTMENT_STORE => trans('departments.store'),
            default => $department,
        };
    }


    protected function resolveManualPaymentGatewayKey(ManualPaymentRequest $manualPaymentRequest): string
    {
        $gateway = $manualPaymentRequest->paymentTransaction?->payment_gateway;
        $normalized = ManualPaymentRequest::canonicalGateway($gateway);

        if ($normalized !== null) {
            return $normalized === 'manual_bank' ? 'manual_banks' : $normalized;
        }

        $metaGateway = ManualPaymentRequest::canonicalGateway(data_get($manualPaymentRequest->meta, 'gateway'));

        if ($metaGateway !== null) {
            return $metaGateway === 'manual_bank' ? 'manual_banks' : $metaGateway;
        }

        if (
            $manualPaymentRequest->isWalletTopUp()
            || data_get($manualPaymentRequest->meta, 'wallet.transaction_id')
        ) {
            return 'wallet';
        }

        return 'manual_banks';
    }



    protected function normalizePaymentRequestChannel($channel): ?string
    {
        if (! is_string($channel)) {
            return null;
        }

        $normalized = strtolower(trim($channel));

        if ($normalized === '' || $normalized === 'null') {
            return null;
        }

        $canonical = ManualPaymentRequest::canonicalGateway($normalized);

        if ($canonical === null) {
            return null;
        }

        return match ($canonical) {
            'manual_bank' => 'manual_banks',
            'east_yemen_bank', 'manual_banks', 'wallet', 'cash' => $canonical,
            default => in_array($canonical, ['manual_banks', 'east_yemen_bank', 'wallet', 'cash'], true)
                ? $canonical
                : null,
        };
    }

    protected function resolveManualBankName(mixed $row): ?string
    {
        $genericGatewayAliases = $this->resolveGenericGatewayAliases();



        $candidates = [
            data_get($row, 'manual_bank_name'),
            data_get($row, 'bank_name'),
            data_get($row, 'bank_account_name'),

            data_get($row, 'meta.manual.bank.name'),
            data_get($row, 'meta.manual.bank.bank_name'),

            data_get($row, 'meta.manual_bank.name'),
            data_get($row, 'meta.manual_bank.bank_name'),
            data_get($row, 'meta.bank.name'),
            data_get($row, 'meta.bank.bank_name'),
            data_get($row, 'meta.payload.bank_name'),
            data_get($row, 'meta.payload.bank.name'),
            data_get($row, 'manualBank.name'),
        ];

        foreach ($candidates as $candidate) {
            if (! is_string($candidate)) {
                continue;
            }

            $trimmed = trim($candidate);

            if ($trimmed === '') {
                continue;
            }

            if (in_array(Str::lower($trimmed), $genericGatewayAliases, true)) {

                continue;
            }

            return $trimmed;
        }

        $manualBankId = null;

        if ($this->manualPaymentRequestsSupportsColumn('manual_bank_id')) {
            $manualBankId = data_get($row, 'manual_bank_id');

            if ($manualBankId === null) {
                $manualBankId = data_get($row, 'manualBank.id');
            }

            if ($manualBankId === null) {
                $manualBankId = data_get($row, 'meta.payload.manual_bank_id');
            }

        }

        if (is_string($manualBankId)) {
            $manualBankId = trim($manualBankId);
        }

        if ($manualBankId !== null && $manualBankId !== '') {
            $manualBankId = (int) $manualBankId;
        } else {
            $manualBankId = null;
        }

        if ($manualBankId !== null) {
            $manualBank = $this->findManualBankById($manualBankId);

            if ($manualBank !== null) {
                $lookupCandidates = [
                    data_get($manualBank, 'name'),
                ];

                foreach ($lookupCandidates as $lookupCandidate) {
                    if (! is_string($lookupCandidate)) {
                        continue;
                    }

                    $trimmedLookupCandidate = trim($lookupCandidate);

                    if ($trimmedLookupCandidate === '') {
                        continue;
                    }

                    if (in_array(Str::lower($trimmedLookupCandidate), $genericGatewayAliases, true)) {
                        continue;
                    }

                    return $trimmedLookupCandidate;
                }
            }
        }

        $manualPaymentRequestId = data_get($row, 'manual_payment_request_id');

        if (is_string($manualPaymentRequestId)) {
            $manualPaymentRequestId = trim($manualPaymentRequestId);
        }

        if ($manualPaymentRequestId !== null && $manualPaymentRequestId !== '') {
            $manualPaymentRequestId = (int) $manualPaymentRequestId;
        } else {
            $manualPaymentRequestId = null;
        }

        if ($manualPaymentRequestId !== null) {
            $manualPaymentRequest = $this->getManualPaymentRequestById($manualPaymentRequestId);

            if ($manualPaymentRequest instanceof ManualPaymentRequest) {
                $lookupCandidates = [
                    data_get($manualPaymentRequest, 'manualBank.name'),
                ];

                foreach ($lookupCandidates as $lookupCandidate) {
                    if (! is_string($lookupCandidate)) {
                        continue;
                    }

                    $trimmedLookupCandidate = trim($lookupCandidate);

                    if ($trimmedLookupCandidate === '') {
                        continue;
                    }

                    if (in_array(Str::lower($trimmedLookupCandidate), $genericGatewayAliases, true)) {
                        continue;
                    }

                    return $trimmedLookupCandidate;
                }
            }
        }

        return null;
    }

    protected function manualPaymentRequestsSupportsColumn(string $column): bool
    {
        if (! array_key_exists($column, $this->manualPaymentColumnSupportCache)) {
            $this->manualPaymentColumnSupportCache[$column] = Schema::hasTable('manual_payment_requests')
                && Schema::hasColumn('manual_payment_requests', $column);
        }

        return $this->manualPaymentColumnSupportCache[$column];
    }

    protected function manualBankLookupSupported(): bool
    {
        if ($this->manualBankTableSupported === null) {
            $this->manualBankTableSupported = Schema::hasTable('manual_banks');
        }

        return $this->manualBankTableSupported;
    }

    protected function findManualBankById(int $manualBankId): ?ManualBank
    {
        if ($manualBankId <= 0) {
            return null;
        }

        if (! $this->manualBankLookupSupported()) {
            return null;
        }

        if (! array_key_exists($manualBankId, $this->manualBankLookupCache)) {
            $this->manualBankLookupCache[$manualBankId] = ManualBank::query()->find($manualBankId);
        }

        $manualBank = $this->manualBankLookupCache[$manualBankId] ?? null;

        return $manualBank instanceof ManualBank ? $manualBank : null;
    }

    protected function getManualPaymentRequestById(int $manualPaymentRequestId): ?ManualPaymentRequest
    {
        if ($manualPaymentRequestId <= 0) {
            return null;
        }

        if (! array_key_exists($manualPaymentRequestId, $this->manualPaymentRequestLookupCache)) {
            $this->manualPaymentRequestLookupCache[$manualPaymentRequestId] = ManualPaymentRequest::query()
                ->with('manualBank')
                ->find($manualPaymentRequestId);
        }

        $manualPaymentRequest = $this->manualPaymentRequestLookupCache[$manualPaymentRequestId] ?? null;

        return $manualPaymentRequest instanceof ManualPaymentRequest ? $manualPaymentRequest : null;
    }


    protected function getManualPaymentRequestByPaymentTransactionId(int $paymentTransactionId): ?ManualPaymentRequest
    {
        if ($paymentTransactionId <= 0) {
            return null;
        }

        if (! array_key_exists($paymentTransactionId, $this->manualPaymentRequestByTransactionLookupCache)) {
            $this->manualPaymentRequestByTransactionLookupCache[$paymentTransactionId] = ManualPaymentRequest::query()
                ->with('manualBank')
                ->where('payment_transaction_id', $paymentTransactionId)
                ->first();
        }

        $manualPaymentRequest = $this->manualPaymentRequestByTransactionLookupCache[$paymentTransactionId] ?? null;

        return $manualPaymentRequest instanceof ManualPaymentRequest ? $manualPaymentRequest : null;
    }



    protected function prefetchManualPaymentRequestsForRows(Collection $rows): void
    {
        if ($rows->isEmpty()) {
            return;
        }

        $manualBankAliases = array_map('strtolower', ManualPaymentRequest::manualBankGatewayAliases());
        $manualBankAliases = array_merge(
            $manualBankAliases,
            array_map('strtolower', $this->resolveLocalizedGatewayFallbacks())
        );

        

        $manualBankAliases = array_values(array_unique(array_filter(array_map(
            static function ($alias) {
                if (! is_string($alias)) {
                    return null;
                }

                $value = trim($alias);

                return $value === '' ? null : $value;
            },
            $manualBankAliases
        ))));

        if ($manualBankAliases === []) {
            $manualBankAliases = ['manual_banks', 'manual_bank'];
        }


        $candidateIds = $rows
            ->map(static function (object $row) use ($manualBankAliases) {
                $manualBankName = data_get($row, 'manual_bank_name');

                if (is_string($manualBankName)) {
                    $manualBankName = trim($manualBankName);

                    if (
                        $manualBankName !== ''
                        && ! in_array(strtolower($manualBankName), $manualBankAliases, true)
                    ) {
                        return null;
                    }
                }

                $manualBankId = data_get($row, 'manual_bank_id');

                if (is_string($manualBankId)) {
                    $manualBankId = trim($manualBankId);
                }

                if ($manualBankId !== null && $manualBankId !== '' && (int) $manualBankId > 0) {
                    return null;
                }

                $manualPaymentRequestId = data_get($row, 'manual_payment_request_id');

                if (is_string($manualPaymentRequestId)) {
                    $manualPaymentRequestId = trim($manualPaymentRequestId);
                }

                if ($manualPaymentRequestId === null || $manualPaymentRequestId === '') {
                    return null;
                }

                $manualPaymentRequestId = (int) $manualPaymentRequestId;

                return $manualPaymentRequestId > 0 ? $manualPaymentRequestId : null;
            })
            ->filter()
            ->unique()
            ->values();

        if ($candidateIds->isEmpty()) {
            return;
        }

        $missingIds = array_values(array_diff($candidateIds->all(), array_keys($this->manualPaymentRequestLookupCache)));

        if ($missingIds === []) {
            return;
        }

        $manualPaymentRequests = ManualPaymentRequest::query()
            ->with('manualBank')
            ->whereIn('id', $missingIds)
            ->get()
            ->keyBy('id');

        foreach ($missingIds as $manualPaymentRequestId) {
            $this->manualPaymentRequestLookupCache[$manualPaymentRequestId] = $manualPaymentRequests->get($manualPaymentRequestId);
        }
    }


    /**
     * @return array<int, string>
     */
    protected function resolveGenericGatewayAliases(): array
    {
        $aliasCandidates = array_merge(
            (array) ManualPaymentRequest::manualBankGatewayAliases(),
            (array) ManualPaymentRequest::walletGatewayAliases(),
            $this->resolveLocalizedGatewayFallbacks()
        );
        return $this->normalizeGatewayAliases($aliasCandidates);
    }

    /**
     * @param array<int, mixed> $aliases
     * @return array<int, string>
     */
    protected function normalizeGatewayAliases(array $aliases): array
    {
        $normalized = array_values(array_filter(array_map(static function ($alias) {
            if (! is_string($alias)) {
                return null;
            }

            $value = Str::lower(trim($alias));

            return $value === '' ? null : $value;
        }, $aliases)));

        if ($normalized === []) {
            return ['manual_banks', 'manual_bank', 'wallet'];
        }

        return array_values(array_unique($normalized));
    }

    /**
     * @return array<int, string>
     */
    protected function resolveLocalizedGatewayFallbacks(): array
    {
        return [
            trans('Bank Transfer'),
            trans('Wallet'),
            'manual_banks',
            'manual_bank',
            'wallet',
            'التحويل البنكي',
            'تحويل بنكي',
            'المحفظة',
        ];
    }

}
