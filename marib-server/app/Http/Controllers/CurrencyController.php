<?php

namespace App\Http\Controllers;



use App\Events\CurrencyRatesUpdated;
use App\Events\CurrencyCreated;
use App\Jobs\BackfillCurrencyRateHistory;
use App\Models\CurrencyRate;
use App\Models\CurrencyRateQuote;
use App\Models\Governorate;
use App\Services\CurrencyIconStorageService;
use App\Services\CurrencyRateHistoryService;
use App\Services\ResponseService;
use Carbon\Carbon;
use DateTimeInterface;
use App\Models\CurrencyRateChangeLog;
use Illuminate\Http\Request;
use App\Services\CurrencyDataMonitor;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use RuntimeException;
use Symfony\Component\HttpFoundation\Response;
use Throwable;




class CurrencyController extends Controller
{

    public function __construct(
        private readonly CurrencyIconStorageService $iconStorageService,
        private readonly CurrencyRateHistoryService $historyService,
        private readonly CurrencyDataMonitor $currencyDataMonitor
    )
    
    
    {
    }

    public function index()
    {
        $governorates = Governorate::orderBy('name')->get();


        return view('currency.index', compact('governorates'));

    }

    public function create()
    {
        $governorates = Governorate::orderBy('name')->get();

        return view('currency.create', [
            'governorates' => $governorates,
            'governorateStoreUrl' => route('governorates.store'),
        ]);

    }


    public function edit(int $id)
    {
        $currency = CurrencyRate::with(['quotes' => function ($query) {
            $query->orderBy('governorate_id');
        }, 'quotes.governorate'])->findOrFail($id);

        $governorates = Governorate::orderBy('name')->get();

        $quotes = $currency->quotes
            ->mapWithKeys(static function (CurrencyRateQuote $quote): array {
                return [
                    $quote->governorate_id => [
                        'sell_price' => $quote->sell_price,
                        'buy_price' => $quote->buy_price,
                        'source' => $quote->source,
                        'quoted_at' => optional($quote->quoted_at)?->toDateTimeString(),
                        'is_default' => (bool) $quote->is_default,
                    ],
                ];
            })
            ->toArray();

        $defaultGovernorateId = $currency->quotes->firstWhere('is_default', true)?->governorate_id;

        return view('currency.edit', [
            'currency' => $currency,
            'governorates' => $governorates,
            'governorateStoreUrl' => route('governorates.store'),
            'quotes' => $quotes,
            'defaultGovernorateId' => $defaultGovernorateId,
        ]);

    }

