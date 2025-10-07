<?php

namespace App\Services;

use App\Jobs\DispatchCampaignNotifications;
use App\Models\Campaign;
use App\Models\CampaignEvent;
use App\Models\CampaignSegment;
use App\Models\NotificationDelivery;
use App\Models\User;
use App\Models\UserFcmToken;
use Carbon\Carbon;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\DB;

class MarketingNotificationService
{
    public function createCampaign(array $data, array $segments = []): Campaign
    {
        return DB::transaction(function () use ($data, $segments) {
            $campaignData = $this->extractCampaignData($data);
            $campaign = Campaign::create($campaignData);

            if (!empty($segments)) {
                $this->syncSegments($campaign, $segments);
            }

            if ($campaign->isScheduled()) {
                $this->scheduleCampaign($campaign, $campaign->scheduled_at);
            }

            return $campaign->fresh(['segments']);
        });
    }

    public function updateCampaign(Campaign $campaign, array $data, ?array $segments = null): Campaign

    {
        return DB::transaction(function () use ($campaign, $data, $segments) {
            $campaign->fill($this->extractCampaignData($data));
            $campaign->save();

            if (is_array($segments)) {
                $this->syncSegments($campaign, $segments);
            }

            if ($campaign->isScheduled()) {
                $this->scheduleCampaign($campaign, $campaign->scheduled_at);
            }

            return $campaign->fresh(['segments']);
        });
    }

    public function syncSegments(Campaign $campaign, array $segmentsData): void
    {
        $segmentIds = [];
        foreach ($segmentsData as $segmentData) {
            $segment = $this->saveSegment($campaign, $segmentData);
            $segmentIds[] = $segment->id;
        }


        if (empty($segmentIds)) {
            $campaign->segments()->delete();

            return;


             }
             
        $campaign->segments()->whereNotIn('id', $segmentIds)->delete();


       
    }

    public function scheduleCampaign(Campaign $campaign, Carbon|string|null $scheduleAt, array $payload = []): CampaignEvent
    {
        $scheduleAt = $scheduleAt ? Carbon::parse($scheduleAt) : now();

        $event = $campaign->events()->create([
            'event_type' => 'schedule',
            'status' => CampaignEvent::STATUS_PENDING,
            'scheduled_at' => $scheduleAt,
            'payload' => $payload,
        ]);

        DispatchCampaignNotifications::dispatch($campaign, $event)->delay($scheduleAt);

        $campaign->update([
            'status' => Campaign::STATUS_SCHEDULED,
            'scheduled_at' => $scheduleAt,
        ]);

        return $event;
    }

    public function dispatchCampaign(Campaign $campaign, ?CampaignEvent $event = null): void
    {
        $campaign->loadMissing('segments');
        $segments = $campaign->segments;

        if ($segments->isEmpty()) {
            $userIds = $this->baseUserQuery()->pluck('id')->all();
            $this->sendToUserIds($campaign, null, $userIds, $event);
        } else {
            foreach ($segments as $segment) {
                $query = $this->buildSegmentQuery($segment);
                $userIds = $query->pluck('id')->all();
                $segment->forceFill([
                    'estimated_size' => count($userIds),
                    'last_calculated_at' => now(),
                ])->save();

                if (!empty($userIds)) {
                    $this->sendToUserIds($campaign, $segment, $userIds, $event);
                }
            }
        }

        $campaign->forceFill([
            'status' => $campaign->trigger_type === Campaign::TRIGGER_MANUAL
                ? Campaign::STATUS_COMPLETED
                : Campaign::STATUS_ACTIVE,
            'last_dispatched_at' => now(),
        ])->save();

        if ($event) {
            $event->forceFill([
                'status' => CampaignEvent::STATUS_DISPATCHED,
                'dispatched_at' => now(),
            ])->save();
        }
    }

    public function triggerEventCampaigns(string $eventKey, array $payload = []): void
    {
        $campaigns = Campaign::query()
            ->active()

            ->where('trigger_type', Campaign::TRIGGER_EVENT)
            ->where('event_key', $eventKey)

            ->get();

        foreach ($campaigns as $campaign) {
            $event = $campaign->events()->create([
                'event_type' => $eventKey,
                'status' => CampaignEvent::STATUS_PENDING,
                'payload' => $payload,
            ]);

            DispatchCampaignNotifications::dispatch($campaign, $event);
        }
    }

    public function getDashboardMetrics(): array
    {
        $totalCampaigns = Campaign::count();
        $activeCampaigns = Campaign::whereIn('status', [Campaign::STATUS_ACTIVE, Campaign::STATUS_SCHEDULED])->count();
        $eventDriven = Campaign::where('trigger_type', Campaign::TRIGGER_EVENT)->count();

        $totalDeliveries = NotificationDelivery::count();
        $delivered = NotificationDelivery::whereNotNull('delivered_at')->count();
        $opened = NotificationDelivery::whereNotNull('opened_at')->count();
        $clicked = NotificationDelivery::whereNotNull('clicked_at')->count();
        $reactivated = NotificationDelivery::whereNotNull('reactivated_at')->count();

        return [
            'total_campaigns' => $totalCampaigns,
            'active_campaigns' => $activeCampaigns,
            'event_driven_campaigns' => $eventDriven,
            'delivery_rate' => $totalDeliveries > 0 ? round($delivered / $totalDeliveries * 100, 2) : 0,
            'open_rate' => $delivered > 0 ? round($opened / $delivered * 100, 2) : 0,
            'click_rate' => $delivered > 0 ? round($clicked / $delivered * 100, 2) : 0,
            'reactivation_rate' => $delivered > 0 ? round($reactivated / $delivered * 100, 2) : 0,
        ];
    }

