<?php

namespace App\Http\Controllers;

use App\Enums\Wifi\WifiCodeBatchStatus;
use App\Enums\Wifi\WifiCodeStatus;
use App\Enums\Wifi\WifiNetworkStatus;
use App\Enums\Wifi\WifiPlanStatus;
use App\Http\Requests\Wifi\UpdateWifiCodeBatchStatusRequest;
use App\Models\Wifi\WifiCode;
use App\Models\Wifi\WifiCodeBatch;
use App\Models\Wifi\WifiNetwork;
use App\Models\Wifi\WifiPlan;
use App\Models\Wifi\WifiSale;
use App\Services\Audit\AuditLogger;
use App\Services\Wifi\WifiCodeBatchProcessor;
use App\Services\Wifi\WifiOperationalService;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Contracts\View\View as ViewContract;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\Storage;
use Illuminate\View\View;
use Carbon\Carbon;
use Symfony\Component\HttpFoundation\StreamedResponse;
use Throwable;


class WifiCabinController extends Controller
{
    public function __construct(
        private readonly WifiNetwork $wifiNetwork,
        private readonly WifiPlan $wifiPlan,
        private readonly WifiCodeBatch $wifiCodeBatch,
        private readonly AuditLogger $auditLogger,
        private readonly WifiOperationalService $operationalService,
        private readonly WifiCodeBatchProcessor $batchProcessor
    ) {
    }

    public function index(Request $request): View
    {
        $perPage = (int) $request->integer('per_page', 15);
        $search = trim((string) $request->input('search', ''));

        $networkQuery = $this->wifiNetwork->newQuery()->with(['owner:id,name,email']);


        $wifiPlanHasStatusColumn = Schema::hasColumn($this->wifiPlan->getTable(), 'status');
        $wifiNetworkHasStatusColumn = Schema::hasColumn($this->wifiNetwork->getTable(), 'status');
        $wifiCodeBatchHasStatusColumn = Schema::hasColumn($this->wifiCodeBatch->getTable(), 'status');
        $wifiCodeHasStatusColumn = Schema::hasColumn((new WifiCode())->getTable(), 'status');


        if ($search !== '') {
            $term = mb_strtolower($search);
            $networkQuery->where(function ($query) use ($term): void {
                $query->whereRaw('LOWER(name) LIKE ?', ['%' . $term . '%'])
                    ->orWhereRaw('LOWER(address) LIKE ?', ['%' . $term . '%']);
            });
        }

        $networkQuery->withCount(['plans']);

        if ($wifiPlanHasStatusColumn) {
            $networkQuery->withCount([
                'plans as active_plans_count' => function ($query): void {
                    $query->where('status', WifiPlanStatus::ACTIVE->value);
                },
            ]);
        }

        /** @var LengthAwarePaginator $networks */
        $networks = $networkQuery

            ->orderByDesc('created_at')
            ->paginate($perPage)
            ->appends($request->query());

        if (! $wifiPlanHasStatusColumn) {
            $networks->getCollection()->each(static function ($network): void {
                $network->active_plans_count = 0;
            });
        }

        $pendingRequestsQuery = $this->wifiCodeBatch->newQuery();

        if ($wifiCodeBatchHasStatusColumn) {
            $pendingRequestsQuery->where('status', WifiCodeBatchStatus::UPLOADED->value);
        }

        $pendingRequests = $pendingRequestsQuery

            ->with([
                'plan:id,name,wifi_network_id',
                'plan.network:id,name'
            ])
            ->orderByDesc('created_at')
            ->limit(15)
            ->get();

        $stats = [
            'networks' => [
                'total' => $this->wifiNetwork->newQuery()->count(),
                'active' => $wifiNetworkHasStatusColumn
                    ? $this->wifiNetwork->newQuery()->where('status', WifiNetworkStatus::ACTIVE->value)->count()
                    : 0,
                'inactive' => $wifiNetworkHasStatusColumn
                    ? $this->wifiNetwork->newQuery()->where('status', WifiNetworkStatus::INACTIVE->value)->count()
                    : 0,
                'suspended' => $wifiNetworkHasStatusColumn
                    ? $this->wifiNetwork->newQuery()->where('status', WifiNetworkStatus::SUSPENDED->value)->count()
                    : 0,
            ],
            'plans' => [
                'total' => $this->wifiPlan->newQuery()->count(),
                'active' => $wifiPlanHasStatusColumn
                    ? $this->wifiPlan->newQuery()->where('status', WifiPlanStatus::ACTIVE->value)->count()
                    : 0,
                'uploaded' => $wifiPlanHasStatusColumn
                    ? $this->wifiPlan->newQuery()->where('status', WifiPlanStatus::UPLOADED->value)->count()
                    : 0,
                'archived' => $wifiPlanHasStatusColumn
                    ? $this->wifiPlan->newQuery()->where('status', WifiPlanStatus::ARCHIVED->value)->count()
                    : 0,
            ],
            'batches' => [
                'total' => $this->wifiCodeBatch->newQuery()->count(),
                'pending' => $wifiCodeBatchHasStatusColumn
                    ? $this->wifiCodeBatch->newQuery()->where('status', WifiCodeBatchStatus::UPLOADED->value)->count()
                    : 0,
                'active' => $wifiCodeBatchHasStatusColumn
                    ? $this->wifiCodeBatch->newQuery()->where('status', WifiCodeBatchStatus::ACTIVE->value)->count()
                    : 0,
            ],
            'codes' => [
                'total' => WifiCode::query()->count(),
                'available' => $wifiCodeHasStatusColumn
                    ? WifiCode::query()->where('status', WifiCodeStatus::AVAILABLE->value)->count()
                    : 0,
                'sold' => $wifiCodeHasStatusColumn
                    ? WifiCode::query()->where('status', WifiCodeStatus::SOLD->value)->count()
                    : 0,
            ],
        ];

        $alertsConfig = config('wifi.alerts', []);

        return view('wifi.index', [
            'networks' => $networks,
            'pendingRequests' => $pendingRequests,
            'stats' => $stats,
            'alertsConfig' => $alertsConfig,
            'search' => $search,
            'adminApiBaseUrl' => url('/wifi-cabin/api'),
            'ownerApiBaseUrl' => url('/wifi-cabin/api/owner'),
        ]);
    }

