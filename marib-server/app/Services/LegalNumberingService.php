<?php

namespace App\Services;

use App\Models\DepartmentNumberSetting;
use Illuminate\Database\DatabaseManager;
use Illuminate\Support\Arr;
use Illuminate\Support\Str;

class LegalNumberingService
{
    public function __construct(private readonly DatabaseManager $db)
    {
    }

    public function formatOrderNumber(int $id, ?string $department = null, ?string $currentNumber = null): string
    {
        $issued = $this->issueOrderNumber($department, $currentNumber);

        return $issued ?? (string) $id;
    }

    public function generateInvoiceNumber(?string $department = null): string
    {
        $issued = $this->issueNumber($department, 'invoice');

        if ($issued !== null) {
            return $issued;
        }

        return $this->fallbackInvoiceNumber($department);
    }

    public function updateSettings(string $department, array $attributes): DepartmentNumberSetting
    {
        $normalizedDepartment = $this->normalizeDepartment($department);

        $payload = [
            'department' => $normalizedDepartment,
            'legal_numbering_enabled' => (bool) Arr::get($attributes, 'legal_numbering_enabled', false),
            'order_prefix' => $this->normalizePrefix(Arr::get($attributes, 'order_prefix')),
            'invoice_prefix' => $this->normalizePrefix(Arr::get($attributes, 'invoice_prefix')),
            'next_order_number' => $this->normalizeSequence(Arr::get($attributes, 'next_order_number', 1)),
            'next_invoice_number' => $this->normalizeSequence(Arr::get($attributes, 'next_invoice_number', 1)),
        ];

        $setting = DepartmentNumberSetting::query()->updateOrCreate(
            ['department' => $normalizedDepartment],
            Arr::except($payload, ['department'])
        );

        return $setting->refresh();
    }

    public function normalizeDepartment(?string $department): string
    {
        $department = trim((string) $department);

        return $department !== ''
            ? $department
            : DepartmentNumberSetting::DEFAULT_DEPARTMENT;
    }

    private function issueOrderNumber(?string $department, ?string $currentNumber = null): ?string
    {
        return $this->issueNumber($department, 'order', $currentNumber);
    }

    private function issueNumber(?string $department, string $type, ?string $currentNumber = null): ?string
    {
        $normalizedDepartment = $this->normalizeDepartment($department);

        return $this->db->transaction(function () use ($normalizedDepartment, $type, $currentNumber) {
            $setting = DepartmentNumberSetting::query()
                ->where('department', $normalizedDepartment)
                ->lockForUpdate()
                ->first();

            if ($setting === null) {
                $setting = DepartmentNumberSetting::query()->create([
                    'department' => $normalizedDepartment,
                    'legal_numbering_enabled' => false,
                    'order_prefix' => null,
                    'invoice_prefix' => null,
                    'next_order_number' => 1,
                    'next_invoice_number' => 1,
                ]);
            }

            if (! $setting->legal_numbering_enabled) {
                return null;
            }

            if ($currentNumber !== null && $this->matchesExistingNumber($currentNumber, $setting, $type)) {
                return $currentNumber;
            }

            $sequenceField = $type === 'order' ? 'next_order_number' : 'next_invoice_number';
            $prefixField = $type === 'order' ? 'order_prefix' : 'invoice_prefix';

            $sequence = $setting->{$sequenceField};

            $setting->{$sequenceField} = $sequence + 1;
            $setting->save();

            return $this->applyPrefix($setting->{$prefixField}, $sequence);
        }, 5);
    }

    private function matchesExistingNumber(string $number, DepartmentNumberSetting $setting, string $type): bool
    {
        $sequenceField = $type === 'order' ? 'next_order_number' : 'next_invoice_number';
        $prefix = $type === 'order' ? $setting->order_prefix : $setting->invoice_prefix;

        if ($prefix !== null && $prefix !== '') {
            return str_starts_with($number, $prefix);
        }

        if (ctype_digit($number)) {
            return (int) $number < $setting->{$sequenceField};
        }

        return false;
    }

    private function applyPrefix(?string $prefix, int $sequence): string
    {
        $prefix = $prefix ?? '';

        return $prefix . $sequence;
    }

    private function normalizePrefix($prefix): ?string
    {
        if ($prefix === null) {
            return null;
        }

        $prefix = trim((string) $prefix);

        return $prefix === '' ? null : $prefix;
    }

    private function normalizeSequence($sequence): int
    {
        $sequence = (int) $sequence;

        return $sequence > 0 ? $sequence : 1;
    }

    private function fallbackInvoiceNumber(?string $department): string
    {
        $prefix = $this->sanitizeDepartmentPrefix($department);

        return $prefix . 'INV-' . Str::upper(Str::random(8));
    }

    private function sanitizeDepartmentPrefix(?string $department): string
    {
        if ($department === null || $department === '') {
            return '';
        }

        $clean = preg_replace('/[^A-Z0-9]/', '', strtoupper($department));

        if (! is_string($clean) || $clean === '') {
            return '';
        }

        return $clean . '-';
    }
}