<?php

namespace App\Services;

use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Intervention\Image\Facades\Image;
use Intervention\Image\Image as InterventionImage;
use RuntimeException;
use Throwable;

class ImageVariantService
{
    private const THUMBNAIL_MAX_EDGE = 240;
    private const DETAIL_MAX_EDGE = 720;
    private const DEFAULT_QUALITY = 80;

    /**
     * @return array{original:string, thumbnail:string, detail:string, fallback:string}
     */
    public static function storeWithVariants(UploadedFile $file, string $folder): array
    {
        $disk = Storage::disk(config('filesystems.default'));
        $uniqueBase = uniqid('', true) . '-' . time();
        $originalExtension = strtolower($file->getClientOriginalExtension() ?: 'jpg');

        $pathsToCleanup = [];

        try {
            $image = Image::make($file->getRealPath())->orientate();

            $thumbnailPath = self::storeVariant(
                clone $image,
                $folder,
                $uniqueBase . '-thumb',
                self::THUMBNAIL_MAX_EDGE,
                ['avif', 'webp'],
                $originalExtension
            );
            $pathsToCleanup[] = $thumbnailPath;

            $detailPath = self::storeVariant(
                clone $image,
                $folder,
                $uniqueBase . '-detail',
                self::DETAIL_MAX_EDGE,
                ['avif', 'webp'],
                $originalExtension
            );
            $pathsToCleanup[] = $detailPath;

            $originalFilename = $uniqueBase . '.' . $originalExtension;
            $disk->putFileAs($folder, $file, $originalFilename);
            $originalPath = $folder . '/' . $originalFilename;

            return [
                'original'  => $originalPath,
                'thumbnail' => $thumbnailPath,
                'detail'    => $detailPath,
                'fallback'  => $originalPath,
            ];
        } catch (Throwable $exception) {
            self::deleteStoredVariants($pathsToCleanup);

            throw new RuntimeException('Unable to create image variants', 0, $exception);
        }
    }

    /**
     * @param array<int, string|null> $paths
     */
    public static function deleteStoredVariants(array $paths): void
    {
        $disk = Storage::disk(config('filesystems.default'));

        foreach ($paths as $path) {
            if (! empty($path) && $disk->exists($path)) {
                $disk->delete($path);
            }
        }
    }

    private static function storeVariant(
        InterventionImage $image,
        string $folder,
        string $fileBase,
        int $maxEdge,
        array $preferredFormats,
        string $fallbackExtension
    ): string {
        $image->resize($maxEdge, $maxEdge, static function ($constraint) {
            $constraint->aspectRatio();
            $constraint->upsize();
        });

        return self::encodeAndStore($image, $folder, $fileBase, $preferredFormats, $fallbackExtension);
    }

    private static function encodeAndStore(
        InterventionImage $image,
        string $folder,
        string $fileBase,
        array $preferredFormats,
        string $fallbackExtension
    ): string {
        $disk = Storage::disk(config('filesystems.default'));

        foreach ($preferredFormats as $format) {
            try {
                $encoded = $image->encode($format, self::DEFAULT_QUALITY);
                $path = sprintf('%s/%s.%s', $folder, $fileBase, $format);
                $disk->put($path, (string) $encoded);

                return $path;
            } catch (Throwable $throwable) {
                // Try the next format.
            }
        }

        $normalizedFallback = self::normalizeFallbackFormat($fallbackExtension);
        $fallbackExtensionNormalized = self::extensionFromFormat($normalizedFallback);

        try {
            $encoded = $image->encode($normalizedFallback, self::DEFAULT_QUALITY);
        } catch (Throwable $throwable) {
            $encoded = $image->encode($normalizedFallback);
        }

        $path = sprintf('%s/%s.%s', $folder, $fileBase, $fallbackExtensionNormalized);
        $disk->put($path, (string) $encoded);

        return $path;
    }

    private static function normalizeFallbackFormat(string $extension): string
    {
        $extension = strtolower($extension);

        return match ($extension) {
            'jpg', 'jpeg' => 'jpeg',
            'png' => 'png',
            'webp' => 'webp',
            'avif' => 'avif',
            default => 'png',
        };
    }

    private static function extensionFromFormat(string $format): string
    {
        return $format === 'jpeg' ? 'jpg' : $format;
    }
}