<?php

namespace App\Console\Commands;

use App\Models\UserFcmToken;
use Carbon\CarbonImmutable;
use Illuminate\Console\Command;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Collection;

class PruneStaleUserFcmTokens extends Command
{
    protected $signature = 'fcm:prune-tokens {--days=90 : Number of days to keep inactive tokens.} {--dry-run : Report matched tokens without deleting them.}';

    protected $description = 'Remove unused or invalid user FCM tokens to keep the pool clean.';

    public function handle(): int
    {
        $days = (int) $this->option('days');
        if ($days <= 0) {
            $days = 90;
        }

        $cutoff = CarbonImmutable::now()->subDays($days);

        $query = $this->buildPrunableQuery($cutoff);

        $totalMatched = (clone $query)->count();

        if ($totalMatched === 0) {
            $this->info('No stale FCM tokens found.');

            return self::SUCCESS;
        }

        $dryRun = (bool) $this->option('dry-run');

        if ($dryRun) {
            $this->info(sprintf('Dry run: %d tokens would be pruned.', $totalMatched));

            return self::SUCCESS;
        }

        $deleted = 0;

        (clone $query)->chunkById(500, function (Collection $tokens) use (&$deleted): void {
            $ids = $tokens->pluck('id');

            if ($ids->isEmpty()) {
                return;
            }

            $deleted += UserFcmToken::whereIn('id', $ids)->delete();
        });

        $this->info(sprintf('Pruned %d stale FCM tokens (matched %d).', $deleted, $totalMatched));

        return self::SUCCESS;
    }

    protected function buildPrunableQuery(CarbonImmutable $cutoff): Builder
    {
        return UserFcmToken::query()
            ->where(function (Builder $query) use ($cutoff): void {
                $query
                    ->whereNull('last_activity_at')
                    ->where('updated_at', '<', $cutoff);
            })
            ->orWhere(function (Builder $query) use ($cutoff): void {
                $query->where('last_activity_at', '<', $cutoff);
            })
            ->orWhereDoesntHave('user');
    }
}