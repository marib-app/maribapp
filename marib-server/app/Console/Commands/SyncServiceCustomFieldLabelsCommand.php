<?php

namespace App\Console\Commands;

use App\Http\Controllers\ServiceController;
use App\Models\Service;
use Illuminate\Console\Command;
use Illuminate\Database\Eloquent\Collection;
use Throwable;

class SyncServiceCustomFieldLabelsCommand extends Command
{
    protected $signature = 'services:resync-custom-fields
        {--chunk=100 : Number of services to process per chunk}
        {--service=* : Specific service IDs to resync}';

    protected $description = 'Resynchronize custom field labels/handles for services using the current schema definitions.';

    public function handle(ServiceController $serviceController): int
    {
        $chunkSize = (int) $this->option('chunk');
        if ($chunkSize <= 0) {
            $chunkSize = 100;
        }

        $serviceIds = array_filter(array_map(static function ($value) {
            if ($value === null || $value === '') {
                return null;
            }

            if (is_numeric($value)) {
                return (int) $value;
            }

            return null;
        }, (array) $this->option('service')));

        $servicesQuery = Service::query()
            ->whereNotNull('service_fields_schema');

        if (! empty($serviceIds)) {
            $servicesQuery->whereIn('id', $serviceIds);
        }

        $total = $servicesQuery->count();
        if ($total === 0) {
            $this->info('No services with custom field schemas were found.');

            return Command::SUCCESS;
        }
        $this->info(sprintf('Preparing to resynchronize %d service(s)...', $total));

        $processed = 0;
        $failures = 0;

        $servicesQuery->orderBy('id')->chunkById($chunkSize, function (Collection $services) use ($serviceController, &$processed, &$failures) {
            foreach ($services as $service) {
                try {
                    $serviceController->syncServiceCustomFields($service);
                    $processed++;

                    if ($this->output->isVerbose()) {
                        $this->line(sprintf('Resynced service #%d (%s)', $service->id, $service->title ?? 'Untitled'));
                    }
                } catch (Throwable $exception) {
                    $failures++;
                    $this->error(sprintf('Failed to resync service #%d: %s', $service->id, $exception->getMessage()));
                }
            }
        });

        $this->info(sprintf('Resynced %d/%d services.', $processed, $total));

        if ($failures > 0) {
            $this->warn(sprintf('%d services encountered errors during resync.', $failures));

            return Command::FAILURE;
        }

        return Command::SUCCESS;
    }
}