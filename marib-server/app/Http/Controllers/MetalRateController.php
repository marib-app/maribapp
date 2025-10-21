<?php

namespace App\Http\Controllers;

use App\Events\MetalRateCreated;
use App\Events\MetalRateUpdated;
use App\Http\Controllers\Concerns\ValidatesMetalRates;
use App\Models\Governorate;
use App\Models\MetalRate;
use App\Models\MetalRateUpdate;
use App\Services\MetalRateQuoteService;
use App\Services\MetalIconStorageService;
use Illuminate\Contracts\View\View;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Arr;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;


class MetalRateController extends Controller
{
    use ValidatesMetalRates;

    public function __construct(
        private readonly MetalIconStorageService $iconStorageService,
        private readonly MetalRateQuoteService $metalRateQuoteService
    )
    
    {
    }

    public function index(): View
    {
        MetalRateUpdate::applyDueUpdates();



        return view('metal_rates.index', [
            'metalRateCount' => MetalRate::count(),

        ]);
    }


    public function create(): View
    {
        return view('metal_rates.create', [
            'governorates' => Governorate::query()->orderBy('name')->get(),
            'defaultGovernorateId' => $this->metalRateQuoteService->resolveDefaultGovernorateId(),            
            'governorateStoreUrl' => route('governorates.store'),
        ]);
    
    }


    public function store(Request $request): RedirectResponse
    {
        $validated = $this->validateMetalRatePayload($request);

        $metalAttributes = Arr::only($validated['metal'], ['metal_type', 'karat']);


        $iconPayload = $this->resolveMetalIconPayload($request, $this->iconStorageService);

        /** @var MetalRate $metal */
        $metal = MetalRate::create(array_merge($metalAttributes, $iconPayload));


        $this->metalRateQuoteService->syncQuotes(
            $metal,
            $validated['quotes'],
            $validated['default_governorate_id'],
            Auth::id()
        );


        MetalRateCreated::dispatch(
            $metal->getKey(),
            $this->resolveQuoteEventPayload($metal),
            (int) $validated['default_governorate_id']
        );


        return redirect()
            ->route('metal-rates.index')
            ->with('success', __('تم إضافة سعر المعدن بنجاح.'));
    }


    public function edit(MetalRate $metalRate): View
    {
        MetalRateUpdate::applyDueUpdates();

        $metalRate->load([
            'quotes' => fn ($query) => $query->with('governorate')->orderBy('governorate_id'),
            'pendingUpdates' => fn ($query) => $query->orderBy('scheduled_for'),
        ]);

        $governorates = Governorate::query()->orderBy('name')->get();

        $quotes = $metalRate->quotes
            ->mapWithKeys(static function ($quote) {
                return [
                    $quote->governorate_id => [
                        'governorate_id' => $quote->governorate_id,
                        'sell_price' => $quote->sell_price,
                        'buy_price' => $quote->buy_price,
                        'source' => $quote->source,
                        'quoted_at' => optional($quote->quoted_at)?->toDateTimeString(),
                        'is_default' => (bool) $quote->is_default,
                    ],
                ];
            })
            ->toArray();

        $defaultGovernorateId = $metalRate->quotes->firstWhere('is_default', true)?->governorate_id
            ?? $this->metalRateQuoteService->resolveDefaultGovernorateId();

        return view('metal_rates.edit', [
            'metalRate' => $metalRate,
            'governorates' => $governorates,
            'quotes' => $quotes,
            'defaultGovernorateId' => $defaultGovernorateId,
            'governorateStoreUrl' => route('governorates.store'),
        ]);
    }


    public function update(Request $request, MetalRate $metalRate): RedirectResponse
    {
        $validated = $this->validateMetalRatePayload($request, $metalRate);

        $metalAttributes = Arr::only($validated['metal'], ['metal_type', 'karat']);



        $iconPayload = $this->resolveMetalIconPayload($request, $this->iconStorageService, $metalRate);

        $metalRate->update(array_merge($metalAttributes, $iconPayload));



        $this->metalRateQuoteService->syncQuotes(
            $metalRate,
            $validated['quotes'],
            $validated['default_governorate_id'],
            Auth::id()
        );

        MetalRateUpdated::dispatch(
            $metalRate->getKey(),
            $this->resolveQuoteEventPayload($metalRate),
            (int) $validated['default_governorate_id']
        );


        
        return redirect()
            ->route('metal-rates.edit', $metalRate)
            ->with('success', __('تم تحديث سعر المعدن بنجاح.'));
    }

    public function destroy(Request $request, MetalRate $metalRate)
    {
        $metalRate->delete();

        if ($request->expectsJson() || $request->ajax()) {
            return response()->json([
                'success' => true,
                'message' => __('تم حذف سعر المعدن بنجاح.'),
            ]);
        }


        return redirect()
            ->route('metal-rates.index')
            ->with('success', __('تم حذف سعر المعدن بنجاح.'));
    }

    public function schedule(Request $request, MetalRate $metalRate): RedirectResponse
    {
        $payload = $this->validateMetalRateSchedule($request);

        $metalRate->pendingUpdates()->create($payload + [
            'created_by' => Auth::id(),
        ]);

        return redirect()
            ->route('metal-rates.edit', $metalRate)
            ->with('success', __('تمت جدولة التحديث بنجاح.'));
    }