    public function create(): ViewContract
    {
        $networks = $this->wifiNetwork->newQuery()
            ->orderBy('name')
            ->get(['id', 'name']);

        $plans = $this->wifiPlan->newQuery()
            ->with('network:id,name')
            ->orderBy('name')
            ->get(['id', 'wifi_network_id', 'name']);

        return view('wifi.create', [
            'networks' => $networks,
            'plans' => $plans,
        ]);
    }

    public function show(Request $request, WifiNetwork $network): View
    {
        $network->load([
            'owner',
            'plans' => static function ($query): void {
                $query->with(['codeBatches' => static function ($batchQuery): void {
                    $batchQuery->orderByDesc('created_at');
                }])->orderByDesc('created_at');
            },
        ]);

        $media = [
            'logo' => $network->icon_path ? Storage::url($network->icon_path) : null,
            'login_screenshot' => $network->login_screenshot_path
                ? Storage::url($network->login_screenshot_path)
                : null,
        ];

        $contacts = collect($network->contacts ?? [])
            ->map(static function ($contact) {
                if (is_string($contact)) {
                    return [
                        'type' => 'other',
                        'value' => $contact,
                    ];
                }

                if (is_array($contact)) {
                    return [
                        'type' => $contact['type'] ?? 'other',
                        'label' => $contact['label'] ?? null,
                        'value' => $contact['value'] ?? null,
                    ];
                }

                return null;
            })
            ->filter(static fn ($contact) => filled($contact['value'] ?? null))
            ->values();

        $commissionRate = data_get($network->settings, 'commission_rate');
        if ($commissionRate === null) {
            $commissionRate = data_get($network->meta, 'commission_rate');
        }

        $statistics = $this->buildNetworkStatistics($network);
        $financialFilters = $this->resolveFinancialFilters($request);
        $financials = $this->buildFinancialSummary($network, $financialFilters['from'], $financialFilters['to']);

        return view('wifi.show', [
            'network' => $network,
            'statistics' => $statistics,
            'media' => $media,
            'contacts' => $contacts,
            'commissionRate' => $commissionRate,
            'financialFilters' => $financialFilters,
            'financialTotals' => $financials['totals'],
            'recentSales' => $financials['sales'],
        ]);
    }

