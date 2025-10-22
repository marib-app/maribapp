<?php

namespace App\Services;

/**
 * @phpstan-type InvoiceViewData array<string, mixed>
 */
class InvoiceDocument
{
    /**
     * @param InvoiceViewData $viewData
     */
    public function __construct(
        public readonly string $fileName,
        public readonly string $html,
        public readonly ?string $pdf,
        public readonly array $viewData = [],
    ) {
    }

    public function hasPdf(): bool
    {
        return $this->pdf !== null && $this->pdf !== '';
    }
}