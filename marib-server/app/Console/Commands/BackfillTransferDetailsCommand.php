<?php

namespace App\Console\Commands;

use App\Models\ManualPaymentRequest;
use App\Models\PaymentTransaction;
use App\Services\Payments\CreateOrLinkManualPaymentRequest;
use App\Services\Payments\ManualPaymentRequestService;
use App\Support\ManualPayments\TransferDetailsResolver;
use Illuminate\Console\Command;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Arr;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class BackfillTransferDetailsCommand extends Command
{
    protected $signature = 'payments:backfill-transfer-details '
        . '{--days=90 : Only backfill transactions created within the last N days (use 0 for all)} '
        . '{--chunk=100 : Number of records to process per chunk} '
        . '{--dry-run : Show the number of transactions that require backfilling without changing data}';

    protected $description = 'Create manual payment requests and link transfer details for legacy manual bank transactions.';

    public function __construct(
        private readonly ManualPaymentRequestService $manualPaymentRequestService,
        private readonly CreateOrLinkManualPaymentRequest $manualPaymentLinker
    ) {
        parent::__construct();
    }

    public function handle(): int
    {
        $days = max(0, (int) $this->option('days'));
        $chunkSize = (int) $this->option('chunk');
        $dryRun = (bool) $this->option('dry-run');

        if ($chunkSize <= 0) {
            $chunkSize = 100;
        }

        $manualGatewayAliases = ManualPaymentRequest::manualBankGatewayAliases();
        $manualGatewayAliases[] = 'manual_bank';
        $manualGatewayAliases[] = 'manual_banks';
        $manualGatewayAliases = array_values(array_unique(array_filter(array_map(static function ($value) {
            if (! is_string($value)) {
                return null;
            }

            $normalized = Str::of($value)->lower()->trim()->value();

            return $normalized === '' ? null : $normalized;
        }, $manualGatewayAliases))));

        $cutoff = $days > 0 ? now()->subDays($days) : null;

        $query = PaymentTransaction::query()
            ->whereNull('manual_payment_request_id')
            ->where(function (Builder $builder) use ($manualGatewayAliases): void {
                foreach ($manualGatewayAliases as $index => $gateway) {
                    $column = DB::raw('LOWER(payment_gateway)');

                    if ($index === 0) {
                        $builder->where($column, '=', $gateway);
                        continue;
                    }

                    $builder->orWhere($column, '=', $gateway);
                }
            })
            ->orderBy('id');

        if ($cutoff instanceof Carbon) {
            $query->where('created_at', '>=', $cutoff);
        }

        $total = (clone $query)->count();

        if ($total === 0) {
            $this->info('No manual bank transactions require backfilling.');

            return self::SUCCESS;
        }

        $this->info(sprintf('Found %d manual bank transaction(s) requiring backfill.', $total));

        if ($dryRun) {
            $this->line('Dry run enabled — no changes will be written.');
        }

        $processed = 0;
        $linked = 0;

        $query->with(['user', 'manualPaymentRequest', 'walletTransaction', 'payable'])
            ->chunkById($chunkSize, function ($transactions) use (&$processed, &$linked, $dryRun): void {
                foreach ($transactions as $transaction) {
                    ++$processed;

                    if ($dryRun) {
                        $this->line(sprintf('Would backfill transfer details for transaction #%d', $transaction->getKey()));
                        continue;
                    }

                    $originalId = $transaction->manual_payment_request_id;

                    $manualRequest = $transaction->manualPaymentRequest;
                    if (! $manualRequest instanceof ManualPaymentRequest) {
                        $manualRequest = $this->manualPaymentRequestService->ensureManualPaymentRequestForTransaction($transaction);
                        $transaction->refresh();
                        $manualRequest = $transaction->manualPaymentRequest;
                    }

                    if (! $manualRequest instanceof ManualPaymentRequest) {
                        $this->warn(sprintf('Skipped transaction #%d — unable to determine manual payment request.', $transaction->getKey()));
                        continue;
                    }

                    $transaction->loadMissing(['user', 'payable']);
                    $user = $transaction->user ?? $manualRequest->user;

                    if (! $user instanceof \App\Models\User) {
                        $this->warn(sprintf('Skipped transaction #%d — no associated user found.', $transaction->getKey()));
                        continue;
                    }

                    $payableType = $manualRequest->payable_type ?? $transaction->payable_type;
                    $payableId = $manualRequest->payable_id ?? $transaction->payable_id;

                    if ($transaction->payableIsWalletTransaction()) {
                        $payableType = ManualPaymentRequest::PAYABLE_TYPE_WALLET_TOP_UP;
                        $payableId = $transaction->payable_id;
                    }

                    if (! is_int($payableId) && is_numeric($payableId)) {
                        $payableId = (int) $payableId;
                    }

                    if (! is_int($payableId)) {
                        $payableId = null;
                    }

                    $payload = $this->buildPayload($transaction, $manualRequest);

                    $this->manualPaymentLinker->handle(
                        $user,
                        $payableType ?? ManualPaymentRequest::PAYABLE_TYPE_WALLET_TOP_UP,
                        $payableId,
                        $transaction->fresh(),
                        $payload
                    );

                    if ($originalId === null && $transaction->manual_payment_request_id !== null) {
                        ++$linked;
                    }
                }
            }, 'id');

        if ($dryRun) {
            $this->info(sprintf('Dry run complete. %d transaction(s) identified.', $processed));

            return self::SUCCESS;
        }

        $this->info(sprintf('Backfill completed. %d transaction(s) processed, %d linked.', $processed, $linked));

        return self::SUCCESS;
    }

    /**
     * @return array<string, mixed>
     */
    private function buildPayload(PaymentTransaction $transaction, ManualPaymentRequest $manualRequest): array
    {
        $payload = [];
        $transactionMeta = is_array($transaction->meta) ? $transaction->meta : [];
        $manualMeta = is_array($manualRequest->meta) ? $manualRequest->meta : [];

        $manualBankId = $manualRequest->manual_bank_id
            ?? Arr::get($manualMeta, 'manual_bank.id')
            ?? Arr::get($manualMeta, 'bank.id')
            ?? Arr::get($transactionMeta, 'manual_bank.id')
            ?? Arr::get($transactionMeta, 'manual.manual_bank_id')
            ?? Arr::get($transactionMeta, 'payload.manual_bank_id');

        if (is_numeric($manualBankId)) {
            $manualBankId = (int) $manualBankId;
            if ($manualBankId > 0) {
                $payload['manual_bank_id'] = $manualBankId;
            }
        }

        $bankName = $manualRequest->bank_name
            ?? Arr::get($manualMeta, 'manual_bank.name')
            ?? Arr::get($manualMeta, 'bank.name')
            ?? Arr::get($transactionMeta, 'manual_bank.name')
            ?? Arr::get($transactionMeta, 'payload.bank_name');

        if (is_string($bankName) && trim($bankName) !== '') {
            $payload['bank_name'] = trim($bankName);
            data_set($payload, 'bank.name', trim($bankName));
        }

        $transferDetails = TransferDetailsResolver::forManualPaymentRequest($manualRequest)->toArray();

        if (! empty($transferDetails['sender_name'])) {
            $payload['sender_name'] = $transferDetails['sender_name'];
        }

        if (! empty($transferDetails['transfer_reference'])) {
            $payload['transfer_reference'] = $transferDetails['transfer_reference'];
        }

        if (! empty($transferDetails['note'])) {
            $payload['note'] = $transferDetails['note'];
        }

        $receiptPath = $manualRequest->receipt_path
            ?? Arr::get($manualMeta, 'receipt.path')
            ?? Arr::get($manualMeta, 'receipt_path')
            ?? Arr::get($transactionMeta, 'receipt.path')
            ?? Arr::get($transactionMeta, 'receipt_path')
            ?? $transaction->receipt_path;

        if (is_string($receiptPath) && trim($receiptPath) !== '') {
            $payload['receipt_path'] = trim($receiptPath);
        }

        $attachments = Arr::get($manualMeta, 'attachments');
        if (! is_array($attachments) || $attachments === []) {
            $attachments = Arr::get($transactionMeta, 'attachments');
        }

        if (is_array($attachments) && $attachments !== []) {
            $payload['attachments'] = $attachments;
        }

        $metadata = Arr::get($manualMeta, 'metadata');
        if (! is_array($metadata) || $metadata === []) {
            $metadata = Arr::get($transactionMeta, 'manual.metadata');
        }

        if (is_array($metadata) && $metadata !== []) {
            $payload['metadata'] = $metadata;
        }

        return $payload;
    }
}