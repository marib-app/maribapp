<?php

namespace App\Services\Wifi;

use App\Models\User;
use App\Models\WifiCode;
use App\Models\WifiCodeBatch;
use App\Models\WifiNetwork;
use App\Models\WifiPlan;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use RuntimeException;
use Illuminate\Database\QueryException;

class WifiCodeImportService
{
    /**
     * @throws RuntimeException
     */
    public function createBatchFromUpload(WifiNetwork $network, WifiPlan $plan, UploadedFile $file, User $uploader, array $options = []): WifiCodeBatch
    {
        $rows = $this->parseFile($file);

        if (empty($rows)) {
            throw new RuntimeException(__('The uploaded file does not contain any rows.'));
        }

        $hashes = array_unique(array_column($rows, 'hash'));

        $existingHashes = WifiCode::query()
            ->select('code_hash', 'wifi_network_id')
            ->whereIn('code_hash', $hashes)
            ->get()
            ->reduce(static function (array $carry, WifiCode $code) {
                $carry[$code->code_hash][$code->wifi_network_id] = true;

                return $carry;
            }, []);


        return DB::transaction(function () use ($network, $plan, $file, $uploader, $rows, $existingHashes, $options) {
            $batch = WifiCodeBatch::create([
                'wifi_network_id' => $network->getKey(),
                'wifi_plan_id' => $plan->getKey(),
                'uploaded_by' => $uploader->getKey(),
                'original_filename' => $file->getClientOriginalName(),
                'status' => WifiCodeBatch::STATUS_PENDING,
                'meta' => [
                    'import_options' => $options,
                ],
            ]);

            $accepted = 0;
            $rejected = 0;
            $rejections = [];
            $seenHashes = [];
            $now = Carbon::now();
            $acceptedRecords = [];
            $messages = [
                'missing_code' => __('The row does not contain a Wi-Fi code.'),
                'duplicate_existing_network' => __('This Wi-Fi code already exists in the selected network.'),
                'duplicate_existing_global' => __('This Wi-Fi code is already associated with a different network.'),
                'duplicate_in_file' => __('This Wi-Fi code appears more than once in the uploaded file.'),
            ];


            foreach ($rows as $row) {
                $reason = null;
                $message = null;

                if (empty($row['code'])) {
                    $reason = 'missing_code';
                } elseif (isset($existingHashes[$row['hash']])) {
                    $existingNetworks = array_keys($existingHashes[$row['hash']]);
                    $reason = in_array($network->getKey(), $existingNetworks, true)
                        ? 'duplicate_existing_network'
                        : 'duplicate_existing_global';


                } elseif (isset($seenHashes[$row['hash']])) {
                    $reason = 'duplicate_in_file';
                }

                if ($reason !== null) {
                    $message = $messages[$reason] ?? null;


                    $rejected++;
                    $rejection = [
                        'code' => $row['code'],
                        'reason' => $reason,
                    ];


                    if ($message !== null) {
                        $rejection['message'] = $message;
                    }

                    $rejections[] = $rejection;



                    continue;
                }

                $seenHashes[$row['hash']] = true;
                $accepted++;

                $acceptedRecords[] = [
                    'record' => [
                        'wifi_network_id' => $network->getKey(),
                        'wifi_plan_id' => $plan->getKey(),
                        'wifi_code_batch_id' => $batch->getKey(),
                        'code_encrypted' => Crypt::encryptString($row['code']),
                        'code_hash' => $row['hash'],
                        'username_encrypted' => $row['username'] !== null ? Crypt::encryptString($row['username']) : null,
                        'password_encrypted' => $row['password'] !== null ? Crypt::encryptString($row['password']) : null,
                        'serial_encrypted' => $row['serial_no'] !== null ? Crypt::encryptString($row['serial_no']) : null,
                        'expires_at' => $row['expiry_date'],
                        'status' => WifiCode::STATUS_AVAILABLE,
                        'created_at' => $now,
                        'updated_at' => $now,
                        'meta' => $row['meta'],
                    ],
                    'code' => $row['code'],
                    'hash' => $row['hash'],
                ];
            }

            if (!empty($acceptedRecords)) {
                $this->insertWifiCodes($acceptedRecords, $messages, $accepted, $rejected, $rejections);
            }

            $batch->forceFill([
                'total_rows' => count($rows),
                'accepted_rows' => $accepted,
                'rejected_rows' => $rejected,
                'status' => WifiCodeBatch::STATUS_PROCESSED,
                'processed_at' => Carbon::now(),
                'meta' => array_filter([
                    'import_options' => $options,
                    'rejections' => $rejections,
                ]),
            ])->save();

            return $batch->fresh(['codes']);
        });
    }

