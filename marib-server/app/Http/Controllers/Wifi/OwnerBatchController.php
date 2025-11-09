<?php

namespace App\Http\Controllers\Wifi;

use App\Enums\Wifi\WifiCodeBatchStatus;
use App\Http\Controllers\Controller;
use App\Http\Requests\Wifi\UpdateWifiCodeBatchStatusRequest;
use App\Http\Requests\Wifi\UploadWifiCodeBatchRequest;
use App\Http\Resources\Wifi\WifiCodeBatchResource;
use App\Models\Wifi\WifiCodeBatch;
use App\Models\Wifi\WifiPlan;
use App\Services\Audit\AuditLogger;
use App\Services\Wifi\WifiCodeBatchProcessor;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\Storage;

class OwnerBatchController extends Controller
{
    public function __construct(
        private AuditLogger $auditLogger,
        private WifiCodeBatchProcessor $batchProcessor
    )
    {
    }

    public function index(Request $request, WifiPlan $plan): AnonymousResourceCollection
    {
        $this->authorize('view', $plan);

        $batches = $plan->codeBatches()
            ->orderByDesc('created_at')
            ->paginate((int) $request->integer('per_page', 15))
            ->appends($request->query());

        return WifiCodeBatchResource::collection($batches);
    }

    public function store(UploadWifiCodeBatchRequest $request, WifiPlan $plan): JsonResponse
    {
        $file = $request->file('source_file');
        $path = $file->store('wifi/batches');
        $checksum = hash_file('sha1', Storage::path($path));

        $data = $request->validated();

        $batch = new WifiCodeBatch([
            'label' => $data['label'],
            'source_filename' => $file->getClientOriginalName(),
            'checksum' => $checksum,
            'total_codes' => $data['total_codes'] ?? 0,
            'available_codes' => $data['available_codes'] ?? ($data['total_codes'] ?? 0),
            'notes' => $data['notes'] ?? null,
            'meta' => $data['meta'] ?? [],
        ]);

        $batch->wifi_plan_id = $plan->id;
        $batch->wifi_network_id = $plan->wifi_network_id;
        $batch->uploaded_by = $request->user()->id;
        $batch->status = WifiCodeBatchStatus::UPLOADED;
        $batch->meta = array_merge($batch->meta ?? [], ['storage_path' => $path]);

        $batch->save();
        $batch->refresh();



        try {
            $summary = $this->batchProcessor->process($plan, $batch, $path);
        } catch (\Throwable $exception) {
            report($exception);

            return response()->json([
                'message' => __('تعذر معالجة ملف الأكواد. يرجى التحقق من التنسيق وإعادة المحاولة.'),
            ], 422);
        }


        $this->auditLogger->logChanges($batch, 'wifi.batch.created', ['label', 'status'], $request->user(), [
            'description' => 'Wifi code batch uploaded by owner',
        ]);

        $response = WifiCodeBatchResource::make($batch->refresh())->resolve();

        $response['summary'] = $summary;

        return response()->json($response, 201);
    }

    public function show(WifiCodeBatch $batch): WifiCodeBatchResource
    {
        $this->authorize('view', $batch);

        return WifiCodeBatchResource::make($batch);
    }

    public function updateStatus(UpdateWifiCodeBatchStatusRequest $request, WifiCodeBatch $batch): WifiCodeBatchResource
    {
        $validated = $request->validated();
        $target = WifiCodeBatchStatus::from($validated['status']);

        $batch->status = $target;

        if ($target === WifiCodeBatchStatus::VALIDATED && $batch->validated_at === null) {
            $batch->validated_at = now();
        }

        if ($target === WifiCodeBatchStatus::ACTIVE) {
            $batch->activated_at = now();
            if ($batch->validated_at === null) {
                $batch->validated_at = now();
            }
        }

        if (! empty($validated['notes'])) {
            $batch->notes = trim((string) $validated['notes']);
        }

        $dirty = array_keys($batch->getDirty());
        if ($dirty === []) {
            return WifiCodeBatchResource::make($batch->refresh());
        }

        $this->auditLogger->logChanges($batch, 'wifi.batch.status_updated', $dirty, $request->user(), [
            'description' => 'Wifi code batch status updated by owner',
        ]);

        $batch->save();

        return WifiCodeBatchResource::make($batch->refresh());
    }

    public function destroy(Request $request, WifiCodeBatch $batch)
    {
        $this->authorize('delete', $batch);

        $this->auditLogger->logChanges($batch, 'wifi.batch.deleted', ['status'], $request->user(), [
            'description' => 'Wifi code batch deleted by owner',
        ]);

        Storage::delete(data_get($batch->meta, 'storage_path'));

        $batch->delete();

        return response()->noContent();
    }
}
