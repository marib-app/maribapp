<?php

namespace App\Services\Wifi;

use App\Models\AdminNotification;
use App\Models\User;
use App\Models\UserFcmToken;
use App\Models\WifiCodeBatch;
use App\Services\NotificationService;
use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Support\Arr;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class WifiOwnerRequestService
{
    public function approve(WifiCodeBatch $batch, ?User $actor): WifiCodeBatch
    {
        return $this->processDecision($batch, $actor, WifiCodeBatch::STATUS_APPROVED, 'approved');
    }

    public function reject(WifiCodeBatch $batch, ?User $actor): WifiCodeBatch
    {
        return $this->processDecision($batch, $actor, WifiCodeBatch::STATUS_REJECTED, 'rejected');
    }

    protected function processDecision(WifiCodeBatch $batch, ?User $actor, string $status, string $decision): WifiCodeBatch
    {
        $actor = $this->resolveActor($actor);
        $this->assertManagePermission($actor);
        $this->assertPending($batch);

        return DB::transaction(function () use ($batch, $actor, $status, $decision) {
            $decisionTimestamp = Carbon::now();

            $meta = $batch->meta ?? [];
            Arr::set($meta, 'owner_request', [
                'status' => $decision,
                'decided_by' => $actor->getKey(),
                'decided_by_name' => $actor->name,
                'decided_at' => $decisionTimestamp->toIso8601String(),
            ]);

            $batch->forceFill([
                'status' => $status,
                'processed_at' => $decisionTimestamp,
                'meta' => $meta,
            ])->save();

            $batch->loadMissing(['network.owner', 'plan']);

            AdminNotification::resolveFor($batch, AdminNotification::TYPE_WIFI_OWNER_REQUEST);

            $this->notifyOwner($batch, $decision);
            $this->notifyTeam($batch, $decision, $actor);

            return $batch->fresh(['network.owner', 'plan']);
        });
    }

    protected function resolveActor(?User $actor): User
    {
        if ($actor === null) {
            throw new AuthorizationException(__('Authentication is required to manage Wi-Fi owner requests.'));
        }

        return $actor;
    }

    protected function assertManagePermission(User $actor): void
    {
        if (! $actor->can('wifi-cabin-manage')) {
            throw new AuthorizationException(__('You are not authorized to manage Wi-Fi owner requests.'));
        }
    }

    protected function assertPending(WifiCodeBatch $batch): void
    {
        if ($batch->status !== WifiCodeBatch::STATUS_PENDING) {
            throw ValidationException::withMessages([
                'batch' => __('Only pending Wi-Fi owner requests can be processed.'),
            ]);
        }
    }

    protected function notifyOwner(WifiCodeBatch $batch, string $decision): void
    {
        $owner = $batch->network?->owner;

        if ($owner === null) {
            return;
        }

        $tokens = UserFcmToken::query()
            ->where('user_id', $owner->getKey())
            ->pluck('fcm_token')
            ->filter()
            ->unique()
            ->values()
            ->all();

        if ($tokens === []) {
            return;
        }

        $networkName = $batch->network?->name ?? __('Wi-Fi network');
        $planName = $batch->plan?->name ?? __('Wi-Fi plan');

        $title = $decision === 'approved'
            ? __('Your Wi-Fi voucher upload was approved')
            : __('Your Wi-Fi voucher upload was rejected');

        $message = $decision === 'approved'
            ? __('Your request for :plan on :network has been approved.', [
                'plan' => $planName,
                'network' => $networkName,
            ])
            : __('Your request for :plan on :network has been rejected. Please review the submission and try again.', [
                'plan' => $planName,
                'network' => $networkName,
            ]);

        NotificationService::sendFcmNotification($tokens, $title, $message, 'wifi_owner_request', [
            'wifi_code_batch_id' => $batch->getKey(),
            'wifi_network_id' => $batch->wifi_network_id,
            'wifi_plan_id' => $batch->wifi_plan_id,
            'decision' => $decision,
        ]);
    }

    protected function notifyTeam(WifiCodeBatch $batch, string $decision, User $actor): void
    {
        $teamUserIds = User::permission('wifi-cabin-manage')
            ->whereKeyNot($actor->getKey())
            ->pluck('id')
            ->all();

        if ($teamUserIds === []) {
            return;
        }

        $tokens = UserFcmToken::query()
            ->whereIn('user_id', $teamUserIds)
            ->pluck('fcm_token')
            ->filter()
            ->unique()
            ->values()
            ->all();

        if ($tokens === []) {
            return;
        }

        $networkName = $batch->network?->name ?? __('Wi-Fi network');
        $planName = $batch->plan?->name ?? __('Wi-Fi plan');

        $title = $decision === 'approved'
            ? __('Wi-Fi owner request approved')
            : __('Wi-Fi owner request rejected');

        $message = $decision === 'approved'
            ? __(':user approved the owner request for :plan on :network.', [
                'user' => $actor->name ?? __('Administrator'),
                'plan' => $planName,
                'network' => $networkName,
            ])
            : __(':user rejected the owner request for :plan on :network.', [
                'user' => $actor->name ?? __('Administrator'),
                'plan' => $planName,
                'network' => $networkName,
            ]);

        NotificationService::sendFcmNotification($tokens, $title, $message, 'wifi_owner_request_team', [
            'wifi_code_batch_id' => $batch->getKey(),
            'wifi_network_id' => $batch->wifi_network_id,
            'wifi_plan_id' => $batch->wifi_plan_id,
            'decision' => $decision,
        ]);
    }
}