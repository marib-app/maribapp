<?php

namespace App\Http\Controllers;

use App\Models\WifiPlan;
use App\Services\Wifi\WifiCodeImportService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class WifiCodeBatchController extends Controller
{
    public function store(Request $request, WifiPlan $plan, WifiCodeImportService $importService): JsonResponse
    {
        $plan->loadMissing('network');

        $network = $plan->network;

        if (!$network) {
            abort(404, __('Wi-Fi network not found for the specified plan.'));
        }

        if ($request->user()?->getKey() !== $network->user_id) {
            abort(403, __('You are not allowed to upload codes for this Wi-Fi plan.'));
        }

        $validated = $request->validate([
            'file' => 'required|file|mimes:csv,xls,xlsx|max:5120',
        ]);

        $batch = $importService->createBatchFromUpload($network, $plan, $validated['file'], $request->user());

        return response()->json([
            'data' => [
                'id' => $batch->getKey(),
                'accepted' => $batch->accepted_rows,
                'rejected' => $batch->rejected_rows,
                'total' => $batch->total_rows,
            ],
        ], 201);
    }
}