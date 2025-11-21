<?php

namespace App\Http\Controllers;
use App\Events\AdminDashboardNotification;

use App\Data\Notifications\NotificationIntent;
use App\Enums\NotificationType;
use App\Models\Item;
use App\Models\Notifications;
use App\Models\User;
use App\Services\BootstrapTableService;
use App\Services\FileService;
use App\Services\MarketingNotificationService;
use App\Services\NotificationDispatchService;
use App\Services\ResponseService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Validator;

use Throwable;


class NotificationController extends Controller {

    private string $uploadFolder;

    public function __construct() {
        $this->uploadFolder = "notification";
    }

    public function index(MarketingNotificationService $marketingNotificationService) {
        ResponseService::noAnyPermissionThenRedirect(['notification-list', 'notification-create', 'notification-update', 'notification-delete']);
        $item_list = Item::approved()->get();
        $overview = $marketingNotificationService->getOverviewData();
        $automationEvents = [
            ['key' => 'user.inactive', 'label' => __('Inactivity (no sessions)')],
            ['key' => 'subscription.expired', 'label' => __('Package expiration')],
            ['key' => 'competition.announced', 'label' => __('Competition or challenge')],
        ];

        return view('notification.index', [
            'item_list' => $item_list,
            'campaigns' => $overview['campaigns'],
            'dashboardMetrics' => $overview['metrics'],
            'recentDeliveries' => $overview['recent_deliveries'],
            'automationEvents' => $automationEvents,
        ]);
    
    
    }

