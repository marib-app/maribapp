<?php

namespace App\Services;

use Illuminate\Support\Facades\Log;

class TelemetryService
{
    public function record(string $event, array $context = []): void
    {
        Log::info($event, $context);
    }

    public static function __callStatic(string $name, array $arguments): mixed
    {
        return app(self::class)->{$name}(...$arguments);
    }

}