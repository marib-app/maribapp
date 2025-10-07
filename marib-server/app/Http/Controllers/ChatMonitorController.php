<?php

namespace App\Http\Controllers;

use App\Models\User;
use App\Models\Chat;
use App\Models\ChatMessage;


use App\Models\DepartmentTicket;
use App\Services\DepartmentReportService;
use App\Services\ResponseService;
use Carbon\Carbon;
use Illuminate\Support\Facades\Auth;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Spatie\Permission\Models\Permission;

class ChatMonitorController extends Controller
{



    protected DepartmentReportService $departmentReportService;

    protected array $departmentCategoriesCache = [];

    /**
     * إنشاء مثيل جديد للمتحكم
     */
    public function __construct(DepartmentReportService $departmentReportService)
    {

                $this->departmentReportService = $departmentReportService;

        // لا حاجة لـ middleware هنا، سيتم فحص الصلاحيات في كل دالة
    }
    
    /**
     * عرض الصفحة الرئيسية لمراقبة المحادثات
     */
    public function index(Request $request, ?string $department = null)
    {
        ResponseService::noAnyPermissionThenRedirect(['chat-monitor-list']);
        // التحقق من وجود معلمة اللغة وتعيينها
        if ($request->has('locale')) {
            app()->setLocale($request->locale);
            // تخزين اللغة في الجلسة
            $language = \App\Models\Language::where('code', $request->locale)->first();
            if ($language) {
                \Illuminate\Support\Facades\Session::put('locale', $language->code);
                \Illuminate\Support\Facades\Session::put('language', (object) $language->toArray());
                \Illuminate\Support\Facades\Session::save();
            }
        }
        
        // إحصائيات عامة
        $totalMessages = ChatMessage::count();
        $totalUsers = User::count();
        
        $department = $this->normalizeDepartment($department ?? $request->get('department'));
        $availableDepartments = $this->departmentReportService->availableDepartments();
        $ticketStatus = $request->get('ticket_status');
        

        $query = Chat::query()
            ->with([
                'latestMessage',
                'participants',
                'assignedAgent',
                'itemOffer.item' => function ($builder) {
                    $builder->withTrashed();
                },
            ])


            ->withCount('messages')
            ->withMax('messages as last_message_created_at', 'created_at')
            ->whereHas('messages');



        $categoryIds = $department ? $this->getDepartmentCategoryIds($department) : [];

        if ($department) {
            if (empty($categoryIds)) {
                $query->whereRaw('0 = 1');
            } else {
                $query
                    ->where(function ($q) use ($department) {
                        $q->whereNull('department')->orWhere('department', $department);
                    })
                    ->whereHas('itemOffer.item', function ($itemQuery) use ($categoryIds) {
                        $itemQuery->whereIn('category_id', $categoryIds);
                    });
            }
        }



        if ($request->filled('user_id')) {
            $query->whereHas('participants', function ($q) use ($request) {
                $q->where('users.id', $request->user_id);
            });
        
        }
        
        if ($request->filled('date_from')) {
            $from = Carbon::parse($request->date_from)->startOfDay();
            $query->whereHas('messages', function ($q) use ($from) {
                $q->where('created_at', '>=', $from);
            });
        
        
        
        }
        
        if ($request->filled('date_to')) {
            $to = Carbon::parse($request->date_to)->endOfDay();
            $query->whereHas('messages', function ($q) use ($to) {
                $q->where('created_at', '<=', $to);
            });
        
        
        }
        




        if ($request->filled('keyword')) {
            $keyword = $request->keyword;
            $query->whereHas('messages', function ($q) use ($keyword) {
                $q->where('message', 'like', '%' . $keyword . '%');



            });
        }
        


        $conversations = $query->orderByDesc('last_message_created_at')
            ->paginate(15)
            ->withQueryString();

        $conversationsData = $conversations->getCollection()->map(function (Chat $conversation) {
            $this->syncConversationDepartment($conversation);

        




            $latestMessage = $conversation->latestMessage;
            $timestamp = $latestMessage?->created_at ?? $conversation->updated_at ?? $conversation->created_at;

            return [
                'id' => $conversation->item_offer_id,
                'conversation_id' => $conversation->id,
                'sender_id' => $latestMessage?->sender_id,
                'participant_ids' => $conversation->participants->pluck('id')->toArray(),
                'created_at' => optional($timestamp)->toDateTimeString(),
                'total_messages' => $conversation->messages_count,
                'last_message' => $latestMessage?->message ?? '',
                'item_offer_id' => $conversation->item_offer_id,
                'department' => $conversation->department,
                'assigned_to' => $conversation->assigned_to,
                'assigned_agent' => $conversation->assignedAgent,

            ];


        })->values()->toArray();


        $userIds = collect($conversationsData)
            ->flatMap(function ($conversation) {
                return array_merge(
                    $conversation['participant_ids'] ?? [],
                    array_filter([
                        $conversation['sender_id'] ?? null,
                        $conversation['assigned_to'] ?? null,
                    ])
                
                );
            
            
            })
            ->filter()
            ->unique()
            ->values()
            ->toArray();
        
        $users = User::whereIn('id', $userIds)->get()->keyBy('id');
        


        foreach ($conversationsData as &$conversation) {
            $conversation['sender'] = $conversation['sender_id'] ? ($users[$conversation['sender_id']] ?? null) : null;
            $conversation['participants'] = collect($conversation['participant_ids'] ?? [])
                ->map(function ($userId) use ($users) {
                    return $users[$userId] ?? null;
                })
                ->filter()
                ->values()
                ->all();

                            $conversation['assigned_agent'] = $conversation['assigned_to'] ? ($users[$conversation['assigned_to']] ?? null) : null;

        }
        


                     unset($conversation);


        
        // الحصول على قائمة المستخدمين للفلتر (بدون تكرار)
        $allUsers = User::orderBy('name')->get()->unique('id');



        
        $assignableAgents = collect();
        if (Permission::where('name', 'chat-monitor-list')->exists()) {
            try {
                $assignableAgents = User::permission('chat-monitor-list')->orderBy('name')->get();
            } catch (\Throwable $exception) {
                \Log::warning('Failed to retrieve chat monitor assignable agents', [
                    'error' => $exception->getMessage(),
                ]);
                $assignableAgents = collect();
            }
        }

        
        $tickets = DepartmentTicket::with(['reporter', 'assignedAgent', 'conversation'])
            ->department($department)
            ->status($ticketStatus)
            ->latest()
            ->paginate(10, ['*'], 'tickets_page')
            ->withQueryString();

        $ticketsStats = DepartmentTicket::select('status', DB::raw('COUNT(*) as total'))
            ->department($department)
            ->groupBy('status')
            ->pluck('total', 'status');

        return view('chat_monitor.index', compact(
            'conversationsData',
            'allUsers',
            'totalMessages',
            'totalUsers',
            'users',
            'conversations',
            'assignableAgents',
            'department',
            'availableDepartments',
            'tickets',
            'ticketStatus',
            'ticketsStats'
        ));


    }
    
 
    