    public function store(Request $request) {
        ResponseService::noPermissionThenSendJson('notification-create');
        $validator = Validator::make($request->all(), [
            'file'    => 'image|mimes:jpeg,png,jpg',
            'send_to' => 'required|in:all,selected,individual,business,real_estate',
            'user_id' => 'required_if:send_to,selected',
            'title'   => 'required',
            'message' => 'required',
        ],
            [
                'user_id' => [
                    'required_if' => __("Please select at least one user")
                ]
            ]
        );

        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }
        try {
            \Log::info('NotificationController: Starting notification send process', [
                'send_to' => $request->send_to,
                'title' => $request->title,
                'user_id' => $request->user_id ?? 'N/A'
            ]);
            
            if (method_exists(NotificationService::class, 'validateHttpV1Configuration')) {
                $configCheck = NotificationService::validateHttpV1Configuration();
                if ($configCheck['error']) {
                    \Log::error('NotificationController: FCM prerequisites failed', $configCheck);
                    ResponseService::warningResponse($configCheck['message'], $configCheck);
                    return;
                }
            } else {
                \Log::warning('NotificationController: validateHttpV1Configuration method is unavailable on NotificationService');



            }
            $notification = Notifications::create([
                ...$request->all(),
                'image'   => $request->hasFile('file') ? FileService::compressAndUpload($request->file('file'), $this->uploadFolder) : '',
                'user_id' => $request->send_to == "selected" ? $request->user_id : ''
            ]);

            $broadcastPayload = $notification->only(['id', 'title', 'message', 'image', 'send_to', 'item_id']);
            $broadcastPayload['created_at'] = optional($notification->created_at)->toIso8601String();

            broadcast(new AdminDashboardNotification($broadcastPayload));   

            $recipientIds = $this->resolveTargetUserIds($request);
            \Log::info('NotificationController: resolved recipients', [
                'count' => count($recipientIds),
            ]);

            if (!empty($recipientIds)) {
                $this->dispatchBroadcastNotifications(
                    $recipientIds,
                    $request->title,
                    $request->message,
                    [
                        'image' => $notification->image,
                        'item_id' => $notification->item_id,
                        'deeplink' => $this->resolveDeeplink($notification),
                        'notification_id' => $notification->id,
                        'send_to' => $request->send_to,
                    ]
                );
            } else {
                \Log::warning('NotificationController: No recipients found for broadcast');
            }

            ResponseService::successResponse('Message Send Successfully', $notification);

        } catch (Throwable $th) {
            \Log::error('NotificationController: Exception occurred', [
                'error' => $th->getMessage(),
                'file' => $th->getFile(),
                'line' => $th->getLine(),
                'trace' => $th->getTraceAsString()
            ]);
            ResponseService::logErrorResponse($th, 'NotificationController -> store');
            ResponseService::errorResponse(
                $th->getMessage(),
                ['error' => true, 'code' => $th->getCode()],
                $th->getCode() ?: null,
                $th
            );
        
            }
    }

    public function destroy($id) {
        try {
            ResponseService::noPermissionThenSendJson('notification-delete');
            $notification = Notifications::findOrFail($id);
            $notification->delete();
            FileService::delete($notification->getRawOriginal('image'));
            ResponseService::successResponse('Notification Deleted successfully');
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, 'NotificationController -> destroy');
            ResponseService::errorResponse('Something Went Wrong');
        }
    }

    public function show(Request $request) {
        ResponseService::noPermissionThenSendJson('notification-list');
        $offset = $request->offset ?? 0;
        $limit = $request->limit ?? 10;
        $sort = $request->sort ?? 'id';
        $order = $request->order ?? 'DESC';

        $sql = Notifications::where('id', '!=', 0)->orderBy($sort, $order);

        if (!empty($request->search)) {
            $sql = $sql->search($request->search);
        }

        $total = $sql->count();
        $sql->skip($offset)->take($limit);
        $result = $sql->get();
        $bulkData = array();
        $bulkData['total'] = $total;
        $rows = array();
        foreach ($result as $key => $row) {
            $tempRow = $row->toArray();
            $operate = '';

            if (Auth::user()->can('notification-delete')) {
                $operate .= BootstrapTableService::deleteButton(route('notification.destroy', $row->id));
            }
            $tempRow['operate'] = $operate;
            $rows[] = $tempRow;
        }

        $bulkData['rows'] = $rows;
        return response()->json($bulkData);
    }

    public function batchDelete(Request $request) {
        ResponseService::noPermissionThenSendJson('notification-delete');
        try {
            foreach (Notifications::whereIn('id', explode(',', $request->id))->get() as $row) {
                $row->delete();
                FileService::delete($row->getRawOriginal('image'));

            }
            ResponseService::successResponse("Notification deleted successfully");
        } catch (Throwable $th) {
            ResponseService::logErrorResponse($th, "NotificationController -> batchDelete");
            ResponseService::errorResponse();
        }
    }

    private function resolveTargetUserIds(Request $request): array
    {
        if ($request->send_to === 'selected') {
            $ids = array_filter(
                array_map('trim', explode(',', (string) $request->user_id))
            );

            return array_map('intval', $ids);
        }

        $query = User::query()->where('notification', 1);

        if (in_array($request->send_to, Notifications::ACCOUNT_TYPE_RECIPIENTS, true)) {
            $query->where('account_type', $this->mapAccountType($request->send_to));
        }

        return $query->pluck('id')->map(fn ($id) => (int) $id)->all();
    }

    private function dispatchBroadcastNotifications(array $userIds, string $title, string $body, array $data): void
    {
        $dispatcher = app(NotificationDispatchService::class);
        $deeplink = (string) ($data['deeplink'] ?? 'marib://notifications');

        foreach (array_chunk($userIds, 500) as $chunk) {
            foreach ($chunk as $userId) {
                $intent = new NotificationIntent(
                    userId: $userId,
                    type: NotificationType::BroadcastMarketing,
                    title: $title,
                    body: $body,
                    deeplink: $deeplink,
                    entity: 'notification',
                    entityId: $data['notification_id'] ?? null,
                    data: $data,
                );
                $dispatcher->dispatch($intent, true);
            }
        }
    }

    private function resolveDeeplink(Notifications $notification): string
    {
        if (!empty($notification->item_id)) {
            return sprintf('marib://item/%s', $notification->item_id);
        }

        return 'marib://notifications';
    }

    private function mapAccountType(string $value): int
    {
        return match ($value) {
            'business' => User::ACCOUNT_TYPE_SELLER,
            'real_estate' => User::ACCOUNT_TYPE_REAL_ESTATE,
            default => User::ACCOUNT_TYPE_CUSTOMER,
        };
    }
}