    public function import(Request $request)
    {
        ResponseService::noAnyPermissionThenSendJson(['currency-rate-import']);

        $validator = Validator::make($request->all(), [
            'file' => 'required|file|mimes:csv,txt,xlsx,xls|max:5120',
        ]);

        if ($validator->fails()) {
            $errors = $validator->errors();

            return response()->json([
                'success' => false,
                'message' => $errors->first('file') ?? __('Unable to import the provided file.'),
                'errors' => $errors,
            ], Response::HTTP_UNPROCESSABLE_ENTITY);
        }

        /** @var UploadedFile $file */
        $file = $request->file('file');

        try {
            $parseResult = $this->parseImportFile($file);
        } catch (RuntimeException $exception) {
            Log::error('Currency rate import parsing failed', ['message' => $exception->getMessage()]);

            return response()->json([
                'success' => false,
                'message' => $exception->getMessage(),
                'report' => [
                    'rows_processed' => 0,
                    'updated_currencies' => [],
                    'errors' => [
                        $this->makeReportEntry(null, $exception->getMessage()),
                    ],
                    'warnings' => [],
                ],
            ], Response::HTTP_UNPROCESSABLE_ENTITY);
        }

        $rows = $parseResult['rows'];
        $errors = $parseResult['errors'];
        $warnings = $parseResult['warnings'];
        $totalRows = $parseResult['total_rows'];

        $governorates = Governorate::query()
            ->select(['id', 'code'])
            ->get()
            ->keyBy(fn (Governorate $governorate) => Str::upper((string) $governorate->code));

        $groupedByCurrency = collect($rows)->groupBy('currency_name');

        $processingErrors = [];
        $processingWarnings = [];
        $updatedCurrencies = [];

        foreach ($groupedByCurrency as $currencyName => $items) {
            $currency = CurrencyRate::where('currency_name', $currencyName)->first();

            if (!$currency) {
                $entry = $this->makeReportEntry(null, __('Currency ":currency" does not exist.', ['currency' => $currencyName]), $currencyName);
                $processingErrors[] = $entry;
                Log::warning('Currency rate import missing currency', $entry);
                continue;
            }

            $preparedRows = [];

            foreach ($items as $item) {
                $code = $item['governorate_code'];
                $governorate = $governorates->get($code);

                if (!$governorate) {
                    $entry = $this->makeReportEntry($item['row_number'], __('Governorate code ":code" is not recognised.', ['code' => $code]), $currencyName);
                    $processingErrors[] = $entry;
                    Log::warning('Currency rate import governorate mismatch', $entry);
                    continue;
                }

                $preparedRows[] = [
                    'governorate_id' => $governorate->id,
                    'governorate_code' => $code,
                    'sell_price' => $item['sell_price'],
                    'buy_price' => $item['buy_price'],
                    'source' => $item['source'],
                    'quoted_at' => $item['quoted_at'],
                    'is_default' => $item['is_default'],
                    'row_number' => $item['row_number'],
                ];
            }

            if (empty($preparedRows)) {
                $entry = $this->makeReportEntry(null, __('No valid governorate rates were provided for ":currency".', ['currency' => $currencyName]), $currencyName);
                $processingErrors[] = $entry;
                Log::warning('Currency rate import empty rows', $entry);
                continue;
            }

            $deduplicated = [];

            foreach ($preparedRows as $row) {
                $key = $row['governorate_id'];

                if (isset($deduplicated[$key])) {
                    $entry = $this->makeReportEntry($row['row_number'], __('Duplicate governorate entry detected. Keeping the latest value.'), $currencyName, 'warning');
                    $processingWarnings[] = $entry;
                    Log::notice('Currency rate import duplicate governorate', $entry);
                }

                $deduplicated[$key] = $row;
            }

            $preparedRows = array_values($deduplicated);

            $defaultRows = array_values(array_filter($preparedRows, fn ($row) => $row['is_default'] === true));

            if (count($defaultRows) === 0) {
                $preparedRows[0]['is_default'] = true;
                $entry = $this->makeReportEntry($preparedRows[0]['row_number'], __('No default governorate provided. Marked :code as default automatically.', ['code' => $preparedRows[0]['governorate_code']]), $currencyName, 'warning');
                $processingWarnings[] = $entry;
                Log::notice('Currency rate import assigned default', $entry);
            } elseif (count($defaultRows) > 1) {
                $selectedDefaultId = $defaultRows[0]['governorate_id'];

                foreach ($preparedRows as &$row) {
                    $row['is_default'] = $row['governorate_id'] === $selectedDefaultId;
                }

                unset($row);

                $entry = $this->makeReportEntry($defaultRows[0]['row_number'], __('Multiple defaults detected. Using :code as default.', ['code' => $defaultRows[0]['governorate_code']]), $currencyName, 'warning');
                $processingWarnings[] = $entry;
                Log::notice('Currency rate import resolved multiple defaults', $entry);
            }

            $defaultGovernorateId = null;

            foreach ($preparedRows as $row) {
                if ($row['is_default']) {
                    $defaultGovernorateId = $row['governorate_id'];
                    break;
                }
            }

            if (!$defaultGovernorateId) {
                $entry = $this->makeReportEntry(null, __('Unable to determine the default governorate for ":currency".', ['currency' => $currencyName]), $currencyName);
                $processingErrors[] = $entry;
                Log::error('Currency rate import missing default', $entry);
                continue;
            }

            try {
                DB::transaction(function () use ($currency, $preparedRows, $defaultGovernorateId) {
                    $payload = array_map(static function (array $row) {
                        return [
                            'governorate_id' => $row['governorate_id'],
                            'sell_price' => $row['sell_price'],
                            'buy_price' => $row['buy_price'],
                            'source' => $row['source'],
                            'quoted_at' => $row['quoted_at'],
                        ];
                    }, $preparedRows);

                    $this->persistCurrencyQuotes($currency, $payload, $defaultGovernorateId);
                });

                $updatedCurrencies[] = [
                    'currency_name' => $currencyName,
                    'quotes_updated' => count($preparedRows),
                ];
            } catch (Throwable $exception) {
                $entry = $this->makeReportEntry(null, __('Failed to update ":currency": :message', ['currency' => $currencyName, 'message' => $exception->getMessage()]), $currencyName);
                $processingErrors[] = $entry;
                Log::error('Currency rate import transaction failed', array_merge($entry, ['exception' => $exception]));
            }
        }

        $allErrors = array_values(array_merge($errors, $processingErrors));
        $allWarnings = array_values(array_merge($warnings, $processingWarnings));
        $updatedCount = count($updatedCurrencies);

        $status = $updatedCount > 0 ? Response::HTTP_OK : Response::HTTP_UNPROCESSABLE_ENTITY;
        $message = $this->buildImportMessage($updatedCount, count($allErrors), count($allWarnings));

        return response()->json([
            'success' => $updatedCount > 0,
            'message' => $message,
            'report' => [
                'rows_processed' => $totalRows,
                'updated_currencies' => $updatedCurrencies,
                'errors' => $allErrors,
                'warnings' => $allWarnings,
            ],
        ], $status);
    }





    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'currency_name' => 'required|string|max:255|unique:currency_rates',

