<?php

namespace App\Console\Commands;

use App\Models\ManualPaymentRequest;
use App\Services\Payments\ManualPaymentRequestService;
use App\Support\ManualPayments\TransferDetailsResolver;
use Illuminate\Console\Command;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Arr;
use Illuminate\Support\Carbon;

class SyncManualTransferDetailsCommand extends Command
{
    protected $signature = 'payments:sync-manual-transfer-details '
        . '{--days=30 : Only sync requests created within the last N days (use 0 for all)} '
        . '{--chunk=100 : Number of requests to process per chunk} '
        . '{--dry-run : Show how many requests require syncing without persisting changes}';

    protected $description = 'Ensure manual payment requests store normalized transfer details in metadata and columns.';

    public function __construct(private readonly ManualPaymentRequestService $manualPaymentRequestService)
    {
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

        $query = ManualPaymentRequest::query()->orderBy('id');

        if ($days > 0) {
            $cutoff = Carbon::now()->subDays($days);
            $query->where(function (Builder $builder) use ($cutoff): void {
                $builder->whereNull('created_at')
                    ->orWhere('created_at', '>=', $cutoff);
            });
        }

        $total = (clone $query)->count();

        if ($total === 0) {
            $this->info('No manual payment requests found for synchronization.');

            return self::SUCCESS;
        }

        $this->info(sprintf('Found %d manual payment request(s) to inspect.', $total));

        if ($dryRun) {
            $this->line('Dry run enabled — no changes will be persisted.');
        }

        $processed = 0;
        $updated = 0;

        $query->with(['manualBank', 'paymentTransaction.walletTransaction'])
            ->chunkById($chunkSize, function ($requests) use (&$processed, &$updated, $dryRun): void {
                foreach ($requests as $manualRequest) {
                    ++$processed;

                    if (! $manualRequest instanceof ManualPaymentRequest) {
                        continue;
                    }

                    $transferDetails = TransferDetailsResolver::forManualPaymentRequest($manualRequest)->toArray();

                    if (! $this->requiresSync($manualRequest, $transferDetails)) {
                        continue;
                    }

                    if ($dryRun) {
                        ++$updated;
                        $this->line(sprintf('Would sync transfer details for manual payment request #%d.', $manualRequest->getKey()));
                        continue;
                    }

                    $beforeState = $this->captureState($manualRequest);
                    $this->manualPaymentRequestService->syncTransferDetails($manualRequest);
                    $afterState = $this->captureState($manualRequest->fresh(['manualBank', 'paymentTransaction.walletTransaction']));

                    if ($beforeState !== $afterState) {
                        ++$updated;
                        $this->line(sprintf('Synced transfer details for manual payment request #%d.', $manualRequest->getKey()));
                    }
                }
            });

        if ($dryRun) {
            $this->info(sprintf('Dry run complete. %d request(s) require syncing.', $updated));

            return self::SUCCESS;
        }

        $this->info(sprintf('Synchronization complete. Processed %d request(s), updated %d.', $processed, $updated));

        return self::SUCCESS;
    }

    /**
     * @param array<string, mixed> $transferDetails
     */
    private function requiresSync(ManualPaymentRequest $manualRequest, array $transferDetails): bool
    {
        $meta = $manualRequest->meta;
        if (! is_array($meta)) {
            $meta = [];
        }

        $storedTransfer = Arr::get($meta, 'transfer_details');
        if (! is_array($storedTransfer)) {
            $storedTransfer = [];
        }

        foreach (['sender_name', 'transfer_reference', 'note', 'receipt_url', 'receipt_path'] as $key) {
            $resolved = Arr::get($transferDetails, $key);

            if ($resolved === null || $resolved === '') {
                continue;
            }

            $current = null;

            if ($key === 'receipt_path') {
                $current = Arr::get($meta, 'receipt.path')
                    ?? Arr::get($meta, 'receipt_path')
                    ?? Arr::get($storedTransfer, $key);
            } elseif ($key === 'note') {
                $current = Arr::get($storedTransfer, $key)
                    ?? Arr::get($meta, 'manual.note');
            } else {
                $current = Arr::get($storedTransfer, $key)
                    ?? Arr::get($meta, 'manual.' . $key)
                    ?? Arr::get($meta, 'metadata.' . $key);
            }

            if (! is_string($current)) {
                $current = is_scalar($current) ? (string) $current : null;
            }

            if ($current === null || trim($current) === '') {
                return true;
            }

            if (trim($current) !== (string) $resolved) {
                return true;
            }
        }

        $reference = Arr::get($transferDetails, 'transfer_reference');
        if ($reference !== null && $reference !== '' && trim((string) ($manualRequest->reference ?? '')) !== (string) $reference) {
            return true;
        }

        $receiptPath = Arr::get($transferDetails, 'receipt_path');
        if ($receiptPath !== null && $receiptPath !== '' && trim((string) ($manualRequest->receipt_path ?? '')) !== (string) $receiptPath) {
            return true;
        }

        return false;
    }

    private function captureState(?ManualPaymentRequest $manualRequest): string
    {
        if (! $manualRequest instanceof ManualPaymentRequest) {
            return 'null';
        }

        $transaction = $manualRequest->paymentTransaction;
        $wallet = $transaction?->walletTransaction;

        $payload = [
            'reference' => $manualRequest->reference,
            'receipt_path' => $manualRequest->receipt_path,
            'meta' => $manualRequest->meta,
            'transaction_meta' => $transaction?->meta,
            'wallet_meta' => $wallet?->meta,
        ];

        $encoded = json_encode($payload);

        if ($encoded === false) {
            return serialize($payload);
        }

        return $encoded;
    }
}