    public function conversations(Request $request)
    {
        // توجيه المستخدم مباشرة إلى الصفحة الرئيسية
        return redirect()->route('chat-monitor.index', $request->query());
    }







       public function assign(Request $request, Chat $conversation)
    {
        ResponseService::noAnyPermissionThenRedirect(['chat-monitor-list']);

        $data = $request->validate([
            'assigned_to' => ['nullable', 'exists:users,id'],
        ]);

        $conversation->assigned_to = $data['assigned_to'] ?? null;
        $resolvedDepartment = $this->determineConversationDepartment($conversation);
        if ($resolvedDepartment) {
            $conversation->department = $resolvedDepartment;
        }
        $conversation->save();

        return back()->with('success', 'تم تحديث المندوب المسؤول عن المحادثة.');
    }

    public function storeTicket(Request $request)
    {
        ResponseService::noAnyPermissionThenRedirect(['chat-monitor-list']);

        $validated = $request->validate([
            'department' => ['nullable', 'string'],
            'subject' => ['required', 'string', 'max:255'],
            'description' => ['nullable', 'string'],
            'chat_conversation_id' => ['nullable', 'exists:chat_conversations,id'],
            'order_id' => ['nullable', 'exists:orders,id'],
            'item_id' => ['nullable', 'exists:items,id'],
            'assigned_to' => ['nullable', 'exists:users,id'],
        ]);

        $department = $this->normalizeDepartment($validated['department'] ?? null) ?? 'general';

        if (!empty($validated['chat_conversation_id'])) {
            $conversation = Chat::find($validated['chat_conversation_id']);
            if ($conversation) {
                $resolved = $this->determineConversationDepartment($conversation);
                if ($resolved) {
                    $department = $resolved;
                }
            }
        }

        DepartmentTicket::create([
            'department' => $department,
            'subject' => $validated['subject'],
            'description' => $validated['description'] ?? null,
            'chat_conversation_id' => $validated['chat_conversation_id'] ?? null,
            'order_id' => $validated['order_id'] ?? null,
            'item_id' => $validated['item_id'] ?? null,
            'reporter_id' => Auth::id(),
            'assigned_to' => $validated['assigned_to'] ?? null,
            'status' => DepartmentTicket::STATUS_OPEN,
        ]);

        return back()->with('success', 'تم تسجيل البلاغ بنجاح.');
    }

