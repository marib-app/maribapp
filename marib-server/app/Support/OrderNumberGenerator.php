<?php

namespace App\Support;
use Illuminate\Support\Facades\Log;
use RuntimeException;
use Throwable;
use Illuminate\Support\Str;

class OrderNumberGenerator
{

    /**
     * @var callable|null
     */
    private static $orderedUuidFactory = null;

    /**
     * @var callable|null
     */
    private static $fallbackUuidFactory = null;


    public static function provisional(): string
    {
                $uuid = null;

        try {
            $uuid = self::resolveOrderedUuidFactory()();
        } catch (Throwable $exception) {
            Log::warning('order_number.provisional_generation_failed', [
                'stage' => 'ordered_uuid',
                'message' => $exception->getMessage(),
            ]);

            try {
                $uuid = self::resolveFallbackUuidFactory()();
            } catch (Throwable $fallbackException) {
                Log::error('order_number.provisional_generation_failed', [
                    'stage' => 'uuid_fallback',
                    'message' => $fallbackException->getMessage(),
                ]);

                throw new RuntimeException(
                    'Unable to generate provisional order number.',
                    0,
                    $fallbackException
                );
            }
        }

        $uuid = trim((string) $uuid);

        if ($uuid === '') {
            Log::error('order_number.provisional_generation_failed', [
                'stage' => 'empty_uuid',
            ]);

            throw new RuntimeException('Unable to generate provisional order number: empty value.');
        }

        return 'temp-' . $uuid;
    }

    public static function useCustomGenerators(?callable $orderedFactory, ?callable $fallbackFactory = null): void
    {
        self::$orderedUuidFactory = $orderedFactory;
        self::$fallbackUuidFactory = $fallbackFactory;
    }

    public static function flushCustomGenerators(): void
    {
        self::$orderedUuidFactory = null;
        self::$fallbackUuidFactory = null;
    }

    private static function resolveOrderedUuidFactory(): callable
    {
        return self::$orderedUuidFactory ?? static function (): string {
            return Str::orderedUuid()->toString();
        };
    }

    private static function resolveFallbackUuidFactory(): callable
    {
        return self::$fallbackUuidFactory ?? static function (): string {
            return Str::uuid()->toString();
        };

        
    }
}