    public function getOverviewData(): array
    {
        return [
            'campaigns' => Campaign::with([
                'segments',
                'events' => fn ($query) => $query->latest()->limit(3),
            ])->latest()->get(),
            'metrics' => $this->getDashboardMetrics(),
            'recent_deliveries' => NotificationDelivery::with(['campaign', 'user'])
                ->latest()
                ->limit(10)
                ->get(),
        ];
    }

    protected function sendToUserIds(Campaign $campaign, ?CampaignSegment $segment, array $userIds, ?CampaignEvent $event = null): void
    {
        if (empty($userIds)) {
            return;
        }

        $tokens = UserFcmToken::query()
            ->whereIn('user_id', $userIds)
            ->pluck('fcm_token')
            ->filter()
            ->unique()
            ->values()
            ->all();

        if (empty($tokens)) {
            return;
        }

        $payload = [
            'campaign_id' => (string) $campaign->id,
            'cta_label' => $campaign->cta_label ?? '',
            'cta_destination' => $campaign->cta_destination ?? '',
            'event_id' => $event?->id,
        ];

        $result = NotificationService::sendFcmNotification(
            $tokens,
            $campaign->notification_title,
            $campaign->notification_body,
            'campaign',
            $payload
        );

        $status = $result['error'] ?? false
            ? NotificationDelivery::STATUS_FAILED
            : NotificationDelivery::STATUS_SENT;

        $timestamp = $status === NotificationDelivery::STATUS_SENT ? now() : null;

        foreach ($userIds as $userId) {
            NotificationDelivery::create([
                'campaign_id' => $campaign->id,
                'segment_id' => $segment?->id,
                'user_id' => $userId,
                'status' => $status,
                'delivered_at' => $timestamp,
                'meta' => [
                    'event_id' => $event?->id,
                    'response' => $result,
                ],
            ]);
        }
    }

    protected function saveSegment(Campaign $campaign, array $segmentData): CampaignSegment
    {
        $filters = Arr::get($segmentData, 'filters', []);
        if (is_string($filters)) {
            $filters = json_decode($filters, true) ?: [];
        }

        $segment = $campaign->segments()->firstOrNew([
            'id' => Arr::get($segmentData, 'id'),
        ]);

        $segment->fill([
            'name' => Arr::get($segmentData, 'name', 'Untitled Segment'),
            'description' => Arr::get($segmentData, 'description'),
            'filters' => $filters,
        ]);

        $segment->save();

        $query = $this->buildSegmentQuery($segment);
        $count = $query->count();
        $segment->forceFill([
            'estimated_size' => $count,
            'last_calculated_at' => now(),
        ])->save();

        return $segment;
    }

    protected function buildSegmentQuery(CampaignSegment $segment): Builder
    {
        $filters = $segment->filters ?? [];
        $query = $this->baseUserQuery();

        if (!empty($filters['account_types']) && is_array($filters['account_types'])) {
            $query->whereIn('account_type', $filters['account_types']);
        }

        if (!empty($filters['minimum_orders'])) {
            $query->whereHas('orders', function ($q) {
                $q->whereNull('orders.deleted_at');
            }, '>=', (int) $filters['minimum_orders']);
        }

        if (!empty($filters['minimum_spent'])) {
            $minSpent = (float) $filters['minimum_spent'];
            $query->whereIn('id', function ($sub) use ($minSpent) {
                $sub->select('user_id')
                    ->from('orders')
                    ->whereNull('deleted_at')
                    ->groupBy('user_id')
                    ->havingRaw('SUM(final_amount) >= ?', [$minSpent]);
            });
        }

        if (!empty($filters['inactive_days'])) {
            $query->where('updated_at', '<=', now()->subDays((int) $filters['inactive_days']));
        }

        if (!empty($filters['minimum_referrals'])) {
            $minReferrals = (int) $filters['minimum_referrals'];
            $query->whereIn('id', function ($sub) use ($minReferrals) {
                $sub->select('referrer_id')
                    ->from('referrals')
                    ->groupBy('referrer_id')
                    ->havingRaw('COUNT(*) >= ?', [$minReferrals]);
            });
        }

        if (!empty($filters['minimum_points'])) {
            $minPoints = (int) $filters['minimum_points'];
            $query->whereIn('id', function ($sub) use ($minPoints) {
                $sub->select('referrer_id')
                    ->from('referrals')
                    ->groupBy('referrer_id')
                    ->havingRaw('SUM(points) >= ?', [$minPoints]);
            });
        }

        if (!empty($filters['purchased_item_ids']) && is_array($filters['purchased_item_ids'])) {
            $query->whereHas('orders.items', function ($q) use ($filters) {
                $q->whereIn('item_id', $filters['purchased_item_ids']);
            });
        }

        if (!empty($filters['last_order_status'])) {
            $query->whereHas('orders', function ($q) use ($filters) {
                $q->where('order_status', $filters['last_order_status']);
            });
        }

        return $query;
    }

    protected function baseUserQuery(): Builder
    {
        return User::query()->where('notification', 1);
    }

    protected function extractCampaignData(array $data): array
    {
        $campaignData = Arr::only($data, [
            'name',
            'slug',
            'status',
            'trigger_type',
            'event_key',
            'scheduled_at',
            'timezone',
            'notification_title',
            'notification_body',
            'cta_label',
            'cta_destination',
            'metadata',
        ]);

        if (!empty($campaignData['scheduled_at'])) {
            $campaignData['scheduled_at'] = Carbon::parse($campaignData['scheduled_at']);
        }

        if (!empty($campaignData['metadata']) && is_string($campaignData['metadata'])) {
            $campaignData['metadata'] = json_decode($campaignData['metadata'], true) ?: [];
        }

        return $campaignData;
    }
}