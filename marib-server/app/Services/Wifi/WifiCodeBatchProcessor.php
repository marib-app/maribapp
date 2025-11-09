<?php

namespace App\Services\Wifi;

use App\Enums\Wifi\WifiCodeBatchStatus;
use App\Enums\Wifi\WifiCodeStatus;
use App\Enums\Wifi\WifiPlanStatus;
use App\Models\Wifi\WifiCode;
use App\Models\Wifi\WifiCodeBatch;
use App\Models\Wifi\WifiPlan;
use Carbon\Carbon;
use Illuminate\Contracts\Filesystem\FileNotFoundException;
use Illuminate\Database\DatabaseManager;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use PhpOffice\PhpSpreadsheet\Cell\Coordinate;
use PhpOffice\PhpSpreadsheet\IOFactory;
use PhpOffice\PhpSpreadsheet\Shared\Date as ExcelDate;
use RuntimeException;
use Throwable;

class WifiCodeBatchProcessor
{
    public function __construct(private readonly DatabaseManager $db)
    {
    }

    /**
     * @return array{accepted:int,rejected:int,duplicates:int,errors:array<int,array<string,mixed>>}
     */
    public function process(WifiPlan $plan, WifiCodeBatch $batch, string $storagePath): array
    {
        $fullPath = Storage::path($storagePath);

        if (! is_file($fullPath) || ! is_readable($fullPath)) {
            throw new FileNotFoundException(sprintf('Unable to read uploaded batch file at %s', $fullPath));
        }

        $extension = strtolower(pathinfo($fullPath, PATHINFO_EXTENSION));

        $rows = $this->readRows($fullPath, $extension);

        $candidates = [];
        $errors = [];
        $seenHashes = [];
        $rowNumber = 1;
        $duplicates = 0;

        foreach ($rows as $row) {
            $rowNumber++;

            $normalized = $this->normalizeRow($row);
            if ($normalized === null) {
                $errors[] = [
                    'row' => $rowNumber,
                    'message' => __('تم تجاهل الصف لعدم احتوائه على كود صالح.'),
                ];
                continue;
            }

            $hash = $normalized['hash'];

            if (isset($seenHashes[$hash])) {
                $duplicates++;
                $errors[] = [
                    'row' => $rowNumber,
                    'message' => __('تم رفض الكود بسبب تكراره داخل الملف.'),
                ];
                continue;
            }

            $seenHashes[$hash] = true;
            $normalized['row_number'] = $rowNumber;
            $candidates[] = $normalized;
        }

        if ($candidates === []) {
            return [
                'accepted' => 0,
                'rejected' => count($errors),
                'duplicates' => $duplicates,
                'errors' => $errors,
            ];
        }

        $existingHashes = WifiCode::query()
            ->whereIn('code_hash', array_column($candidates, 'hash'))
            ->pluck('code_hash')
            ->all();

        $existingMap = array_flip($existingHashes);

        $accepted = [];

        foreach ($candidates as $candidate) {
            if (isset($existingMap[$candidate['hash']])) {
                $duplicates++;
                $errors[] = [
                    'row' => $candidate['row_number'],
                    'message' => __('تم رفض الكود بسبب تكراره في المنصة.'),
                ];
                continue;
            }

            $accepted[] = $candidate;
        }

        if ($accepted === []) {
            return [
                'accepted' => 0,
                'rejected' => count($errors),
                'duplicates' => $duplicates,
                'errors' => $errors,
            ];
        }

        $summary = [
            'accepted' => count($accepted),
            'rejected' => count($errors),
            'duplicates' => $duplicates,
            'errors' => $errors,
        ];

        $this->db->transaction(function () use ($plan, $batch, $accepted, &$summary): void {
            $now = Carbon::now();

            foreach ($accepted as $candidate) {
                $code = new WifiCode();
                $code->wifi_network_id = $plan->wifi_network_id;
                $code->wifi_plan_id = $plan->getKey();
                $code->wifi_code_batch_id = $batch->getKey();
                $code->status = WifiCodeStatus::AVAILABLE;
                $code->code = $candidate['code'];
                $code->username = $candidate['username'];
                $code->password = $candidate['password'];
                $code->serialNo = $candidate['serial_no'];
                $code->expiry_date = $candidate['expiry_date'];
                $code->meta = array_filter([
                    'source_row' => $candidate['row_number'],
                ]);
                $code->created_at = $now;
                $code->updated_at = $now;
                $code->save();
            }

            $batch->total_codes = ($batch->total_codes ?? 0) + $summary['accepted'];
            $batch->available_codes = ($batch->available_codes ?? 0) + $summary['accepted'];

            if ($summary['accepted'] > 0) {
                $batch->status = WifiCodeBatchStatus::ACTIVE;
                $batch->validated_at = $batch->validated_at ?? $now;
                $batch->activated_at = $batch->activated_at ?? $now;
            } else {
                $batch->status = WifiCodeBatchStatus::VALIDATED;
                $batch->validated_at = $batch->validated_at ?? $now;
            }


            $batch->save();

            if (
                $summary['accepted'] > 0
                && in_array($plan->status, [WifiPlanStatus::UPLOADED, WifiPlanStatus::VALIDATED], true)
            ) {
                $plan->status = WifiPlanStatus::ACTIVE;

                
                $plan->save();
            }
        });

        return $summary;
    }

