<?php

namespace App\Services;

use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class MetalIconStorageService
{
    private const DISK = 'public';
    private const DIRECTORY = 'metal/icons';

    public function storeIcon(UploadedFile $icon, ?string $existingPath = null): string
    {
        if ($existingPath) {
            $this->deleteIcon($existingPath);
        }

        $filename = Str::uuid() . '.' . $icon->getClientOriginalExtension();

        return $icon->storeAs(self::DIRECTORY, $filename, self::DISK);
    }

    public function deleteIcon(?string $path): void
    {
        if (!$path) {
            return;
        }

        $disk = Storage::disk(self::DISK);

        if ($disk->exists($path)) {
            $disk->delete($path);
        }
    }

    public function getUrl(?string $path): ?string
    {
        if (!$path) {
            return null;
        }

        return Storage::disk(self::DISK)->url($path);
    }
}