            'icon' => 'nullable|image|mimes:jpg,jpeg,png,webp,svg|max:2048',
            'icon_alt' => 'nullable|string|max:255',
            'quotes' => 'required|array',
            'quotes.*.governorate_id' => 'required|exists:governorates,id',
            'quotes.*.sell_price' => 'nullable|numeric|min:0',
            'quotes.*.buy_price' => 'nullable|numeric|min:0',
            'quotes.*.source' => 'nullable|string|max:255',
            'quotes.*.quoted_at' => 'nullable|date',
            'default_governorate_id' => 'required|exists:governorates,id',

        
        ]);

        if ($validator->fails()) {
            if ($request->expectsJson()) {
                return response()->json(['errors' => $validator->errors()], Response::HTTP_UNPROCESSABLE_ENTITY);
            }

            return redirect()
                ->back()
                ->withErrors($validator)
                ->withInput();
            
            }

        $iconData = $this->extractIconData($request);
        $quotesPayload = $this->normalizeQuotes($request->input('quotes', []));
        $defaultGovernorateId = (int) $request->input('default_governorate_id');

        $currency = DB::transaction(function () use ($request, $iconData, $quotesPayload, $defaultGovernorateId) {
            $data = [
                'currency_name' => $request->currency_name,
                'icon_alt' => $request->filled('icon_alt') ? $request->icon_alt : null,
                'last_updated_at' => now(),
            ] + $iconData;

            $currency = CurrencyRate::create($data);

            $this->persistCurrencyQuotes($currency, $quotesPayload, $defaultGovernorateId);

            return $currency->fresh(['quotes.governorate']);
        });
        CurrencyCreated::dispatch($currency->id, $defaultGovernorateId);

        $message = __('Currency rate created successfully');

        if ($request->expectsJson()) {
            return response()->json([
                'success' => true,
                'message' => $message,
                'data' => $currency,
            ]);
        }

        return redirect()
            ->route('currency.index')
            ->with('success', $message);

    }



    public function update(Request $request, $id)
    {
        $currency = CurrencyRate::with('quotes')->findOrFail($id);


        $validator = Validator::make($request->all(), [
            'currency_name' => 'required|string|max:255|unique:currency_rates,currency_name,' . $id,
            'icon' => 'nullable|image|mimes:jpg,jpeg,png,webp,svg|max:2048',
            'icon_alt' => 'nullable|string|max:255',
            'remove_icon' => 'sometimes|boolean',
            'quotes' => 'required|array',
            'quotes.*.governorate_id' => 'required|exists:governorates,id',
            'quotes.*.sell_price' => 'nullable|numeric|min:0',
            'quotes.*.buy_price' => 'nullable|numeric|min:0',
            'quotes.*.source' => 'nullable|string|max:255',
            'quotes.*.quoted_at' => 'nullable|date',
            'default_governorate_id' => 'required|exists:governorates,id',
        
        ]);

        if ($validator->fails()) {
            if ($request->expectsJson()) {
                return response()->json(['errors' => $validator->errors()], Response::HTTP_UNPROCESSABLE_ENTITY);
            }

            return redirect()
                ->back()
                ->withErrors($validator)
                ->withInput();

        }

        $iconData = $this->extractIconData($request, $currency);
        $quotesPayload = $this->normalizeQuotes($request->input('quotes', []));
        $defaultGovernorateId = (int) $request->input('default_governorate_id');

        $currency = DB::transaction(function () use ($currency, $request, $iconData, $quotesPayload, $defaultGovernorateId) {
            $payload = [
                'currency_name' => $request->currency_name,
                'icon_alt' => $request->filled('icon_alt') ? $request->icon_alt : null,
            ] + $iconData;

            if ($request->boolean('remove_icon')) {
                if ($currency->icon_path) {
                    $this->iconStorageService->deleteIcon($currency->icon_path);
                }


                $payload['icon_path'] = null;
                $payload['icon_alt'] = null;
                $payload['icon_uploaded_by'] = null;
                $payload['icon_uploaded_at'] = null;
                $payload['icon_removed_by'] = Auth::id();
                $payload['icon_removed_at'] = now();
            }

            $currency->update($payload);



            $this->persistCurrencyQuotes($currency, $quotesPayload, $defaultGovernorateId);
            return $currency->fresh(['quotes.governorate']);
        });



        CurrencyRatesUpdated::dispatch(
            $currency->id,
            $currency->quotes
                ->map(static function (CurrencyRateQuote $quote): array {
                    return [
                        'governorate_id' => $quote->governorate_id,
                        'governorate_code' => $quote->governorate?->code,
                        'governorate_name' => $quote->governorate?->name,
                        'sell_price' => $quote->sell_price,
                        'buy_price' => $quote->buy_price,
                        'is_default' => (bool) $quote->is_default,
                    ];
                })
                ->values()
                ->all()
        );

        $message = __('Currency rate updated successfully');

        if ($request->expectsJson()) {
            return response()->json([
                'success' => true,
                'message' => $message,
                'data' => $currency,
            ]);
        }

        return redirect()
            ->route('currency.index')
            ->with('success', $message);




    }

    public function destroy($id)
    {
        $currency = CurrencyRate::findOrFail($id);
        $this->iconStorageService->deleteIcon($currency->icon_path);


        $currency->delete();

        return response()->json([
            'success' => true,
            'message' => 'Currency rate deleted successfully',

        ]);
    }


    public function destroyIcon($id)
    {
        $currency = CurrencyRate::findOrFail($id);

        if (!$currency->icon_path) {
            return response()->json([
                'success' => true,
                'message' => 'Currency icon already removed',
                'data' => $currency->fresh(),
            ]);
        }

        $this->iconStorageService->deleteIcon($currency->icon_path);

        $currency->update([
            'icon_path' => null,
            'icon_alt' => null,
            'icon_uploaded_by' => null,
            'icon_uploaded_at' => null,
            'icon_removed_by' => Auth::id(),
            'icon_removed_at' => now(),
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Currency icon removed successfully',
            'data' => $currency->fresh(),
        ]);
    }



    public function show()
    {
        $offset = request('offset', 0);
        $limit = request('limit', 10);
        $search = request('search', '');
        $sort = request('sort', 'id');
        $order = request('order', 'desc');

        $query = CurrencyRate::with(['quotes.governorate'])
            ->when($search, function ($q) use ($search) {
                $q->where(function ($inner) use ($search) {
                    $inner->where('currency_name', 'like', '%' . $search . '%')
                        ->orWhereHas('quotes', function ($quoteQuery) use ($search) {
                            $quoteQuery->where('sell_price', 'like', '%' . $search . '%')
                                ->orWhere('buy_price', 'like', '%' . $search . '%');
                        });
                });
            });


        $total = $query->count();
        $historyService = $this->historyService;
        $monitor = $this->currencyDataMonitor;

        $currencies = $query->orderBy($sort, $order)
            ->offset($offset)
            ->limit($limit)
            ->get()
            ->map(function (CurrencyRate $currency) use ($historyService, $monitor) {

                [$defaultQuote] = $currency->resolveQuoteForGovernorate(null);

                if (!$defaultQuote) {
                    $defaultQuote = $currency->quotes->first();
                }

                $defaultGovernorateId = $defaultQuote?->governorate_id;


                $latestHourly = $currency->hourlyHistories()
                    ->when($defaultGovernorateId, fn ($query) => $query->where('governorate_id', $defaultGovernorateId))
                    ->latest('hour_start')
                    ->first();

                $latestDaily = $currency->dailyHistories()
                    ->when($defaultGovernorateId, fn ($query) => $query->where('governorate_id', $defaultGovernorateId))
                    ->latest('day_start')
                    ->first();

                $capturedAt = $latestHourly?->captured_at ?? $latestHourly?->hour_start;
                $sourceQuality = $historyService->determineSourceQuality($capturedAt);
                $monitor->inspectCurrency($currency, $capturedAt, $sourceQuality);


                return [
                    'id' => $currency->id,
                    'currency_name' => $currency->currency_name,
                    'sell_price' => $defaultQuote?->sell_price,
                    'buy_price' => $defaultQuote?->buy_price,
                    'icon_url' => $currency->icon_url,
                    'icon_alt' => $currency->icon_alt,
                    'last_updated_at' => optional($defaultQuote?->quoted_at ?? $currency->last_updated_at)->toIso8601String(),
                    'quotes' => $currency->quotes->map(fn (CurrencyRateQuote $quote) => [
                        'id' => $quote->id,
                        'governorate_id' => $quote->governorate_id,
                        'governorate_code' => $quote->governorate?->code,
                        'governorate_name' => $quote->governorate?->name,
                        'sell_price' => $quote->sell_price,
                        'buy_price' => $quote->buy_price,
                        'source' => $quote->source,
                        'quoted_at' => optional($quote->quoted_at)->toIso8601String(),
                        'is_default' => $quote->is_default,
                    ])->values(),

                    'history' => [
                        'last_hourly_at' => optional($latestHourly?->hour_start)->toIso8601String(),
                        'last_daily_at' => optional($latestDaily?->day_start)->toDateString(),
                        'last_captured_at' => optional($capturedAt)->toIso8601String(),
                        'source_quality' => $sourceQuality,
                        'source' => $latestHourly?->source,
                        'daily_change_sell_percent' => $latestDaily?->change_sell_percent,
                        'daily_change_buy_percent' => $latestDaily?->change_buy_percent,
                        'range_hint' => 7,
                    ],

                ];
            });

        return response()->json([
            'total' => $total,
            'rows' => $currencies,

        ]);
    }



    public function changeLogs(Request $request)
    {
        ResponseService::noAnyPermissionThenSendJson(['currency-rate-list']);

        $perPage = (int) max(1, min((int) $request->integer('per_page', 15), 100));

        $logs = CurrencyRateChangeLog::query()
            ->with([
                'currencyRate:id,currency_name',
                'governorate:id,name,code',
                'user:id,name,email',
            ])
            ->when($request->filled('currency_rate_id'), fn ($query) => $query->where('currency_rate_id', $request->integer('currency_rate_id')))
            ->when($request->filled('governorate_id'), fn ($query) => $query->where('governorate_id', $request->integer('governorate_id')))
            ->when($request->filled('change_type'), fn ($query) => $query->where('change_type', $request->input('change_type')))
            ->orderByDesc('changed_at')
            ->paginate($perPage);

        return response()->json($logs);
    }



    public function backfillHistory(Request $request, CurrencyRate $currency): \Illuminate\Http\JsonResponse
    {
        ResponseService::noAnyPermissionThenSendJson(['currency-rate-edit']);

        $validator = Validator::make($request->all(), [
            'range_days' => 'required|integer|min:1|max:365',
            'governorate_id' => 'nullable|integer|exists:governorates,id',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => $validator->errors()->first(),
            ], 422);
        }

        $rangeDays = (int) $request->integer('range_days');
        $governorateId = $request->input('governorate_id');

        $end = now();
        $start = (clone $end)->subDays($rangeDays - 1)->startOfDay();

        BackfillCurrencyRateHistory::dispatchSync($start, $end, $currency->id, $governorateId ? (int) $governorateId : null);

        return response()->json([
            'success' => true,
            'message' => __('History backfill has been queued successfully.'),
        ]);
    }




    private function parseImportFile(UploadedFile $file): array
    {
        $extension = Str::lower($file->getClientOriginalExtension() ?: $file->extension());

        return match ($extension) {
            'csv', 'txt' => $this->parseImportCsv($file),
            'xlsx', 'xls' => $this->parseImportSpreadsheet($file),
            default => throw new RuntimeException(__('Unsupported file type: :type', ['type' => $extension ?: __('unknown')])),
        };
    }

    private function parseImportCsv(UploadedFile $file): array
    {
        $handle = fopen($file->getRealPath(), 'rb');

        if ($handle === false) {
            throw new RuntimeException(__('Unable to open the uploaded file.'));
        }

        $header = null;
        $rows = [];
        $errors = [];
        $warnings = [];
        $lineNumber = 0;
        $dataRowCount = 0;

        while (($data = fgetcsv($handle)) !== false) {
            $lineNumber++;

            if ($header === null) {
                if ($this->isImportRowEmpty($data)) {
                    continue;
                }

                $header = $this->normaliseImportHeader($data);
                $this->assertImportColumns($header);
                continue;
            }

            if ($this->isImportRowEmpty($data)) {
                continue;
            }

            $dataRowCount++;

            $result = $this->mapImportRow($header, $data, $lineNumber);

            if (isset($result['error'])) {
                $errors[] = $result['error'];
                Log::warning('Currency rate import row error', $result['error']);
                continue;
            }

            foreach ($result['warnings'] as $warning) {
                $warnings[] = $warning;
                Log::notice('Currency rate import row warning', $warning);
            }

            $rows[] = $result['row'];
        }

        fclose($handle);

        if ($header === null) {
            throw new RuntimeException(__('The uploaded file does not contain a valid header row.'));
        }

        return [
            'rows' => $rows,
            'errors' => $errors,
            'warnings' => $warnings,
            'total_rows' => $dataRowCount,
        ];
    }

    private function parseImportSpreadsheet(UploadedFile $file): array
    {
        if (!class_exists('\\PhpOffice\\PhpSpreadsheet\\IOFactory')) {
            throw new RuntimeException(__('XLSX imports require the phpoffice/phpspreadsheet package.'));
        }

        $spreadsheet = \PhpOffice\PhpSpreadsheet\IOFactory::load($file->getRealPath());
        $worksheet = $spreadsheet->getActiveSheet();

        $header = null;
        $rows = [];
        $errors = [];
        $warnings = [];
        $lineNumber = 0;
        $dataRowCount = 0;

        foreach ($worksheet->toArray(null, true, true, false) as $row) {
            $lineNumber++;

            if ($header === null) {
                if ($this->isImportRowEmpty($row)) {
                    continue;
                }

                $header = $this->normaliseImportHeader($row);
                $this->assertImportColumns($header);
                continue;
            }

            if ($this->isImportRowEmpty($row)) {
                continue;
            }

            $dataRowCount++;

            $result = $this->mapImportRow($header, $row, $lineNumber);

            if (isset($result['error'])) {
                $errors[] = $result['error'];
                Log::warning('Currency rate import row error', $result['error']);
                continue;
            }

            foreach ($result['warnings'] as $warning) {
                $warnings[] = $warning;
                Log::notice('Currency rate import row warning', $warning);
            }

            $rows[] = $result['row'];
        }

        if ($header === null) {
            throw new RuntimeException(__('The uploaded file does not contain a valid header row.'));
        }

        return [
            'rows' => $rows,
            'errors' => $errors,
            'warnings' => $warnings,
            'total_rows' => $dataRowCount,
        ];
    }

    private function normaliseImportHeader(array $columns): array
    {
        $normalised = [];

        foreach ($columns as $column) {
            $key = Str::of((string) $column)
                ->trim()
                ->lower()
                ->snake()
                ->value();

            $normalised[] = match ($key) {
                'currency', 'currency_name', 'name' => 'currency_name',
                'governorate', 'governorate_code', 'gov', 'gov_code', 'governorateid', 'governorate_id' => 'governorate_code',
                'sell', 'sell_price', 'sell_rate' => 'sell_price',
                'buy', 'buy_price', 'buy_rate' => 'buy_price',
                'source', 'origin', 'provider' => 'source',
                'quoted_at', 'quoted', 'quoted_at_utc', 'timestamp', 'last_updated_at' => 'quoted_at',
                'default', 'is_default', 'default_flag', 'default_governorate' => 'is_default',
                default => 'meta',
            };
        }

        return $normalised;
    }

    private function assertImportColumns(array $header): void
    {
        $required = ['currency_name', 'governorate_code', 'sell_price', 'buy_price'];
        $unique = array_unique($header);
        $missing = array_diff($required, $unique);

        if (!empty($missing)) {
            $readable = array_map(static fn ($column) => Str::headline($column), $missing);

            throw new RuntimeException(__('The uploaded file must include the following columns: :columns', [
                'columns' => implode(', ', $readable),
            ]));
        }
    }

    private function mapImportRow(array $header, array $data, int $rowNumber): array
    {
        $mapped = [
            'currency_name' => null,
            'governorate_code' => null,
            'sell_price' => null,
            'buy_price' => null,
            'source' => null,
            'quoted_at' => null,
            'is_default' => false,
        ];

        foreach ($header as $index => $column) {
            if (!array_key_exists($index, $data) || $column === 'meta') {
                continue;
            }

            $mapped[$column] = $data[$index];
        }

        $currencyName = $this->normalizeString($mapped['currency_name']);

        if (!$currencyName) {
            return [
                'warnings' => [],
                'error' => $this->makeReportEntry($rowNumber, __('Currency name is required.')),
            ];
        }

        $governorateCode = $this->normalizeString($mapped['governorate_code']);

        if (!$governorateCode) {
            return [
                'warnings' => [],
                'error' => $this->makeReportEntry($rowNumber, __('Governorate code is required.'), $currencyName),
            ];
        }

        $governorateCode = Str::upper($governorateCode);

        $sell = $this->normalizeNumeric($mapped['sell_price']);

        if ($sell === null) {
            return [
                'warnings' => [],
                'error' => $this->makeReportEntry($rowNumber, __('Sell price is required.'), $currencyName),
            ];
        }

        $buy = $this->normalizeNumeric($mapped['buy_price']);

        if ($buy === null) {
            return [
                'warnings' => [],
                'error' => $this->makeReportEntry($rowNumber, __('Buy price is required.'), $currencyName),
            ];
        }

        $warnings = [];
        $source = $this->normalizeString($mapped['source']);
        $quotedAt = null;
        $rawQuotedAt = $mapped['quoted_at'];

        if ($rawQuotedAt !== null && $rawQuotedAt !== '') {
            try {
                $quotedAt = Carbon::parse($rawQuotedAt)->toDateTimeString();
            } catch (Throwable $exception) {
                $warning = $this->makeReportEntry($rowNumber, __('Invalid quoted at value. Current time will be used.'), $currencyName, 'warning');
                $warnings[] = $warning;
                Log::notice('Currency rate import invalid quoted_at', array_merge($warning, ['exception' => $exception->getMessage()]));
                $quotedAt = null;
            }
        }

        $isDefault = $this->interpretBoolean($mapped['is_default']);

        return [
            'row' => [
                'currency_name' => $currencyName,
                'governorate_code' => $governorateCode,
                'sell_price' => $sell,
                'buy_price' => $buy,
                'source' => $source,
                'quoted_at' => $quotedAt,
                'is_default' => $isDefault,
                'row_number' => $rowNumber,
            ],
            'warnings' => $warnings,
        ];
    }

    private function isImportRowEmpty(array $row): bool
    {
        foreach ($row as $cell) {
            if ($cell === null) {
                continue;
            }

            if (is_string($cell) && trim($cell) === '') {
                continue;
            }

            if (!is_string($cell) && $cell !== '') {
                return false;
            }

            if (is_string($cell) && trim($cell) !== '') {
                return false;
            }
        }

        return true;
    }

    private function interpretBoolean(mixed $value): bool
    {
        if ($value === null) {
            return false;
        }

        if (is_bool($value)) {
            return $value;
        }

        $normalised = Str::of((string) $value)->trim()->lower()->value();

        return in_array($normalised, ['1', 'true', 'yes', 'y', 'default', 'primary'], true);
    }

    private function makeReportEntry(?int $rowNumber, string $message, ?string $currencyName = null, string $level = 'error'): array
    {
        $entry = [
            'message' => $message,
            'level' => $level,
        ];

        if ($rowNumber !== null) {
            $entry['row_number'] = $rowNumber;
        }

        if ($currencyName !== null) {
            $entry['currency_name'] = $currencyName;
        }

        return $entry;
    }

    private function buildImportMessage(int $updatedCount, int $errorCount, int $warningCount): string
    {
        if ($updatedCount === 0) {
            return __('No currency rates were updated. Please review the reported issues.');
        }

        if ($errorCount > 0) {
            return __('Imported :count currencies with :errors errors.', [
                'count' => $updatedCount,
                'errors' => $errorCount,
            ]);
        }

        if ($warningCount > 0) {
            return __('Imported :count currencies with :warnings warnings.', [
                'count' => $updatedCount,
                'warnings' => $warningCount,
            ]);
        }

        return __('Imported :count currencies successfully.', ['count' => $updatedCount]);
    }




    private function extractIconData(Request $request, ?CurrencyRate $currency = null): array
    {
        $data = [];

        if ($request->hasFile('icon')) {
            $path = $this->iconStorageService->storeIcon($request->file('icon'), $currency?->icon_path);
            $data['icon_path'] = $path;
            $data['icon_uploaded_by'] = Auth::id();
            $data['icon_uploaded_at'] = now();
            $data['icon_removed_by'] = null;
            $data['icon_removed_at'] = null;
        }

        return $data;
    }

    private function normalizeQuotes(array $quotes): array
    {
        $normalized = [];

        foreach ($quotes as $key => $quote) {
            $governorateId = (int) Arr::get($quote, 'governorate_id', $key);
            $sellRaw = Arr::get($quote, 'sell_price');
            $buyRaw = Arr::get($quote, 'buy_price');

            $normalized[] = [
                'governorate_id' => $governorateId,
                'sell_price' => $this->normalizeNumeric($sellRaw),
                'buy_price' => $this->normalizeNumeric($buyRaw),
                'source' => $this->normalizeString(Arr::get($quote, 'source')),
                'quoted_at' => Arr::get($quote, 'quoted_at'),
            ];
        }

        return $normalized;
    }

    private function normalizeNumeric($value): ?float
    {
        if ($value === null || $value === '') {
            return null;
        }

        if (is_string($value)) {
            $value = str_replace(',', '', $value);
        }

        return (float) $value;
    }

    private function normalizeString($value): ?string
    {
        if ($value === null) {
            return null;
        }

        $trimmed = trim((string) $value);

        return $trimmed === '' ? null : $trimmed;
    }


    private function formatQuoteLogValues(?CurrencyRateQuote $quote): ?array
    {
        if (!$quote) {
            return null;
        }

        return [
            'sell_price' => $quote->sell_price !== null ? (string) $quote->sell_price : null,
            'buy_price' => $quote->buy_price !== null ? (string) $quote->buy_price : null,
            'source' => $quote->source,
            'quoted_at' => $this->formatQuoteTimestamp($quote->quoted_at),
            'is_default' => (bool) $quote->is_default,
        ];
    }

    private function formatQuoteTimestamp($value): ?string
    {
        if ($value === null) {
            return null;
        }

        if ($value instanceof DateTimeInterface) {
            return Carbon::instance($value)->toIso8601String();
        }

        return Carbon::parse($value)->toIso8601String();
    }

    private function snapshotsAreDifferent(?array $before, ?array $after): bool
    {
        return $before !== $after;
    }


    private function persistCurrencyQuotes(CurrencyRate $currency, array $quotesPayload, int $defaultGovernorateId): void
    {
        $quotes = collect($quotesPayload)
            ->filter(fn ($quote) => $quote['sell_price'] !== null && $quote['buy_price'] !== null)
            ->map(function ($quote) {
                $quotedAt = $quote['quoted_at'];

                return [
                    'governorate_id' => $quote['governorate_id'],
                    'sell_price' => $quote['sell_price'],
                    'buy_price' => $quote['buy_price'],
                    'source' => $quote['source'],
                    'quoted_at' => $quotedAt ? Carbon::parse($quotedAt) : now(),
                ];
            });

        if ($quotes->isEmpty()) {
            throw ValidationException::withMessages([
                'quotes' => __('Please provide at least one governorate rate with both buy and sell prices.'),
            ]);
        }

        if (!$quotes->contains('governorate_id', $defaultGovernorateId)) {
            throw ValidationException::withMessages([
                'default_governorate_id' => __('Default governorate must have both buy and sell prices.'),
            ]);
        }

        $existingQuotes = $currency->quotes()->get()->keyBy('governorate_id');
        $incomingGovernorateIds = $quotes->pluck('governorate_id')->map(fn ($id) => (int) $id)->all();
        $logEntries = [];
        $userId = Auth::id();
        $timestamp = now();

        $quotesToDelete = $existingQuotes->filter(
            fn (CurrencyRateQuote $quote) => !in_array((int) $quote->governorate_id, $incomingGovernorateIds, true)
        );

        if ($quotesToDelete->isNotEmpty()) {
            $currency->quotes()->whereIn('id', $quotesToDelete->pluck('id'))->delete();

            foreach ($quotesToDelete as $quote) {
                $logEntries[] = [
                    'currency_rate_id' => $currency->id,
                    'governorate_id' => $quote->governorate_id,
                    'change_type' => 'deleted',
                    'previous_values' => $this->formatQuoteLogValues($quote),
                    'new_values' => null,
                    'changed_by' => $userId,
                    'changed_at' => $timestamp,
                ];
            }

            $existingQuotes = $existingQuotes->except($quotesToDelete->keys());
        }



        $defaultQuote = null;

        foreach ($quotes as $quote) {
            $isDefault = $quote['governorate_id'] === $defaultGovernorateId;

            /** @var CurrencyRateQuote|null $existingQuote */
            $existingQuote = $existingQuotes->get($quote['governorate_id']);
            $previousSnapshot = $this->formatQuoteLogValues($existingQuote);


            $stored = $currency->quotes()->updateOrCreate(
                [
                    'governorate_id' => $quote['governorate_id'],
                ],
                [
                    'sell_price' => $quote['sell_price'],
                    'buy_price' => $quote['buy_price'],
                    'source' => $quote['source'],
                    'quoted_at' => $quote['quoted_at'],
                    'is_default' => $isDefault,
                ]
            );



            $newSnapshot = $this->formatQuoteLogValues($stored);

            if ($existingQuote) {
                if ($this->snapshotsAreDifferent($previousSnapshot, $newSnapshot)) {
                    $logEntries[] = [
                        'currency_rate_id' => $currency->id,
                        'governorate_id' => $stored->governorate_id,
                        'change_type' => 'updated',
                        'previous_values' => $previousSnapshot,
                        'new_values' => $newSnapshot,
                        'changed_by' => $userId,
                        'changed_at' => $timestamp,
                    ];
                }
            } else {
                $logEntries[] = [
                    'currency_rate_id' => $currency->id,
                    'governorate_id' => $stored->governorate_id,
                    'change_type' => 'created',
                    'previous_values' => null,
                    'new_values' => $newSnapshot,
                    'changed_by' => $userId,
                    'changed_at' => $timestamp,
                ];
            }


            if ($isDefault) {
                $defaultQuote = $stored;
            }
        }

        $currency->quotes()
            ->where('governorate_id', '!=', $defaultGovernorateId)
            ->where('is_default', true)
            ->update(['is_default' => false]);


        if (!empty($logEntries)) {
            foreach ($logEntries as $entry) {
                CurrencyRateChangeLog::create($entry);
            }
        }


        $currency->applyDefaultQuoteSnapshot($defaultQuote);
    }
}