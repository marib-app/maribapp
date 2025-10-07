<?php

namespace App\Http\Controllers;
use App\Events\AdminDashboardNotification;

use App\Models\Item;
use App\Models\Notifications;
use App\Models\UserFcmToken;
use App\Services\BootstrapTableService;
use App\Services\FileService;
use App\Services\MarketingNotificationService;
use App\Services\NotificationService;
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

            
            if ($request->send_to == "selected") {
                // إرسال للمستخدمين المحددين
                \Log::info('NotificationController: Sending to selected users', ['user_ids' => $request->user_id]);
                $fcm_ids = UserFcmToken::select('fcm_token')->whereIn('user_id', explode(',', $request->user_id))->pluck('fcm_token')->toArray();
            } else if (in_array($request->send_to, Notifications::ACCOUNT_TYPE_RECIPIENTS, true)) {
                // إرسال حسب نوع الحساب (فردي، تجاري، عقاري)
                \Log::info('NotificationController: Sending to account type', ['account_type' => $request->send_to]);
                $fcm_ids = UserFcmToken::whereHas('user', function ($q) use ($request) {
                    $q->where('notification', 1)->where('account_type', $request->send_to);
                })->select('fcm_token')->pluck('fcm_token')->toArray();
            } else {
                // إرسال للجميع
                \Log::info('NotificationController: Sending to all users');
                $fcm_ids = UserFcmToken::whereHas('user', static function ($q) {
                    $q->where('notification', 1);
                })->select('fcm_token')->pluck('fcm_token')->toArray();
            }
            
            \Log::info('NotificationController: FCM tokens retrieved', [
                'total_tokens' => count($fcm_ids),
                'tokens_sample' => array_slice($fcm_ids, 0, 3) // عرض أول 3 tokens فقط للأمان
            ]);
            
            if (!empty($fcm_ids)) {
                $registrationIDs = array_filter($fcm_ids);
                \Log::info('NotificationController: Filtered FCM tokens', [
                    'filtered_tokens_count' => count($registrationIDs)
                ]);
                
                \Log::info('NotificationController: Calling FCM service', [
                    'title' => $request->title,
                    'message' => $request->message,
                    'type' => 'notification'
                ]);
                
                $notification_result = NotificationService::sendFcmNotification($registrationIDs, $request->title, $request->message, "notification", [
                    "image"   => $notification->image,
                    "item_id" => $notification->item_id,
                ]);
                
                \Log::info('NotificationController: FCM service response', [
                    'success' => !$notification_result['error'],
                    'message' => $notification_result['message'] ?? 'No message',
                    'data' => isset($notification_result['data']) ? 'Data present' : 'No data'
                ]);

                if ($notification_result['error']) {
                    \Log::error('NotificationController: FCM sending failed', $notification_result);
                    ResponseService::warningResponse(
                        $notification_result['message'],
                        $notification_result,
                        $notification_result['code'] ?? null
                    );
                
                } else {
                    \Log::info('NotificationController: FCM sending successful');
                }
            } else {
                \Log::warning('NotificationController: No FCM tokens found for sending');
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
}