    public function updateTicketStatus(Request $request, DepartmentTicket $ticket)
    {
        ResponseService::noAnyPermissionThenRedirect(['chat-monitor-list']);

        $validated = $request->validate([
            'status' => ['required', 'in:' . implode(',', [
                DepartmentTicket::STATUS_OPEN,
                DepartmentTicket::STATUS_IN_PROGRESS,
                DepartmentTicket::STATUS_RESOLVED,
            ])],
            'assigned_to' => ['nullable', 'exists:users,id'],
        ]);

        $ticket->status = $validated['status'];
        $ticket->assigned_to = $validated['assigned_to'] ?? $ticket->assigned_to;
        $ticket->resolved_at = $ticket->status === DepartmentTicket::STATUS_RESOLVED ? now() : null;
        $ticket->save();

        return back()->with('success', 'تم تحديث حالة البلاغ.');
    }

    protected function getDepartmentCategoryIds(string $department): array
    {
        if (!array_key_exists($department, $this->departmentCategoriesCache)) {
            $this->departmentCategoriesCache[$department] = $this->departmentReportService->resolveCategoryIds($department);
        }

        return $this->departmentCategoriesCache[$department];
    }

    protected function normalizeDepartment(?string $department): ?string
    {
        if (empty($department)) {
            return null;
        }

        $department = strtolower($department);
        $available = array_keys($this->departmentReportService->availableDepartments());

        return in_array($department, $available, true) ? $department : null;
    }

    protected function determineConversationDepartment(Chat $conversation): ?string
    {
        if ($conversation->department) {
            return $conversation->department;
        }

        $conversation->loadMissing('itemOffer.item');
        $item = $conversation->itemOffer?->item;

        if (!$item) {
            return null;
        }

        foreach (array_keys($this->departmentReportService->availableDepartments()) as $departmentKey) {
            $categoryIds = $this->getDepartmentCategoryIds($departmentKey);
            if (!empty($categoryIds) && in_array((int) $item->category_id, $categoryIds, true)) {
                return $departmentKey;
            }
        }

        return null;
    }

    protected function syncConversationDepartment(Chat $conversation): void
    {
        $resolved = $this->determineConversationDepartment($conversation);

        if ($resolved && $conversation->department !== $resolved) {
            $conversation->department = $resolved;
            $conversation->save();
        }
    }

    
    
    /**
     * عرض محادثة معينة
     */
    public function viewConversation($id, Request $request)
    {
        try {
            \Log::info('View conversation request', ['id' => $id, 'is_ajax' => $request->ajax()]);

            $conversation = Chat::with([
                'messages' => function ($query) {
                    $query->orderBy('created_at', 'asc');
                },
                'participants'
            ])->where('item_offer_id', $id)->first();

            if (!$conversation && is_numeric($id)) {
                $conversation = Chat::with([
                    'messages' => function ($query) {
                        $query->orderBy('created_at', 'asc');
                    },
                    'participants'
                ])->find($id);
            }

            if (!$conversation) {



                \Log::warning('Conversation not found', ['id' => $id]);
                
                if ($request->ajax() || $request->wantsJson() || $request->header('X-Requested-With') == 'XMLHttpRequest') {
                    return response()->json(['error' => 'المحادثة غير موجودة'], 404);
                }
                abort(404, 'المحادثة غير موجودة');
            }
            

            $messages = $conversation->messages;

            \Log::info('Conversation found', [
                'item_offer_id' => $conversation->item_offer_id,
                'conversation_id' => $conversation->id,
                'messages_count' => $messages->count()
            ]);

            $userIds = $conversation->participants->pluck('id')
                ->merge($messages->pluck('sender_id'))
                ->unique()
                ->values();




            $users = User::whereIn('id', $userIds)->get();
            
            \Log::info('Users found', ['count' => $users->count(), 'ids' => $userIds]);
            



            $usersArray = [];
            foreach ($users as $user) {
                $usersArray[$user->id] = [
                    'id' => $user->id,
                    'name' => $user->name,
                    'email' => $user->email,
                    'image' => $user->image ? url($user->image) : null
                ];
            }
            
            // إعداد البيانات للرد
            $responseData = [
                'id' => $conversation->item_offer_id,
                'conversation_id' => $conversation->id,
                'chats' => $messages->values()->toArray(),

                'users' => $usersArray
            ];
            
            // التحقق مما إذا كان الطلب AJAX أو يريد JSON
            if ($request->ajax() || $request->wantsJson() || $request->header('X-Requested-With') == 'XMLHttpRequest') {
                \Log::info('Returning JSON response', ['data_size' => strlen(json_encode($responseData))]);
                return response()->json($responseData);
            }
            
            // إعادة توجيه إلى الصفحة الرئيسية مع تحديد محادثة
            return redirect()->route('chat-monitor.index', ['conversation_id' => $conversation->item_offer_id]);



        } catch (\Exception $e) {
            \Log::error('Error in viewConversation', [
                'id' => $id,
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString()
            ]);
            
            if ($request->ajax() || $request->wantsJson() || $request->header('X-Requested-With') == 'XMLHttpRequest') {
                return response()->json([
                    'error' => 'حدث خطأ أثناء تحميل المحادثة',
                    'message' => $e->getMessage()
                ], 500);
            }
            
            abort(500, 'حدث خطأ أثناء تحميل المحادثة');
        }
    }
    