    private function insertWifiCodes(array $acceptedRecords, array $messages, int &$accepted, int &$rejected, array &$rejections): void
    {
        $recordsToPersist = $acceptedRecords;

        while (!empty($recordsToPersist)) {
            $records = array_map(static fn (array $acceptedRecord) => $acceptedRecord['record'], $recordsToPersist);

            try {
                WifiCode::insert($records);

                break;
            } catch (QueryException $exception) {
                if (!$this->isUniqueConstraintViolation($exception)) {
                    throw $exception;
                }

                $hashes = array_map(static fn (array $acceptedRecord) => $acceptedRecord['hash'], $recordsToPersist);

                $conflictingHashes = WifiCode::query()
                    ->whereIn('code_hash', $hashes)
                    ->pluck('code_hash')
                    ->all();

                if ($conflictingHashes === []) {
                    throw $exception;
                }

                $conflictingLookup = array_flip($conflictingHashes);

                $recordsToPersist = array_values(array_filter($recordsToPersist, function (array $acceptedRecord) use (&$accepted, &$rejected, &$rejections, $messages, $conflictingLookup) {
                    if (!isset($conflictingLookup[$acceptedRecord['hash']])) {
                        return true;
                    }

                    $accepted--;
                    $rejected++;

                    $rejection = [
                        'code' => $acceptedRecord['code'],
                        'reason' => 'duplicate_existing_global',
                    ];

                    $message = $messages['duplicate_existing_global'] ?? null;

                    if ($message !== null) {
                        $rejection['message'] = $message;
                    }

                    $rejections[] = $rejection;

                    return false;
                }));
            }
        }
    }

    private function isUniqueConstraintViolation(QueryException $exception): bool
    {
        $sqlState = $exception->getCode();

        if (in_array($sqlState, ['23000', '23505'], true)) {
            return true;
        }

        $driverSpecificCode = $exception->errorInfo[1] ?? null;

        return in_array($driverSpecificCode, [19, 1062, 1557, 2627, 2601], true);
    }


    private function parseFile(UploadedFile $file): array
    {
        $extension = Str::lower($file->getClientOriginalExtension());

        return match ($extension) {
            'csv' => $this->parseCsv($file),
            'xlsx', 'xls' => $this->parseSpreadsheet($file),
            default => throw new RuntimeException(__('Unsupported file type: :type', ['type' => $extension])),
        };
    }

    private function parseCsv(UploadedFile $file): array
    {
        $handle = fopen($file->getRealPath(), 'rb');

        if ($handle === false) {
            throw new RuntimeException(__('Unable to open the uploaded file.'));
        }

        $header = null;
        $rows = [];

        while (($data = fgetcsv($handle)) !== false) {
            if ($header === null) {
                $header = $this->normaliseHeader($data);
                continue;
            }

            $row = $this->mapRow($header, $data);

            if ($row !== null) {
                $rows[] = $row;
            }
        }

        fclose($handle);

        return $rows;
    }

    private function parseSpreadsheet(UploadedFile $file): array
    {
        if (!class_exists('\\PhpOffice\\PhpSpreadsheet\\IOFactory')) {
            throw new RuntimeException(__('XLSX imports require the phpoffice/phpspreadsheet package.'));
        }

        $spreadsheet = \PhpOffice\PhpSpreadsheet\IOFactory::load($file->getRealPath());
        $worksheet = $spreadsheet->getActiveSheet();

        $header = null;
        $rows = [];

        foreach ($worksheet->toArray(null, true, true, false) as $data) {
            if ($header === null) {
                $header = $this->normaliseHeader($data);
                continue;
            }

            $row = $this->mapRow($header, $data);

            if ($row !== null) {
                $rows[] = $row;
            }
        }

        return $rows;
    }

    private function normaliseHeader(array $columns): array
    {
        $normalised = [];

        foreach ($columns as $column) {
            $key = Str::of($column)->trim()->lower()->snake()->value();

            $normalised[] = match ($key) {
                'code', 'voucher', 'pin' => 'code',
                'user', 'username' => 'username',
                'pass', 'password' => 'password',
                'serial', 'serial_no', 'serial_number' => 'serial_no',
                'expiry', 'expires', 'expiry_date', 'expiration_date' => 'expiry_date',
                default => 'meta',
            };
        }

        return $normalised;
    }

    private function mapRow(array $header, array $data): ?array
    {
        $mapped = [
            'code' => null,
            'username' => null,
            'password' => null,            
            'serial_no' => null,

            'expiry_date' => null,

            'meta' => [],
        ];

        foreach ($header as $index => $column) {
            $value = $data[$index] ?? null;
            $value = is_string($value) ? trim($value) : $value;

            if ($column === 'meta') {
                if ($value !== null && $value !== '') {
                    $mapped['meta'][] = $value;
                }

                continue;
            }

            if ($value === null || $value === '') {
                continue;
            }

            if ($column === 'expiry_date') {
                try {
                    $mapped['expiry_date'] = Carbon::parse($value);
                } catch (\Throwable $throwable) {
                    $mapped['expiry_date'] = null;
                }

                continue;
            }

            $mapped[$column] = $value;
        }

        if ($mapped['code'] === null || $mapped['code'] === '') {
            return null;
        }

        if (!empty($mapped['meta'])) {
            $mapped['meta'] = ['columns' => $mapped['meta']];
        } else {
            $mapped['meta'] = null;
        }

        $mapped['hash'] = WifiCode::hashCode($mapped['code']);

        return $mapped;
    }
}