    /**
     * @return iterable<int, array<string, mixed>>
     */
    protected function readRows(string $path, string $extension): iterable
    {
        return match ($extension) {
            'xlsx', 'xlsm' => $this->readSpreadsheetRows($path),
            default => $this->readCsvRows($path),
        };
    }

    /**
     * @return iterable<int, array<string, mixed>>
     */
    protected function readCsvRows(string $path): iterable
    {
        $handle = fopen($path, 'rb');

        if ($handle === false) {
            throw new RuntimeException('Unable to open CSV file for reading.');
        }

        $headers = null;
        $rowIndex = 0;
        $pendingDataRow = null;

        try {
            while (($row = fgetcsv($handle)) !== false) {
                $rowIndex++;

                if ($headers === null) {
                    $normalizedHeaders = $this->normalizeHeaders($row);

                    if ($this->headersContainCodeColumn($normalizedHeaders)) {
                        $headers = $normalizedHeaders;
                        continue;
                    }

                    if ($this->rowHasAnyValue($row)) {
                        $headers = $this->buildCodeOnlyHeaders(max(count($row), 1), 0);
                        $pendingDataRow = $row;
                    } else {
                        $headers = $this->buildCodeOnlyHeaders(1, 0);
                        continue;
                    }
                }

                $currentRow = $pendingDataRow ?? $row;
                $pendingDataRow = null;

                if ($currentRow === [null] || $currentRow === false || ! $this->rowHasAnyValue($currentRow)) {
                    continue;
                }

                $values = [];
                foreach ($headers as $index => $header) {
                    if ($header === null) {
                        continue;
                    }

                    $values[$header] = $currentRow[$index] ?? null;
                }

                yield $values;
            }
        } finally {
            fclose($handle);
        }
    }

    /**
     * @return iterable<int, array<string, mixed>>
     */
    protected function readSpreadsheetRows(string $path): iterable
    {
        if (! class_exists(IOFactory::class)) {
            throw new RuntimeException('PhpSpreadsheet is required to parse XLSX files.');
        }

        try {
            $spreadsheet = IOFactory::load($path);
        } catch (Throwable $exception) {
            Log::error('wifi.codes.batch.parse_failed', [
                'path' => $path,
                'exception' => $exception,
            ]);
            throw new RuntimeException('تعذر قراءة ملف الأكواد المرفوع.', 0, $exception);
        }

        $sheet = $spreadsheet->getActiveSheet();
        $highestRow = $sheet->getHighestDataRow();
        $highestColumn = $sheet->getHighestDataColumn();
        $highestColumnIndex = Coordinate::columnIndexFromString($highestColumn);

        $headers = [];
        $hasCodeHeader = false;

        for ($col = 1; $col <= $highestColumnIndex; $col++) {
            $columnLetter = Coordinate::stringFromColumnIndex($col);
            $cellValue = $sheet->getCell($columnLetter . '1')?->getValue();
            $header = $this->normalizeHeaderValue($cellValue);
            if ($header === 'code') {
                $hasCodeHeader = true;
            }
            $headers[$col] = $header;
        }

        $dataStartRow = 2;
        if (! $hasCodeHeader) {
            $headers = $this->buildCodeOnlyHeaders($highestColumnIndex, 1);
            $dataStartRow = 1;
        }

        for ($row = $dataStartRow; $row <= $highestRow; $row++) {
            $values = [];
            $rowHasData = false;

            for ($col = 1; $col <= $highestColumnIndex; $col++) {
                $header = $headers[$col] ?? null;
                if ($header === null) {
                    continue;
                }

                $columnLetter = Coordinate::stringFromColumnIndex($col);
                $cell = $sheet->getCell($columnLetter . (string) $row);
                $value = $cell?->getValue();

                if (is_numeric($value) && $header === 'expiry_date' && $cell?->getDataType() === 'n') {
                    try {
                        $date = ExcelDate::excelToDateTimeObject((float) $value);
                        $value = $date?->format('Y-m-d');
                    } catch (Throwable) {
                        // leave as-is if conversion fails
                    }
                }

                if ($value !== null && $value !== '') {
                    $rowHasData = true;
                }

                $values[$header] = $value;
            }

            if (! $rowHasData) {
                continue;
            }

            yield $values;
        }
    }

