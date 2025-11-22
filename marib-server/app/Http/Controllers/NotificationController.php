<?php

namespace App\Http\Controllers;
use App\Events\AdminDashboardNotification;

use App\Data\Notifications\NotificationIntent;
use App\Enums\NotificationType;
use App\Models\Blog;
use App\Models\Category;
use App\Models\Item;
use App\Models\Notifications;
use App\Models\Service;
use App\Models\User;
use App\Services\BootstrapTableService;
use App\Services\FileService;
use App\Services\NotificationDispatchService;
use App\Services\NotificationService;
use App\Services\ResponseService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

use Throwable;


class NotificationController extends Controller {

    private const TARGET_TYPES = [
        'inbox',
        'item',
        'category',
        'service',
        'blog',
        'screen',
        'custom_link',
        'deeplink',
    ];

    private const BROADCAST_CATEGORY_OPTIONS = [
        'account',
        'wallet',
        'updates',
        'marketing',
        'system',
    ];

    private string $uploadFolder;

    public function __construct() {
        $this->uploadFolder = "notification";
    }

    public function index() {
        ResponseService::noAnyPermissionThenRedirect(['notification-list', 'notification-create', 'notification-update', 'notification-delete']);

        return view('notification.index');
    }

    public function create() {
        ResponseService::noPermissionThenRedirect('notification-create');
        $item_list = Item::approved()->orderBy('name')->get(['id', 'name']);
        $categories = Category::orderBy('name')->get(['id', 'name']);
        $services = Service::orderBy('title')->get(['id', 'title']);
        $blogs = Blog::orderByDesc('created_at')->get(['id', 'title']);

        return view('notification.create', [
            'item_list' => $item_list,
            'categories' => $categories,
            'services' => $services,
            'blogs' => $blogs,
            'targetTypeLabels' => $this->targetTypeLabels(),
            'broadcastCategories' => $this->broadcastCategoryLabels(),
            'screenDestinations' => $this->screenDestinations(),
        ]);
    }

