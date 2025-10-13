<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\SaveAdDraftRequest;
use App\Http\Requests\Api\PublishAdDraftRequest;
use App\Http\Resources\AdDraftResource;
use App\Services\AdDraftService;
use App\Services\ResponseService;
use Illuminate\Http\Request;

class AdDraftController extends Controller
{
    public function store(SaveAdDraftRequest $request, AdDraftService $service)
    {
        $userId = (int) $request->user()->id;
        $draft = $service->saveDraft(null, $userId, $request->normalized());

        return ResponseService::successResponse(
            __('Draft saved successfully.'),
            (new AdDraftResource($draft))->toArray($request)
        );
    }

    public function update(SaveAdDraftRequest $request, AdDraftService $service, int $draft)
    {
        $userId = (int) $request->user()->id;
        $savedDraft = $service->saveDraft($draft, $userId, $request->normalized());

        return ResponseService::successResponse(
            __('Draft updated successfully.'),
            (new AdDraftResource($savedDraft))->toArray($request)
        );
    }

    public function show(Request $request, AdDraftService $service, int $draft)
    {
        $userId = (int) $request->user()->id;
        $found = $service->getDraftForUser($draft, $userId);

        return ResponseService::successResponse(
            __('Draft fetched successfully.'),
            (new AdDraftResource($found))->toArray($request)
        );
    }
    public function publish(PublishAdDraftRequest $request, AdDraftService $service)
    {
        $userId = (int) $request->user()->id;
        $normalized = $request->normalized();
        $draftId = $normalized['draft_id'];
        $result = $service->publish(
            $draftId !== null ? (int) $draftId : null,
            $userId,
            $normalized['payload'],
        );

        return ResponseService::successResponse(
            __('Ad submitted successfully.'),
            $result,
        );
    }
}