    /**
     * @param array<int, string|null> $headers
     * @return array<int, string|null>
     */
    protected function normalizeHeaders(array $headers): array
    {
        $normalized = [];

        foreach ($headers as $index => $header) {
            $normalized[$index] = $this->normalizeHeaderValue($header);
        }

        return $normalized;
    }

    protected function normalizeHeaderValue(mixed $value): ?string
    {
        if ($value === null) {
            return null;
        }

        $string = trim((string) $value);

        if ($string === '') {
            return null;
        }

        $canonical = Str::snake(Str::lower($string));

        return match ($canonical) {
            'code', 'voucher_code', 'wifi_code' => 'code',
            'username', 'user_name', 'login' => 'username',
            'password', 'pass' => 'password',
            'serial', 'serial_no', 'serial_number' => 'serial_no',
            'expiry', 'expiry_date', 'expires_at', 'valid_until' => 'expiry_date',
            default => null,
        };
    }

    /**
     * @param array<string, mixed> $row
     * @return array<string, mixed>|null
     */
    protected function normalizeRow(array $row): ?array
    {
        $code = $this->normalizeNullableString($row['code'] ?? null);

        if ($code === null) {
            return null;
        }

        $hash = $this->hashCode($code);

        $username = $this->normalizeNullableString($row['username'] ?? null);
        $password = $this->normalizeNullableString($row['password'] ?? null);
        $serial = $this->normalizeNullableString($row['serial_no'] ?? null);
        $expiry = $this->normalizeExpiryDate($row['expiry_date'] ?? null);

        return [
            'code' => $code,
            'username' => $username,
            'password' => $password,
            'serial_no' => $serial,
            'expiry_date' => $expiry,
            'hash' => $hash,
        ];
    }

    protected function normalizeNullableString(mixed $value): ?string
    {
        if ($value === null) {
            return null;
        }

        if (is_string($value)) {
            $trimmed = trim($value);
            return $trimmed === '' ? null : $trimmed;
        }

        if (is_numeric($value)) {
            return trim((string) $value);
        }

        return null;
    }

    protected function normalizeExpiryDate(mixed $value): ?Carbon
    {
        $string = $this->normalizeNullableString($value);

        if ($string === null) {
            return null;
        }

        try {
            return Carbon::parse($string)->startOfDay();
        } catch (Throwable) {
            return null;
        }
    }

    protected function hashCode(string $code): string
    {
        $normalized = Str::of($code)
            ->lower()
            ->replaceMatches('/\s+/u', '')
            ->value();

        return hash('sha256', $normalized);
    }

    /**
     * @param array<int|string, string|null> $headers
     */
    protected function headersContainCodeColumn(array $headers): bool
    {
        foreach ($headers as $header) {
            if ($header === 'code') {
                return true;
            }
        }

        return false;
    }

    protected function buildCodeOnlyHeaders(int $columnCount, int $startIndex = 0): array
    {
        $columnCount = max(1, $columnCount);
        $headers = [];

        for ($i = 0; $i < $columnCount; $i++) {
            $index = $startIndex + $i;
            $headers[$index] = $i === 0 ? 'code' : null;
        }

        return $headers;
    }

    protected function rowHasAnyValue(array $row): bool
    {
        foreach ($row as $value) {
            if ($value === null) {
                continue;
            }
            if (is_string($value) && trim($value) === '') {
                continue;
            }
            return true;
        }

        return false;
    }
}
