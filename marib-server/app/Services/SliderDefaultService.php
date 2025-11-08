<?php

namespace App\Services;

use App\Models\SliderDefault;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;

class SliderDefaultService
{
    private string $storageFolder = 'slider-defaults';

    public function listDefaults(): Collection
    {
        return SliderDefault::query()
            ->orderBy('interface_type')
            ->get();
    }

    public function listActiveDefaults(): Collection
    {
        return SliderDefault::query()
            ->active()
            ->orderBy('interface_type')
            ->get();
    }

    public function upsert(string $interfaceType, UploadedFile $image): SliderDefault
    {
        $interfaceType = $this->normalizeInterfaceType($interfaceType);

        return DB::transaction(function () use ($interfaceType, $image) {
            $record = SliderDefault::query()->where('interface_type', $interfaceType)->first();

            $path = FileService::compressAndUpload($image, $this->storageFolder);

            if ($record) {
                FileService::delete($record->image_path);
                $record->fill([
                    'image_path' => $path,
                    'status'     => SliderDefault::STATUS_ACTIVE,
                ]);
                $record->save();

                return $record->refresh();
            }

            return SliderDefault::query()->create([
                'interface_type' => $interfaceType,
                'image_path'     => $path,
                'status'         => SliderDefault::STATUS_ACTIVE,
            ]);
        });
    }

    public function delete(SliderDefault $sliderDefault): void
    {
        DB::transaction(function () use ($sliderDefault) {
            FileService::delete($sliderDefault->image_path);
            $sliderDefault->delete();
        });
    }

    public function findActiveForInterface(?string $interfaceType): ?SliderDefault
    {
        $interfaceType = $this->normalizeInterfaceType($interfaceType ?? 'all');

        $interfaces = $this->expandInterfaceTypes($interfaceType);

        $records = SliderDefault::query()
            ->active()
            ->whereIn('interface_type', $interfaces)
            ->get()
            ->keyBy('interface_type');

        foreach ($interfaces as $candidate) {
            if ($records->has($candidate)) {
                return $records->get($candidate);
            }
        }

        return null;
    }

    private function normalizeInterfaceType(string $interfaceType): string
    {
        $interfaceType = trim($interfaceType);

        if ($interfaceType === '' || $interfaceType === 'all') {
            return 'all';
        }

        return InterfaceSectionService::normalizeSectionType($interfaceType);
    }

    private function expandInterfaceTypes(string $interfaceType): array
    {
        if ($interfaceType === 'all') {
            return ['all'];
        }

        $variants = InterfaceSectionService::sectionTypeVariants($interfaceType);

        return array_values(array_unique(array_merge($variants, ['all'])));
    }
}
