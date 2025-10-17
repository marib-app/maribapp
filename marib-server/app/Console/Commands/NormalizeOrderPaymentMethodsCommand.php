<?php

namespace App\Console\Commands;

use App\Models\Order;
use App\Services\OrderCheckoutService;
use Illuminate\Console\Command;

class NormalizeOrderPaymentMethodsCommand extends Command
{
    protected $signature = 'orders:normalize-payment-methods {--dry-run : Only report the changes without saving them} {--chunk=100 : Number of orders to process per chunk}';

    protected $description = 'Normalize legacy payment gateway identifiers on existing orders.';

    public function handle(): int
    {
        $dryRun = (bool) $this->option('dry-run');
        $chunkSize = (int) $this->option('chunk');

        if ($chunkSize <= 0) {
            $this->error('Chunk size must be a positive integer.');

            return self::FAILURE;
        }

        $updatedCount = 0;
        $scannedCount = 0;

        Order::query()
            ->select(['id', 'payment_method', 'payment_payload'])
            ->orderBy('id')
            ->chunkById($chunkSize, function ($orders) use (&$updatedCount, &$scannedCount, $dryRun) {
                foreach ($orders as $order) {
                    ++$scannedCount;

                    $originalMethod = $order->payment_method;
                    $normalizedMethod = OrderCheckoutService::normalizePaymentMethod($originalMethod);

                    $payload = $order->payment_payload ?? [];

                    if (! is_array($payload)) {
                        $payload = [];
                    }

                    $requestedMethod = $payload['requested_method'] ?? null;
                    $normalizedRequested = OrderCheckoutService::normalizePaymentMethod($requestedMethod);

                    $dirty = false;

                    if ($normalizedMethod !== $originalMethod) {
                        $order->payment_method = $normalizedMethod;
                        $dirty = true;
                    }

                    if ($normalizedRequested !== $requestedMethod) {
                        if ($normalizedRequested === null) {
                            unset($payload['requested_method']);
                        } else {
                            $payload['requested_method'] = $normalizedRequested;
                        }

                        $order->payment_payload = $payload;
                        $dirty = true;
                    }

                    if (! $dirty) {
                        continue;
                    }

                    if ($dryRun) {
                        $this->line(sprintf(
                            'Order #%d would be updated: method "%s" -> "%s"%s',
                            $order->getKey(),
                            (string) $originalMethod,
                            (string) $normalizedMethod,
                            $requestedMethod !== $normalizedRequested
                                ? sprintf(', payload "%s" -> "%s"', (string) $requestedMethod, (string) $normalizedRequested)
                                : ''
                        ));

                        continue;
                    }

                    $order->save();
                    ++$updatedCount;
                }
            });

        if ($dryRun) {
            $this->info(sprintf('Scanned %d orders. %d would be updated.', $scannedCount, $updatedCount));
        } else {
            $this->info(sprintf('Scanned %d orders. Updated %d orders.', $scannedCount, $updatedCount));
        }

        return self::SUCCESS;
    }
}
