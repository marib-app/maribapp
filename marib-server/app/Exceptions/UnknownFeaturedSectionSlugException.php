<?php

namespace App\Exceptions;

use RuntimeException;

class UnknownFeaturedSectionSlugException extends RuntimeException
{
    public function __construct(string $slug)
    {
        parent::__construct(sprintf('Unknown featured section slug: %s', $slug));
    }
}