    /**
     * حذف محادثة
     */
    public function deleteConversation($id)
    {
        $conversation = Chat::where('item_offer_id', $id)->first();

        if (!$conversation && is_numeric($id)) {
            $conversation = Chat::find($id);
        }

        if (!$conversation) {



            abort(404, 'المحادثة غير موجودة');
        }

                $conversation->delete();

        
        return redirect()->route('chat-monitor.index')
            ->with('success', 'تم حذف المحادثة بنجاح');
    }
    
    /**
     * عرض صفحة البحث
     */
    public function search(Request $request)
    {
        $results = null;
        $users = User::orderBy('name')->get();
        
        if ($request->filled('keyword') || $request->filled('user_id') ||
            $request->filled('date_from') || $request->filled('date_to') ||
            $request->filled('message_type')) {
            

            $query = ChatMessage::with(['sender', 'conversation.participants'])
            
            
            
            ->when($request->filled('keyword'), function ($q) use ($request) {
                    $keyword = $request->keyword;
                    return $q->where(function ($query) use ($keyword) {
                        $query->where('message', 'like', '%' . $keyword . '%');
                    });
                
                
                
                })
                ->when($request->filled('user_id'), function ($q) use ($request) {
                    return $q->where('sender_id', $request->user_id);
                })
                ->when($request->filled('message_type'), function ($q) use ($request) {
                    if ($request->message_type === 'text') {
                        return $q->where(function ($query) {
                            $query->whereNotNull('message')
                                ->where('message', '<>', '')
                                ->whereNull('file')
                                ->whereNull('audio');
                        });
                    }

                    if ($request->message_type === 'file') {
                        return $q->where(function ($query) {
                            $query->whereNotNull('file')
                                ->orWhere('file', '<>', '');
                        });
                    }

                    if ($request->message_type === 'audio') {




                        return $q->whereNotNull('audio');
                    }


                                        return $q;



                })
                ->when($request->filled('date_from'), function ($q) use ($request) {
                    return $q->where('created_at', '>=', Carbon::parse($request->date_from)->startOfDay());
                })
                ->when($request->filled('date_to'), function ($q) use ($request) {
                    return $q->where('created_at', '<=', Carbon::parse($request->date_to)->endOfDay());
                })
                ->latest('created_at');
                
            $results = $query->paginate(20);
        }
        
        return view('chat_monitor.search', compact('results', 'users'));
    }
    
    /**
     * عرض الإحصائيات المفصلة
     */
    public function statistics()
    {
        // الإحصائيات العامة
        $stats = [
            'total' => ChatMessage::count(),
            'today' => ChatMessage::whereDate('created_at', today())->count(),
            'week' => ChatMessage::where('created_at', '>=', now()->subWeek())->count(),
            'month' => ChatMessage::where('created_at', '>=', now()->subMonth())->count(),
            'text_messages' => ChatMessage::where(function ($query) {
                    $query->whereNotNull('message')
                        ->where('message', '<>', '')
                        ->whereNull('file')
                        ->whereNull('audio');
                })->count(),
            'file_messages' => ChatMessage::where(function ($query) {
                    $query->whereNotNull('file')->where('file', '<>', '');
                })->count(),
            'audio_messages' => ChatMessage::where(function ($query) {
                    $query->whereNotNull('audio')->where('audio', '<>', '');
                })->count(),
        ];
        
        // إحصائيات المحادثات اليومية (آخر 30 يوم)
        $chatsByDay = ChatMessage::select(


            DB::raw('DATE(created_at) as date'),
                DB::raw('count(*) as total')
            )
            ->where('created_at', '>=', now()->subDays(30))
            ->groupBy('date')
            ->orderBy('date')
            ->get();
            
        // أكثر المستخدمين نشاطاً
        $topUserIds = ChatMessage::select('sender_id', DB::raw('count(*) as total'))

                       ->groupBy('sender_id')
                       ->orderByDesc('total')
                       ->limit(10)
                       ->get();
                       
        $users = User::whereIn('id', $topUserIds->pluck('sender_id'))->get()->keyBy('id');
        
        $topUsers = $topUserIds->map(function ($item) use ($users) {
            return [
                'user' => $users[$item->sender_id] ?? null,
                'total' => $item->total,
            ];
        });
            
        return view('chat_monitor.statistics', compact('stats', 'chatsByDay', 'topUsers'));
    }
}