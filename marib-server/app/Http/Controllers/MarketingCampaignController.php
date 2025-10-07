<?php

namespace App\Http\Controllers;

use App\Models\Campaign;
use App\Services\MarketingNotificationService;
use App\Services\ResponseService;
use Illuminate\Http\Request;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\Rule;
use Throwable;

class MarketingCampaignController extends Controller
{
    public function store(Request $request, MarketingNotificationService $marketingNotificationService)
    {
        ResponseService::noPermissionThenSendJson('notification-create');

        $validator = Validator::make($request->all(), [
            'name' => ['required', 'string', 'max:255'],
            'notification_title' => ['required', 'string', 'max:255'],
            'notification_body' => ['required', 'string'],
            'trigger_type' => ['required', Rule::in([
                Campaign::TRIGGER_MANUAL,
                Campaign::TRIGGER_SCHEDULED,
                Campaign::TRIGGER_EVENT,
            ])],
            'event_key' => ['nullable', 'string', 'max:255'],
            'scheduled_at' => ['nullable', 'date'],
            'segments' => ['nullable', 'array'],
        ]);

        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }

        try {
            $segments = $this->normalizeSegments($request->input('segments', []));
            $campaign = $marketingNotificationService->createCampaign($request->all(), $segments);

            if ($request->boolean('dispatch_now')) {
                $marketingNotificationService->dispatchCampaign($campaign);
            }

            ResponseService::successResponse(__('Campaign saved successfully'), $campaign);
        } catch (Throwable $throwable) {
            ResponseService::logErrorResponse($throwable, 'MarketingCampaignController -> store');
            ResponseService::errorResponse(__('Something Went Wrong'));
        }
    }


    public function update(
        Campaign $campaign,
        Request $request,
        MarketingNotificationService $marketingNotificationService
    ) {
        ResponseService::noPermissionThenSendJson('notification-update');

        $validator = Validator::make($request->all(), [
            'name' => ['required', 'string', 'max:255'],
            'notification_title' => ['required', 'string', 'max:255'],
            'notification_body' => ['required', 'string'],
            'trigger_type' => ['required', Rule::in([
                Campaign::TRIGGER_MANUAL,
                Campaign::TRIGGER_SCHEDULED,
                Campaign::TRIGGER_EVENT,
            ])],
            'event_key' => ['nullable', 'string', 'max:255'],
            'scheduled_at' => ['nullable', 'date'],
            'segments' => ['nullable', 'array'],
        ]);

        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }

        try {
            $segmentsInput = $request->input('segments', []);
            $normalizedSegments = $this->normalizeSegments($segmentsInput);
            $segmentsPayload = $request->has('segments') ? $normalizedSegments : null;

            $campaign = $marketingNotificationService->updateCampaign(
                $campaign,
                $request->all(),
                $segmentsPayload
            );

            if ($request->boolean('dispatch_now')) {
                $marketingNotificationService->dispatchCampaign($campaign);
            }

            ResponseService::successResponse(__('Campaign updated successfully'), $campaign);
        } catch (Throwable $throwable) {
            ResponseService::logErrorResponse($throwable, 'MarketingCampaignController -> update');
            ResponseService::errorResponse(__('Something Went Wrong'));
        }
    }




    public function sendCampaign(Campaign $campaign, MarketingNotificationService $marketingNotificationService)
    {
        ResponseService::noPermissionThenSendJson('notification-create');

        try {
            $marketingNotificationService->dispatchCampaign($campaign);
            ResponseService::successResponse(__('Campaign dispatched successfully'));
        } catch (Throwable $throwable) {
            ResponseService::logErrorResponse($throwable, 'MarketingCampaignController -> dispatch');
            ResponseService::errorResponse(__('Something Went Wrong'));
        }
    }

    public function schedule(Campaign $campaign, Request $request, MarketingNotificationService $marketingNotificationService)
    {
        ResponseService::noPermissionThenSendJson('notification-create');

        $validator = Validator::make($request->all(), [
            'scheduled_at' => ['required', 'date'],
        ]);

        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }

        try {
            $event = $marketingNotificationService->scheduleCampaign($campaign, $request->get('scheduled_at'));
            ResponseService::successResponse(__('Campaign scheduled successfully'), $event);
        } catch (Throwable $throwable) {
            ResponseService::logErrorResponse($throwable, 'MarketingCampaignController -> schedule');
            ResponseService::errorResponse(__('Something Went Wrong'));
        }
    }

    public function triggerAutomation(Request $request, MarketingNotificationService $marketingNotificationService)
    {
        ResponseService::noPermissionThenSendJson('notification-create');

        $validator = Validator::make($request->all(), [
            'event_key' => ['required', 'string', 'max:255'],
            'payload' => ['nullable', 'array'],
        ]);

        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }

        try {
            $marketingNotificationService->triggerEventCampaigns(
                $request->get('event_key'),
                $request->get('payload', [])
            );

            ResponseService::successResponse(__('Automation triggered successfully'));
        } catch (Throwable $throwable) {
            ResponseService::logErrorResponse($throwable, 'MarketingCampaignController -> triggerAutomation');
            ResponseService::errorResponse(__('Something Went Wrong'));
        }
    }

    protected function normalizeSegments($segments): array
    {
        if (is_string($segments)) {
            $decoded = json_decode($segments, true);
            $segments = is_array($decoded) ? $decoded : [];
        }

        if (!is_array($segments)) {
            return [];
        }

        $normalized = [];
        foreach ($segments as $segment) {
            $filters = Arr::get($segment, 'filters', []);
            if (is_string($filters)) {
                $filters = json_decode($filters, true) ?: [];
            }

            if (isset($filters['purchased_item_ids']) && is_string($filters['purchased_item_ids'])) {
                $filters['purchased_item_ids'] = array_filter(array_map('intval', explode(',', $filters['purchased_item_ids'])));
            }

            $normalized[] = [
                'id' => Arr::get($segment, 'id'),
                'name' => Arr::get($segment, 'name'),
                'description' => Arr::get($segment, 'description'),
                'filters' => $filters,
            ];
        }

        return $normalized;
    }
}