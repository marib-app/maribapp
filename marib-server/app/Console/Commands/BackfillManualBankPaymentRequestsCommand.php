<?php

namespace App\Console\Commands;

use App\Models\ManualPaymentRequest;
use App\Models\PaymentTransaction;
use App\Services\Payments\ManualPaymentRequestService;
use Illuminate\Console\Command;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Carbon;
use App\Support\Payments\PaymentLabelService;

class BackfillManualBankPaymentRequestsCommand extends Command
{
    protected $signature = 'manual-payments:backfill '
        . '{--days=90 : Only backfill transactions created within the last N days (use 0 for all)} '
        . '{--chunk=100 : Number of records to process per chunk} '
        . '{--dry-run : Show the number of transactions that require backfilling without changing data}';

    protected $description = 'Backfill manual payment requests for manual bank transactions that are missing their request link.';

    public function handle(ManualPaymentRequestService $service): int
    {
        $days = (int) $this->option('days');
        $chunkSize = (int) $this->option('chunk');
        $dryRun = (bool) $this->option('dry-run');

        if ($chunkSize <= 0) {
            $chunkSize = 100;
        }

        $days = max(0, $days);
        $manualGatewayAliases = ManualPaymentRequest::manualBankGatewayAliases();
        $manualGatewayAliases[] = 'manual_bank';
        $manualGatewayAliases[] = 'manual_banks';
        $manualGatewayAliases = array_values(array_unique(array_filter(array_map(static function ($value) {
            if (! is_string($value)) {
                return null;
            }

            $normalized = strtolower(trim($value));

            return $normalized === '' ? null : $normalized;
        }, $manualGatewayAliases))));

        $cutoff = $days > 0 ? now()->subDays($days) : null;

        $query = PaymentTransaction::query()
            ->whereNull('manual_payment_request_id')
            ->where(function (Builder $builder) use ($manualGatewayAliases): void {
                foreach ($manualGatewayAliases as $index => $gateway) {
                    if ($index === 0) {
                        $builder->whereRaw('LOWER(payment_gateway) = ?', [$gateway]);

                        continue;
                    }

                    $builder->orWhereRaw('LOWER(payment_gateway) = ?', [$gateway]);
                }
            })
            ->orderBy('id');

        if ($cutoff instanceof Carbon) {
            $query->where('created_at', '>=', $cutoff);
        }

        $totalCandidates = (clone $query)->count();

        if ($totalCandidates === 0) {
            $this->info('No manual bank payment transactions require backfilling.');

            return self::SUCCESS;
        }

        $this->info(sprintf('Found %d manual bank transaction(s) requiring backfill.', $totalCandidates));

        if ($dryRun) {
            $this->line('Dry run enabled — no changes will be written.');
        }

        $processed = 0;
        $linked = 0;
        $updatedBankNames = 0;

        $query->chunkById($chunkSize, function ($transactions) use (&$processed, &$linked, &$updatedBankNames, $service, $dryRun): void {
            foreach ($transactions as $transaction) {
                ++$processed;

                if ($dryRun) {
                    $this->line(sprintf('Would backfill manual request for transaction #%d', $transaction->getKey()));

                    continue;
                }

                $originalId = $transaction->manual_payment_request_id;
                $manualRequest = $service->ensureManualPaymentRequestForTransaction($transaction);

                if ($manualRequest instanceof ManualPaymentRequest || $transaction->manual_payment_request_id !== $originalId) {
                    ++$linked;
                }


                $labels = PaymentLabelService::forPaymentTransaction($transaction->fresh('manualPaymentRequest.manualBank'));
                $bankName = $labels['bank_name'] ?? null;

                if (is_string($bankName) && trim($bankName) !== '') {
                    $meta = $transaction->meta ?? [];
                    $existing = data_get($meta, 'payload.bank_name');

                    if (! is_string($existing) || trim($existing) === '') {
                        data_set($meta, 'payload.bank_name', $bankName);
                        $transaction->forceFill(['meta' => $meta])->saveQuietly();
                        ++$updatedBankNames;
                    }
                }

            }
        }, 'id');

        if ($dryRun) {
            $this->info(sprintf('Dry run complete. %d transaction(s) identified.', $processed));

            return self::SUCCESS;
        }

        $this->info(sprintf('Backfill completed. %d transaction(s) processed, %d linked, %d bank name(s) updated.', $processed, $linked, $updatedBankNames));

        return self::SUCCESS;
    }
}