    public function exportSalesReport(Request $request, WifiNetwork $network): StreamedResponse
    {
        $filters = $this->resolveFinancialFilters($request);
        $filename = sprintf(
            'wifi-sales-%s-%s-%s.csv',
            $network->getKey(),
            $filters['from']->format('Ymd'),
            $filters['to']->format('Ymd')
        );

        $query = WifiSale::query()
            ->with(['plan:id,name', 'user:id,name'])
            ->where('wifi_network_id', $network->getKey())
            ->whereBetween('paid_at', [$filters['from'], $filters['to']])
            ->orderByDesc('paid_at');

        $headers = [
            'Content-Type' => 'text/csv; charset=UTF-8',
            'Content-Disposition' => "attachment; filename=\"{$filename}\"",
        ];

        $callback = static function () use ($query): void {
            $handle = fopen('php://output', 'w');
            fputcsv($handle, [
                'التاريخ',
                'الخطة',
                'المستخدم',
                'المبلغ الإجمالي',
                'العملة',
                'نسبة العمولة',
                'مبلغ العمولة',
                'حصة المالك',
                'مرجع الدٝع',
            ]);

            $query->chunk(500, static function ($sales) use ($handle): void {
                foreach ($sales as $sale) {
                    fputcsv($handle, [
                        optional($sale->paid_at ?? $sale->created_at)->format('Y-m-d H:i'),
                        $sale->plan->name ?? '—',
                        $sale->user->name ?? '—',
                        number_format((float) $sale->amount_gross, 2, '.', ''),
                        $sale->currency ?? '—',
                        sprintf('%0.2f%%', (float) $sale->commission_rate * 100),
                        number_format((float) $sale->commission_amount, 2, '.', ''),
                        number_format((float) $sale->owner_share_amount, 2, '.', ''),
                        $sale->payment_reference ?? '—',
                    ]);
                }
            });

            fclose($handle);
        };

        return response()->stream($callback, 200, $headers);
    }

    public function store(Request $request): RedirectResponse
    {
        $validated = $request->validate([
            'wifi_plan_id' => ['required', 'integer', 'exists:wifi_plans,id'],
            'label' => ['required', 'string', 'max:255'],
            'notes' => ['nullable', 'string'],
            'total_codes' => ['nullable', 'integer', 'min:1', 'max:50000'],
            'available_codes' => ['nullable', 'integer', 'min:0'],
            'source_file' => ['required', 'file', 'mimes:csv,txt,xlsx'],
        ]);

        $plan = $this->wifiPlan->newQuery()
            ->with('network')
            ->findOrFail($validated['wifi_plan_id']);

        $file = $request->file('source_file');
        $path = $file->store('wifi/batches');
        $checksum = hash_file('sha1', Storage::path($path));

        $batch = $this->wifiCodeBatch->newInstance([
            'label' => $validated['label'],
            'source_filename' => $file->getClientOriginalName(),
            'checksum' => $checksum,
            'total_codes' => Arr::get($validated, 'total_codes', 0),
            'available_codes' => Arr::get($validated, 'available_codes', Arr::get($validated, 'total_codes', 0)),
            'notes' => Arr::get($validated, 'notes'),
            'meta' => [
                'storage_path' => $path,
                'uploaded_via' => 'admin_panel',
            ],
        ]);

        $batch->wifi_plan_id = $plan->getKey();
        $batch->wifi_network_id = $plan->wifi_network_id;
        $batch->uploaded_by = $request->user()?->getKey();
        $batch->status = WifiCodeBatchStatus::UPLOADED;

        $batch->save();
        $batch->refresh();

        try {
            $summary = $this->batchProcessor->process($plan, $batch, $path);
        } catch (Throwable $exception) {
            Log::error('Failed processing wifi code batch', [
                'plan_id' => $plan->getKey(),
                'batch_id' => $batch->getKey(),
                'exception' => $exception,
            ]);

            return redirect()
                ->back()
                ->withInput()
                ->withErrors(['source_file' => __('تعذر معالجة ملٝ الأكواد. يرجى التحقق من التنسيق وإعادة المحاولة.')]);
        }

        $batch->refresh();

        $this->auditLogger->logChanges($batch, 'wifi.batch.created', ['label', 'status'], $request->user(), [
            'description' => 'Wifi code batch uploaded by administrator',
            'summary' => $summary,
        ]);

        if ($plan->network) {
            $this->refreshPlanInventoryMeta($plan);
        }

        return redirect()
            ->route('wifi.edit', ['network' => $plan->wifi_network_id])
            ->with('status', __('تم رٝع الدٝعة ومعالجتها بنجاح.'));
    }