    public function store(Request $request) {
        ResponseService::noPermissionThenSendJson('notification-create');
        $targetTypes = array_keys($this->targetTypeLabels());
        $screenOptions = array_keys($this->screenDestinations());
        $targetScreenRule = ['required_if:target_type,screen', 'nullable', 'string', 'max:120'];

        if (! empty($screenOptions)) {
            $targetScreenRule[] = Rule::in($screenOptions);
        }

        $validator = Validator::make($request->all(), [
            'file'    => 'image|mimes:jpeg,png,jpg',
            'send_to' => ['required', Rule::in(['all', 'selected', 'individual', 'business', 'real_estate'])],
            'user_id' => 'required_if:send_to,selected',
            'title'   => 'required|string',
            'message' => 'required|string',
            'target_type' => ['required', Rule::in($targetTypes)],
            'category' => ['required', Rule::in(self::BROADCAST_CATEGORY_OPTIONS)],
            'target_item_id' => ['required_if:target_type,item', 'nullable', 'integer', 'exists:items,id'],
            'target_category_id' => ['required_if:target_type,category', 'nullable', 'integer', 'exists:categories,id'],
            'target_service_id' => ['required_if:target_type,service', 'nullable', 'integer', 'exists:services,id'],
            'target_blog_id' => ['required_if:target_type,blog', 'nullable', 'integer', 'exists:blogs,id'],
            'target_screen' => $targetScreenRule,
            'target_url' => ['required_if:target_type,custom_link', 'nullable', 'url', 'max:255'],
            'target_deeplink' => ['required_if:target_type,deeplink', 'nullable', 'string', 'max:255'],
            'cta_label' => ['nullable', 'string', 'max:60'],
            'cta_link' => ['nullable', 'url', 'max:255'],
            'request_payment' => ['sometimes', 'boolean'],
            'payment_amount' => ['required_if:request_payment,1', 'nullable', 'numeric', 'gt:0'],
            'payment_currency' => ['required_if:request_payment,1', 'nullable', 'string', 'size:3'],
            'payment_note' => ['nullable', 'string', 'max:200'],
            'payment_gateways' => ['nullable', 'array'],
            'payment_gateways.*' => ['string', 'max:50'],
        ], [
            'user_id.required_if' => __("Please select at least one user"),
            'target_item_id.required_if' => __("Please choose an item for this destination."),
            'target_category_id.required_if' => __("Please choose a category for this destination."),
            'target_service_id.required_if' => __("Please choose a service for this destination."),
            'category.required' => __("Please select the notification type."),
            'target_blog_id.required_if' => __("Please choose a blog article for this destination."),
            'target_screen.required_if' => __("Please choose an in-app screen."),
            'target_url.required_if' => __("Please provide a link for this destination."),
            'target_deeplink.required_if' => __("Please provide a deeplink."),
            'payment_amount.required_if' => __("Please provide the amount to request."),
            'payment_currency.required_if' => __("Please specify the currency for the requested payment."),
        ]);

        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }
        try {
            \Log::info('NotificationController: Starting notification send process', [
                'send_to' => $request->send_to,
                'title' => $request->title,
                'user_id' => $request->user_id ?? 'N/A',
                'target_type' => $request->target_type,
            ]);

            $itemId = $request->target_type === 'item'
                ? (int) $request->input('target_item_id')
                : null;
            $meta = $this->buildNotificationMeta($request, $itemId);
            $meta['source'] = 'manual-broadcast';
            $paymentRequest = $this->buildPaymentRequestMeta($request);
            if ($paymentRequest !== null) {
                if (! is_array($meta)) {
                    $meta = [];
                }
                $meta['payment_request'] = $paymentRequest;
            }
            
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
                'title' => $request->title,
                'message' => $request->message,
                'send_to' => $request->send_to,
                'item_id' => $itemId,
                'image'   => $request->hasFile('file') ? FileService::compressAndUpload($request->file('file'), $this->uploadFolder) : '',
                'user_id' => $request->send_to == "selected" ? $request->user_id : '',
                'category' => $request->input('category', 'system'),
                'meta' => ! empty($meta) ? $meta : null,
            ]);

            $broadcastPayload = $notification->only(['id', 'title', 'message', 'image', 'send_to', 'item_id', 'category', 'meta']);
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
                        'category' => $notification->category ?? 'general',
                        'meta' => $notification->meta ?? [],
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

        $sql = Notifications::query()
            ->withCount([
                'deliveries as delivered_count' => fn ($q) => $q->whereNotNull('delivered_at'),
                'deliveries as clicked_count' => fn ($q) => $q->whereNotNull('clicked_at'),
            ])
            ->orderBy($sort, $order);

        if (!empty($request->search)) {
            $sql = $sql->search($request->search);
        }

        $total = $sql->count();
        $sql->skip($offset)->take($limit);
        $result = $sql->get();
        $bulkData = array();
        $bulkData['total'] = $total;
        $rows = array();
        $categoryLabels = $this->broadcastCategoryLabels();

        foreach ($result as $key => $row) {
            $tempRow = $row->toArray();
            $tempRow['category'] = $categoryLabels[$row->category] ?? $row->category;
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
        $intentData = $data;
        $intentData['category'] = $data['category'] ?? 'general';
        $intentData['source'] = 'manual-broadcast';
        $metaPayload = $notification->meta ?? [];
        if (! empty($metaPayload['payment_request'])) {
            $intentData['payment_request'] = $metaPayload['payment_request'];
        }

        $metaPayload = $notification->meta ?? [];
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
                    data: $intentData,
                    meta: $metaPayload,
                );
                $dispatcher->dispatch($intent, true);
            }
        }
    }

    private function resolveDeeplink(Notifications $notification): string
    {
        $meta = $notification->meta ?? [];
        $target = is_array($meta) ? ($meta['target'] ?? null) : null;

        if (is_array($target)) {
            $type = $target['type'] ?? 'inbox';

            return match ($type) {
                'item' => ! empty($notification->item_id)
                    ? sprintf('marib://item/%s', $notification->item_id)
                    : 'marib://notifications',
                'category' => ! empty($target['category_id'])
                    ? sprintf('marib://category/%s', $target['category_id'])
                    : 'marib://notifications',
                'service' => ! empty($target['service_id'])
                    ? sprintf('marib://service/%s', $target['service_id'])
                    : 'marib://notifications',
                'blog' => ! empty($target['blog_id'])
                    ? sprintf('marib://blog/%s', $target['blog_id'])
                    : 'marib://notifications',
                'screen' => ! empty($target['screen'])
                    ? sprintf('marib://%s', ltrim((string) $target['screen'], '/'))
                    : 'marib://notifications',
                'custom_link' => ! empty($target['url'])
                    ? (string) $target['url']
                    : 'marib://notifications',
                'deeplink' => ! empty($target['deeplink'])
                    ? (string) $target['deeplink']
                    : 'marib://notifications',
                default => 'marib://notifications',
            };
        }

        if (!empty($notification->item_id)) {
            return sprintf('marib://item/%s', $notification->item_id);
        }

        return 'marib://notifications';
    }


    private function targetTypeLabels(): array
    {
        $labels = [
            'inbox' => __('توجيه إلى صندوق الإشعارات (افتراضي)'),
            'item' => __('عرض منتج معيّن'),
            'category' => __('عرض قسم أو تصنيف'),
            'service' => __('عرض خدمة'),
            'screen' => __('فتح شاشة داخل التطبيق'),
            'custom_link' => __('رابط خارجي (ويب)'),
            'deeplink' => __('رابط Deeplink مخصص'),
        ];

        $options = [];
        foreach (self::TARGET_TYPES as $type) {
            $options[$type] = $labels[$type] ?? $type;
        }

        return $options;
    }

    private function broadcastCategoryLabels(): array
    {
        return [
            'account' => __('الحساب والإعدادات'),
            'wallet' => __('المحفظة والمدفوعات'),
            'updates' => __('مستجدات التطبيق'),
            'marketing' => __('العروض والإعلانات'),
            'system' => __('تنبيهات النظام'),
        ];
    }

    private function screenDestinations(): array
    {
        return [
            'home' => __('الرئيسية'),
            'notifications' => __('قائمة الإشعارات'),
            'wallet' => __('المحفظة'),
            'orders' => __('طلباتي'),
            'chat' => __('الدردشة'),
            'profile' => __('ملفي الشخصي'),
        ];
    }

    private function buildPaymentRequestMeta(Request $request): ?array
    {
        if (! $request->boolean('request_payment')) {
            return null;
        }

        $amount = (float) $request->input('payment_amount', 0);
        if ($amount <= 0) {
            return null;
        }

        $currency = strtoupper(trim((string) $request->input('payment_currency', 'YER')));
        $note = trim((string) $request->input('payment_note', ''));
        $gateways = $request->input('payment_gateways');

        $allowedGateways = [];
        if (is_array($gateways)) {
            foreach ($gateways as $gateway) {
                if (! is_string($gateway)) {
                    continue;
                }
                $normalized = trim(strtolower($gateway));
                if ($normalized !== '') {
                    $allowedGateways[] = $normalized;
                }
            }
        }

        if (empty($allowedGateways)) {
            $allowedGateways = ['manual_bank', 'wallet', 'east_yemen_bank'];
        } else {
            $allowedGateways = array_values(array_unique($allowedGateways));
        }

        $timestamp = now()->toIso8601String();

        return array_filter([
            'id' => (string) Str::uuid(),
            'amount' => round($amount, 2),
            'currency' => $currency ?: 'YER',
            'status' => 'pending',
            'note' => $note !== '' ? $note : null,
            'allowed_gateways' => $allowedGateways,
            'created_at' => $timestamp,
            'updated_at' => $timestamp,
        ]);
    }

    private function buildNotificationMeta(Request $request, ?int $itemId): array
    {
        $targetType = $request->input('target_type', 'inbox');
        $target = [
            'type' => $targetType,
        ];

        if ($targetType === 'item' && $itemId) {
            $target['item_id'] = $itemId;
        } elseif ($targetType === 'category' && $request->filled('target_category_id')) {
            $target['category_id'] = (int) $request->input('target_category_id');
        } elseif ($targetType === 'service' && $request->filled('target_service_id')) {
            $target['service_id'] = (int) $request->input('target_service_id');
        } elseif ($targetType === 'blog' && $request->filled('target_blog_id')) {
            $target['blog_id'] = (int) $request->input('target_blog_id');
        } elseif ($targetType === 'screen' && $request->filled('target_screen')) {
            $target['screen'] = $request->input('target_screen');
        } elseif ($targetType === 'custom_link' && $request->filled('target_url')) {
            $target['url'] = $request->input('target_url');
        } elseif ($targetType === 'deeplink' && $request->filled('target_deeplink')) {
            $target['deeplink'] = $request->input('target_deeplink');
        }

        $cta = array_filter([
            'label' => $request->input('cta_label'),
            'link' => $request->input('cta_link'),
        ], fn ($value) => filled($value));

        return array_filter([
            'target' => $this->sanitizeMetaSection($target),
            'cta' => $cta,
        ]);
    }

    private function sanitizeMetaSection(array $value): array
    {
        $sanitized = [];

        foreach ($value as $key => $entry) {
            if (is_array($entry)) {
                $child = $this->sanitizeMetaSection($entry);
                if (! empty($child)) {
                    $sanitized[$key] = $child;
                }
                continue;
            }

            if ($entry === null || $entry === '') {
                continue;
            }

            $sanitized[$key] = $entry;
        }

        return $sanitized;
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