    public function cancelSchedule(MetalRateUpdate $metalRateUpdate): RedirectResponse
    {
        $metalRateUpdate->cancel();

        return redirect()
            ->route('metal-rates.edit', $metalRateUpdate->metalRate)
            ->with('success', __('تم إلغاء الجدولة بنجاح.'));
    }


    /**
     * @return array<int, array{
     *     governorate_id: int,
     *     governorate_code: string|null,
     *     governorate_name: string|null,
     *     sell_price: string|null,
     *     buy_price: string|null,
     *     is_default: bool
     * }>
     */
    private function resolveQuoteEventPayload(MetalRate $metalRate): array
    {
        return $metalRate->quotes()
            ->with('governorate:id,code,name')
            ->get()
            ->map(static function ($quote): array {
                $governorate = $quote->relationLoaded('governorate')
                    ? $quote->governorate
                    : $quote->governorate()->first();

                return [
                    'governorate_id' => (int) $quote->governorate_id,
                    'governorate_code' => $governorate?->code
                        ? Str::upper((string) $governorate->code)
                        : null,
                    'governorate_name' => $governorate?->name,
                    'sell_price' => $quote->sell_price !== null
                        ? (string) $quote->sell_price
                        : null,
                    'buy_price' => $quote->buy_price !== null
                        ? (string) $quote->buy_price
                        : null,
                    'is_default' => (bool) $quote->is_default,
                ];
            })
            ->values()
            ->all();
    }


    
    public function show(Request $request): JsonResponse
    {
        MetalRateUpdate::applyDueUpdates();

        $offset = (int) $request->get('offset', 0);
        $limit = (int) $request->get('limit', 10);
        $search = trim((string) $request->get('search', ''));
        $sort = $request->get('sort', 'id');
        $order = strtolower((string) $request->get('order', 'desc')) === 'asc' ? 'asc' : 'desc';

        $query = MetalRate::query()->with(['quotes.governorate', 'pendingUpdates']);

        if ($search !== '') {
            $query->where(function ($inner) use ($search) {
                $inner->where('metal_type', 'like', '%' . $search . '%')
                    ->orWhere('karat', 'like', '%' . $search . '%')
                    ->orWhere('id', $search)
                    ->orWhereHas('quotes', function ($quoteQuery) use ($search) {
                        $quoteQuery->where('sell_price', 'like', '%' . $search . '%')
                            ->orWhere('buy_price', 'like', '%' . $search . '%');
                    });
            });
        }

        $total = $query->count();

        $query->when($sort === 'id', fn ($q) => $q->orderBy('id', $order))
            ->when($sort === 'sell_price', fn ($q) => $q->orderBy('sell_price', $order))
            ->when($sort === 'buy_price', fn ($q) => $q->orderBy('buy_price', $order))
            ->when($sort === 'last_updated_at', fn ($q) => $q->orderBy('quoted_at', $order))
            ->when($sort === 'display_name', function ($q) use ($order) {
                $q->orderBy('metal_type', $order)->orderBy('karat', $order);
            });

        $metals = $query
            ->offset($offset)
            ->limit($limit)
            ->get()
            ->map(function (MetalRate $metal) {
                [$defaultQuote] = $metal->resolveQuoteForGovernorate(null);

                if (!$defaultQuote) {
                    $defaultQuote = $metal->quotes->first();
                }

                $lastUpdatedAt = $defaultQuote?->quoted_at ?? $metal->quoted_at;

                $iconUrl = $metal->icon_path ? Storage::url($metal->icon_path) : null;

                return [
                    'id' => $metal->id,
                    'display_name' => $metal->display_name,
                    'metal_type' => $metal->metal_type,
                    'karat' => $metal->karat,
                    'sell_price' => $defaultQuote?->sell_price ?? $metal->sell_price,
                    'buy_price' => $defaultQuote?->buy_price ?? $metal->buy_price,
                    'icon_url' => $iconUrl,
                    'icon_alt' => $metal->icon_alt,
                    'last_updated_at' => optional($lastUpdatedAt)?->toIso8601String(),
                    'history' => [
                        'last_hourly_at' => null,
                        'last_daily_at' => null,
                        'last_captured_at' => optional($lastUpdatedAt)?->toIso8601String(),
                        'source_quality' => $this->determineQuoteQuality($lastUpdatedAt),
                        'source' => $defaultQuote?->source ?? $metal->source,
                        'range_hint' => $metal->pendingUpdates->isNotEmpty() ? 1 : 7,
                    ],
                ];
            });

        return response()->json([
            'total' => $total,
            'rows' => $metals,
        ]);
    }

    private function determineQuoteQuality(?Carbon $timestamp): string
    {
        if (!$timestamp) {
            return 'unknown';
        }

        $diffInHours = $timestamp->diffInHours(now());

        if ($diffInHours <= 6) {
            return 'fresh';
        }

        if ($diffInHours <= 24) {
            return 'warning';
        }

        return 'stale';
    }


}