    public function edit(WifiNetwork $network): ViewContract
    {
        $network->load(['owner:id,name,email,mobile', 'walletAccount']);

        $plans = $network->plans()
            ->withCount([
                'codeBatches as batches_total_count',
                'codeBatches as batches_active_count' => function ($query): void {
                    $query->where('status', WifiCodeBatchStatus::ACTIVE->value);
                },
                'codes as codes_total_count',
                'codes as codes_available_count' => function ($query): void {
                    $query->where('status', WifiCodeStatus::AVAILABLE->value);
                },
                'codes as codes_sold_count' => function ($query): void {
                    $query->where('status', WifiCodeStatus::SOLD->value);
                },
            ])
            ->with(['codeBatches' => function ($query): void {
                $query->orderByDesc('created_at');
            }])
            ->orderBy('sort_order')
            ->orderBy('name')
            ->get();

        $batches = $this->wifiCodeBatch->newQuery()
            ->whereHas('plan', function ($query) use ($network): void {
                $query->where('wifi_network_id', $network->getKey());
            })
            ->with(['plan:id,name,wifi_network_id'])
            ->orderByDesc('created_at')
            ->paginate(20);

        $networkStats = [
            'plans_total' => $plans->count(),
            'plans_active' => $plans->where('status', WifiPlanStatus::ACTIVE)->count(),
            'batches_total' => $batches->total(),
            'batches_active' => $batches->filter(fn (WifiCodeBatch $batch) => $batch->status === WifiCodeBatchStatus::ACTIVE)->count(),
            'codes_total' => $plans->sum('codes_total_count'),
            'codes_available' => $plans->sum('codes_available_count'),
            'codes_sold' => $plans->sum('codes_sold_count'),
        ];

        return view('wifi.edit', [
            'network' => $network,
            'plans' => $plans,
            'batches' => $batches,
            'networkStats' => $networkStats,
            'adminApiEndpoints' => [
                'network_status' => url('/api/wifi/admin/networks/' . $network->getKey() . '/status'),
                'reputation' => url('/api/wifi/admin/networks/' . $network->getKey() . '/reputation-counters'),
                'reports' => url('/api/wifi/admin/reports?network_id=' . $network->getKey()),
                'commission' => url('/api/wifi/owner/networks/' . $network->getKey() . '/commission'),
            ],
        ]);
    }

    public function approveOwnerRequest(Request $request, WifiCodeBatch $batch): RedirectResponse
    {
        $batch->loadMissing('plan.network');

        if ($batch->status !== WifiCodeBatchStatus::UPLOADED) {
            return redirect()
                ->back()
                ->with('status', __('تمت معالجة هذا الطلب مسبقًا.'));
        }

        $now = now();
        $targetStatus = $batch->available_codes > 0 ? WifiCodeBatchStatus::ACTIVE : WifiCodeBatchStatus::VALIDATED;

        $batch->status = $targetStatus;
        $batch->validated_at = $batch->validated_at ?? $now;
        if ($targetStatus === WifiCodeBatchStatus::ACTIVE) {
            $batch->activated_at = $batch->activated_at ?? $now;
        }

        $dirty = array_keys($batch->getDirty());
        $batch->save();

        $this->auditLogger->logChanges($batch, 'wifi.batch.status_updated', $dirty, $request->user(), [
            'description' => 'Wifi code batch approved by administrator',
        ]);

        if ($batch->plan) {
            $this->refreshPlanInventoryMeta($batch->plan);
        }

        return redirect()
            ->back()
            ->with('status', __('تمت المواٝقة على طلب المالك بنجاح.'));
    }

    public function rejectOwnerRequest(Request $request, WifiCodeBatch $batch): RedirectResponse
    {
        $batch->loadMissing('plan.network');

        $validated = $request->validate([
            'reason' => ['nullable', 'string', 'max:1000'],
        ]);

        if ($batch->status === WifiCodeBatchStatus::ARCHIVED) {
            return redirect()
                ->back()
                ->with('status', __('تم رٝض هذا الطلب مسبقًا.'));
        }

        $batch->status = WifiCodeBatchStatus::ARCHIVED;
        $meta = $batch->meta ?? [];
        if (! empty($validated['reason'])) {
            $meta['admin_rejection_reason'] = $validated['reason'];
        }
        $batch->meta = $meta;

        $dirty = array_keys($batch->getDirty());
        $batch->save();

        $this->auditLogger->logChanges($batch, 'wifi.batch.status_updated', $dirty, $request->user(), [
            'description' => 'Wifi code batch rejected by administrator',
            'reason' => $validated['reason'] ?? null,
        ]);

        if ($batch->plan) {
            $this->refreshPlanInventoryMeta($batch->plan);
        }

        return redirect()
            ->back()
            ->with('status', __('تم رٝض طلب المالك وتحديث الحالة.'));
    }

