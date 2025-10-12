<?php

namespace App\Support;

class FeaturedSectionQueryState
{
    public function __construct(
        public readonly string $filter,
        public readonly string $priceColumn,
        public readonly string $priceColumnQualified,
        public readonly ?float $minPrice,
        public readonly ?float $maxPrice,
    ) {
    }
}