<?php

namespace App\Events;

use Illuminate\Contracts\Events\ShouldDispatchAfterCommit;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class MetalRateCreated implements ShouldDispatchAfterCommit
{
    use Dispatchable;
    use SerializesModels;

    /**
     * @param array<int, array{
     *     governorate_id: int,
     *     governorate_code: string|null,
     *     governorate_name: string|null,
     *     sell_price: string|null,
     *     buy_price: string|null,
     *     is_default: bool
     * }> $quotes
     */
    public function __construct(
        public readonly int $metalId,
        public readonly array $quotes,
        public readonly int $defaultGovernorateId
    ) {
    }
}