    private function refreshPlanInventoryMeta(WifiPlan $plan): void
    {
        $plan->loadMissing('network');
        $network = $plan->network;

        if (! $network instanceof WifiNetwork) {
            return;
        }

        $meta = $plan->meta ?? [];
        $updatedMeta = $this->operationalService->handlePostSaleInventory($plan, $network, $meta);

        if ($updatedMeta !== $meta) {
            $plan->meta = $updatedMeta;
            $plan->save();
        }
    }

    /**
     * @return array{from: Carbon, to: Carbon}
     */
    private function resolveFinancialFilters(Request $request): array
    {
        $defaultTo = Carbon::now()->endOfDay();
        $defaultFrom = Carbon::now()->subDays(30)->startOfDay();

        $fromInput = $request->query('from');
        $toInput = $request->query('to');

        try {
            $from = $fromInput ? Carbon::parse($fromInput)->startOfDay() : $defaultFrom;
        } catch (\Exception) {
            $from = $defaultFrom;
        }

        try {
            $to = $toInput ? Carbon::parse($toInput)->endOfDay() : $defaultTo;
        } catch (\Exception) {
            $to = $defaultTo;
        }

        if ($to->lt($from)) {
            $to = $from->copy()->endOfDay();
        }

        return [
            'from' => $from,
            'to' => $to,
        ];
    }

    private function buildFinancialSummary(WifiNetwork $network, Carbon $from, Carbon $to): array
    {
        $baseQuery = WifiSale::query()
            ->where('wifi_network_id', $network->getKey())
            ->whereBetween('paid_at', [$from, $to]);

        $totalsRow = (clone $baseQuery)
            ->selectRaw('COALESCE(SUM(amount_gross), 0) as gross')
            ->selectRaw('COALESCE(SUM(commission_amount), 0) as commission')
            ->selectRaw('COALESCE(SUM(owner_share_amount), 0) as owner_share')
            ->first();

        $recentSales = (clone $baseQuery)
            ->with(['plan:id,name', 'user:id,name'])
            ->orderByDesc('paid_at')
            ->limit(10)
            ->get();

        return [
            'totals' => [
                'gross' => (float) ($totalsRow->gross ?? 0),
                'commission' => (float) ($totalsRow->commission ?? 0),
                'owner_share' => (float) ($totalsRow->owner_share ?? 0),
            ],
            'sales' => $recentSales,
        ];
    }

    private function buildNetworkStatistics(WifiNetwork $network): array
    {
        $plans = $network->plans ?? collect();

        $activePlans = $plans->filter(static function ($plan) {
            return ($plan->status ?? null) === WifiPlanStatus::ACTIVE->value;
        })->count();

        $codes = [
            'total' => 0,
            'available' => 0,
            'sold' => 0,
        ];

        foreach ($plans as $plan) {
            $batches = $plan->codeBatches ?? collect();
            foreach ($batches as $batch) {
                $total = (int) ($batch->total_codes ?? 0);
                $available = (int) ($batch->available_codes ?? 0);
                $codes['total'] += $total;
                $codes['available'] += $available;
                $codes['sold'] += max($total - $available, 0);
            }
        }

        return [
            'plans' => [
                'total' => $plans->count(),
                'active' => $activePlans,
                'inactive' => max($plans->count() - $activePlans, 0),
            ],
            'codes' => $codes,
        ];
    }

    public function codes(Request $request, WifiNetwork $network): View
    {
        $perPage = max(5, min(100, (int) $request->integer('per_page', 25)));
        $search = trim((string) $request->input('search', ''));
        $statusFilter = $request->input('status');

        $query = WifiCode::query()
            ->where('wifi_network_id', $network->getKey())
            ->with(['plan:id,name'])
            ->leftJoin('users', 'users.id', '=', 'wifi_codes.allocated_to_user_id')
            ->select('wifi_codes.*', 'users.name as allocated_user_name', 'users.email as allocated_user_email')
            ->orderByDesc('wifi_codes.id');

        if ($search !== '') {
            $term = '%' . $search . '%';
            $query->where(function ($q) use ($term): void {
                $q->where('wifi_codes.code_suffix', 'like', $term)
                    ->orWhere('wifi_codes.code_last4', 'like', $term)
                    ->orWhere('wifi_codes.serial_no_encrypted', 'like', $term)
                    ->orWhere('wifi_codes.id', 'like', $term);
            });
        }

        if (is_string($statusFilter) && $statusFilter !== '') {
            $query->where('wifi_codes.status', $statusFilter);
        }

        $codes = $query->paginate($perPage)->appends($request->query());

        return view('wifi.codes', [
            'network' => $network,
            'codes' => $codes,
            'search' => $search,
            'statusFilter' => $statusFilter,
        ]);
    }

}
