<?php

namespace App\Http\Controllers;



use App\Jobs\BackfillCurrencyRateHistory;
use App\Services\CurrencyRateHistoryService;
use App\Services\ResponseService;
use App\Models\CurrencyRateQuote;
use App\Models\Governorate;
use App\Services\CurrencyIconStorageService;
use Carbon\Carbon;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use App\Models\CurrencyRate;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\ValidationException;

class CurrencyController extends Controller
{

    public function __construct(
        private readonly CurrencyIconStorageService $iconStorageService,
        private readonly CurrencyRateHistoryService $historyService
    )
    
    
    {
    }

    public function index()
    {
        $governorates = Governorate::orderBy('name')->get();


        return view('currency.index', compact('governorates'));

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
            return response()->json(['errors' => $validator->errors()], 422);
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

        return response()->json([
            'success' => true,
            'message' => 'Currency rate created successfully',
            'data' => $currency,

        ]);
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
            return response()->json(['errors' => $validator->errors()], 422);
        }

        $iconData = $this->extractIconData($request, $currency);
        $quotesPayload = $this->normalizeQuotes($request->input('quotes', []));
        $defaultGovernorateId = (int) $request->input('default_governorate_id');

        DB::transaction(function () use ($currency, $request, $iconData, $quotesPayload, $defaultGovernorateId) {
            $payload = [
                'currency_name' => $request->currency_name,
                'icon_alt' => $request->filled('icon_alt') ? $request->icon_alt : null,
            ] + $iconData;

            if ($request->boolean('remove_icon')) {
                $this->iconStorageService->deleteIcon($currency->icon_path);
                $payload['icon_path'] = null;
                $payload['icon_alt'] = null;
                $payload['icon_uploaded_by'] = null;
                $payload['icon_uploaded_at'] = null;
                $payload['icon_removed_by'] = Auth::id();
                $payload['icon_removed_at'] = now();
            }

            $this->persistCurrencyQuotes($currency, $quotesPayload, $defaultGovernorateId);
        });

        $currency->update($data);

        return response()->json([
            'success' => true,
            'message' => 'Currency rate updated successfully',
            'data' => $currency->fresh(['quotes.governorate']),


        ]);
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

        $currencies = $query->orderBy($sort, $order)
            ->offset($offset)
            ->limit($limit)
            ->get()
             ->map(function (CurrencyRate $currency) use ($historyService) {

                [$defaultQuote] = $currency->resolveQuoteForGovernorate(null);


                $latestHourly = $currency->hourlyHistories()
                    ->latest('hour_start')
                    ->first();

                $latestDaily = $currency->dailyHistories()
                    ->latest('day_start')
                    ->first();

                $capturedAt = $latestHourly?->captured_at ?? $latestHourly?->hour_start;
                $sourceQuality = $historyService->determineSourceQuality($capturedAt);


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

        $currency->quotes()
            ->whereNotIn('governorate_id', $quotes->pluck('governorate_id'))
            ->delete();

        $defaultQuote = null;

        foreach ($quotes as $quote) {
            $isDefault = $quote['governorate_id'] === $defaultGovernorateId;

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

            if ($isDefault) {
                $defaultQuote = $stored;
            }
        }

        $currency->quotes()
            ->where('governorate_id', '!=', $defaultGovernorateId)
            ->where('is_default', true)
            ->update(['is_default' => false]);

        $currency->applyDefaultQuoteSnapshot($defaultQuote);
    }
}