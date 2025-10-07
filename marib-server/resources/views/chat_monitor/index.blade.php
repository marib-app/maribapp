@extends('layouts.main')

@section('title')
    {{ __('مراقبة المحادثات') }}
@endsection

@section('css')
<style>
    /* تنسيق عام للصفحة */
    .chat-container {
        background-color: #f5f5f5;
        border-radius: 8px;
        overflow: hidden;
        display: flex;
        height: 75vh;
        box-shadow: 0 5px 15px rgba(0,0,0,0.1);
        margin-bottom: 20px;
    }

    /* قائمة المحادثات */
    .conversations-list {
        width: 30%;
        background-color: #fff;
        border-right: 1px solid #e5e5e5;
        display: flex;
        flex-direction: column;
        overflow: hidden;
    }

    .conversation-search {
        padding: 10px;
        border-bottom: 1px solid #e5e5e5;
        background-color: #f8f8f8;
    }

    .conversations-container {
        flex-grow: 1;
        overflow-y: auto;
        scrollbar-width: thin;
    }

    .conversations-container::-webkit-scrollbar {
        width: 6px;
    }

    .conversations-container::-webkit-scrollbar-track {
        background: #f1f1f1;
    }

    .conversations-container::-webkit-scrollbar-thumb {
        background: #c1c1c1;
        border-radius: 10px;
    }

    .conversations-container::-webkit-scrollbar-thumb:hover {
        background: #a8a8a8;
    }

    .conversation-item {
        padding: 10px;
        border-bottom: 1px solid #f1f1f1;
        cursor: pointer;
        transition: all 0.2s;
    }

    .conversation-item:hover, .conversation-item.active {
        background-color: #f5f5f5;
    }

    .conversation-item .user-avatar {
        width: 50px;
        height: 50px;
        border-radius: 50%;
        object-fit: cover;
    }

    .conversation-item .message-preview {
        color: #888;
        font-size: 13px;
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
        max-width: 150px;
    }

    /* عرض المحادثة */
    .chat-view {
        width: 70%;
        display: flex;
        flex-direction: column;
        background-color: #f5f5f5;
        height: 100%;
    }

    .chat-header {
        padding: 15px;
        background-color: #fff;
        border-bottom: 1px solid #e5e5e5;
        display: flex;
        align-items: center;
    }

    .chat-header .user-avatar {
        width: 40px;
        height: 40px;
        border-radius: 50%;
        margin-right: 10px;
    }

    .chat-header .user-name {
        font-weight: bold;
        font-size: 16px;
        color: #435ebe;
    }

    .chat-header .conversation-id {
        font-size: 12px;
        color: #888;
        margin-top: 3px;
    }

    .messages-container {
        flex-grow: 1;
        overflow-y: auto;
        padding: 20px;
        height: calc(100% - 160px); /* خصم ارتفاع الهيدر والأكشن والعنوان */
        scrollbar-width: thin;
    }

    .messages-container::-webkit-scrollbar {
        width: 6px;
    }

    .messages-container::-webkit-scrollbar-track {
        background: #f1f1f1;
    }

    .messages-container::-webkit-scrollbar-thumb {
        background: #c1c1c1;
        border-radius: 10px;
    }

    .messages-container::-webkit-scrollbar-thumb:hover {
        background: #a8a8a8;
    }

    .message {
        margin-bottom: 12px;
        display: flex;
        flex-direction: column;
        width: 100%;
    }

    /* رسائل المستخدم الحالي (المرسل) - على اليمين */
    .message-sender {
        align-self: flex-end;
        max-width: 70%;
        background-color: #e3f2fd;
        border-radius: 18px 18px 0 18px;
        position: relative;
        padding: 12px 16px;
        box-shadow: 0 1px 2px rgba(0,0,0,0.1);
        text-align: right;
        margin-bottom: 8px;
    }
    
    /* رسائل المستخدمين الآخرين (المستقبل) - على اليسار */
    .message-receiver {
        align-self: flex-start;
        max-width: 70%;
        background-color: #ffffff;
        border-radius: 18px 18px 18px 0;
        position: relative;
        padding: 12px 16px;
        box-shadow: 0 1px 2px rgba(0,0,0,0.1);
        text-align: left;
        margin-bottom: 8px;
    }

    .message-username {
        font-weight: bold;
        font-size: 0.85rem;
        margin-bottom: 5px;
        color: #1f7aec;
    }
    
    /* تمييز اسم المرسل والمستقبل بألوان مختلفة */
    .message-sender .message-username {
        color: #0d6e0d;
    }
    
    .message-receiver .message-username {
        color: #1f7aec;
    }

    .message-text {
        word-break: break-word;
        white-space: pre-wrap;
        font-size: 14px;
        line-height: 1.5;
    }

    .message-time {
        text-align: right;
        font-size: 0.7rem;
        color: #999;
        margin-top: 5px;
    }

    .message-date {
        margin-left: 5px;
        font-size: 0.65rem;
        color: #aaa;
    }

    [dir="rtl"] .message-date {
        margin-left: 0;
        margin-right: 5px;
    }

    .message-media img {
        max-width: 200px;
        max-height: 150px;
        border-radius: 8px;
        cursor: pointer;
        margin-top: 8px;
    }

    .message-group {
        margin-bottom: 15px;
    }

    .empty-chat {
        display: flex;
        flex-direction: column;
        justify-content: center;
        align-items: center;
        height: 100%;
        color: #888;
        font-size: 16px;
        background-color: #f8f8f8;
    }

    .empty-chat i {
        font-size: 70px;
        margin-bottom: 20px;
        color: #999;
    }

    .chat-loading {
        display: flex;
        justify-content: center;
        align-items: center;
        height: 100%;
        font-size: 14px;
        color: #666;
    }

    .chat-actions {
        padding: 10px;
        background-color: #f0f0f0;
        border-top: 1px solid #e5e5e5;
        display: flex;
        justify-content: space-between;
    }

    /* للغة العربية */
    [dir="rtl"] .conversation-item .user-avatar,
    [dir="rtl"] .chat-header .user-avatar {
        margin-right: 0;
        margin-left: 10px;
    }

    /* تصحيح اتجاه الرسائل في وضع RTL */
    [dir="rtl"] .message-sender {
        align-self: flex-end;
        border-radius: 12px 0 12px 12px;
        text-align: left;
    }

    [dir="rtl"] .message-receiver {
        align-self: flex-start;
        border-radius: 0 12px 12px 12px;
        text-align: right;
    }

    [dir="rtl"] .message-time {
        float: left;
        margin-left: 0;
        margin-right: 8px;
    }

    @media (max-width: 768px) {
        .chat-container {
            flex-direction: column;
            height: auto;
        }

        .conversations-list,
        .chat-view {
            width: 100%;
            height: 50vh;
        }
    }
    
    /* تنسيق الفلاتر */
    .filters-card {
        margin-bottom: 20px;
    }
    
    .filters-card .form-label {
        font-weight: 600;
        margin-bottom: 8px;
        font-size: 1rem;
    }
    
    .filters-card .form-control,
    .filters-card .form-select {
        border-radius: 6px;
        padding: 12px 15px;
        height: auto;
        border: 1px solid #dce7f1;
        font-size: 1rem;
    }
    
    .filters-card .form-control:focus,
    .filters-card .form-select:focus {
        border-color: #435ebe;
        box-shadow: 0 0 0 0.25rem rgba(67, 94, 190, 0.1);
    }
    
    .filters-card .select2-container--bootstrap-5 .select2-selection {
        min-height: 50px;
        padding: 12px 15px;
        border: 1px solid #dce7f1;
        font-size: 1rem;
    }
    
    .filters-card .select2-container--bootstrap-5 .select2-selection--single .select2-selection__rendered {
        padding: 0;
        font-size: 1rem;
        line-height: 1.5;
    }
    
    .filters-card .select2-container--bootstrap-5.select2-container--focus .select2-selection {
        border-color: #435ebe;
        box-shadow: 0 0 0 0.25rem rgba(67, 94, 190, 0.1);
    }
    
    .select2-container--bootstrap-5 .select2-dropdown {
        border-color: #dce7f1;
        border-radius: 6px;
        box-shadow: 0 5px 15px rgba(0,0,0,0.1);
    }
    
    .select2-container--bootstrap-5 .select2-dropdown .select2-results__option {
        padding: 10px 15px;
        font-size: 1rem;
    }
    
    .select2-container--bootstrap-5 .select2-dropdown .select2-results__option--highlighted {
        background-color: #435ebe;
        color: white;
    }
    
    .filters-card .btn-actions {
        text-align: center;
        margin-top: 10px;
    }
    
    .filters-card .btn {
        padding: 12px 25px;
        font-weight: 600;
        border-radius: 6px;
        min-width: 140px;
        font-size: 1rem;
    }

    /* تنسيق الإحصائيات */
    .stats-card {
        border: none;
        border-radius: 10px;
        box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
        overflow: hidden;
        transition: transform 0.3s ease;
        height: 100%;
    }

    .stats-card:hover {
        transform: translateY(-5px);
        box-shadow: 0 10px 15px rgba(0, 0, 0, 0.1);
    }

    .stats-card .card-body {
        padding: 20px;
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
    }

    .stats-card .icon-container {
        display: flex;
        align-items: center;
        justify-content: center;
        width: 80px;
        height: 80px;
        border-radius: 50%;
        margin-bottom: 15px;
        margin-left: auto;
        margin-right: auto;
    }

    .stats-card .icon-container i {
        font-size: 32px;
        color: white;
        display: flex;
        align-items: center;
        justify-content: center;
        width: 100%;
        height: 100%;
    }

    .stats-card h2 {
        font-size: 32px;
        font-weight: 700;
        margin-bottom: 5px;
        text-align: center;
    }

    .stats-card p {
        font-size: 16px;
        color: #6c757d;
        margin-bottom: 0;
        text-align: center;
    }

    /* عناوين الأقسام */
    .list-header h5, .view-header h5 {
        font-size: 16px;
        font-weight: 600;
        color: #435ebe;
        margin: 0;
    }

    /* تنسيق الرسائل الصوتية والملفات */
    .message-file {
        margin-top: 10px;
    }
    
    .message-file a.btn {
        display: inline-flex;
        align-items: center;
        padding: 8px 12px;
        border-radius: 8px;
        background-color: #f8f9fa;
        border: 1px solid #e2e6ea;
        color: #495057;
        text-decoration: none;
        transition: all 0.2s;
        font-size: 14px;
    }
    
    .message-file a.btn:hover {
        background-color: #e2e6ea;
        border-color: #dae0e5;
    }
    
    .message-file a.btn i {
        margin-right: 8px;
        font-size: 16px;
        color: #435ebe;
    }
    
    [dir="rtl"] .message-file a.btn i {
        margin-right: 0;
        margin-left: 8px;
    }
</style>
@endsection


@section('content')
    <section class="section">




        <div class="mb-3">
            <ul class="nav nav-pills gap-2 flex-wrap">
                <li class="nav-item">
                    <a class="nav-link {{ $department ? '' : 'active' }}" href="{{ route('chat-monitor.index') }}">
                        <i class="bi bi-chat-square-dots me-1"></i>
                        {{ __('كل الأقسام') }}
                    </a>
                </li>
                @foreach($availableDepartments as $key => $label)
                    <li class="nav-item">
                        @php
                            $sectionRoute = $key === 'shein' ? route('item.shein.support') : ($key === 'computer' ? route('item.computer.support') : route('chat-monitor.index'));
                        @endphp
                        <a class="nav-link {{ $department === $key ? 'active' : '' }}" href="{{ $sectionRoute }}">
                            <i class="bi bi-collection me-1"></i>
                            {{ $label }}
                        </a>
                    </li>
                @endforeach
            </ul>
        </div>




        <!-- إحصائيات المحادثات -->
        <div class="row mb-4">
            <div class="col-md-6 col-12 mb-4">
                <div class="card stats-card">
                    <div class="card-body">
                        <div class="icon-container bg-primary">
                            <i class="bi bi-chat-dots"></i>
                        </div>
                        <h2>{{ number_format($totalMessages) }}</h2>
                        <p>{{ __('إجمالي الرسائل') }}</p>
                    </div>
                </div>
            </div>
            <div class="col-md-6 col-12 mb-4">
                <div class="card stats-card">
                    <div class="card-body">
                        <div class="icon-container bg-success">
                            <i class="bi bi-people"></i>
                        </div>
                        <h2>{{ number_format($totalUsers) }}</h2>
                        <p>{{ __('عدد المستخدمين') }}</p>
                    </div>
                </div>
            </div>






            <div class="col-md-6 col-12 mb-4">
                <div class="card stats-card">
                    <div class="card-body">
                        <div class="icon-container bg-warning text-dark">
                            <i class="bi bi-life-preserver"></i>
                        </div>
                        <h2>{{ $ticketsStats->get(\App\Models\DepartmentTicket::STATUS_OPEN, 0) }}</h2>
                        <p>{{ __('البلاغات المفتوحة') }}</p>
                    </div>
                </div>
            </div>
            <div class="col-md-6 col-12 mb-4">
                <div class="card stats-card">
                    <div class="card-body">
                        <div class="icon-container bg-info">
                            <i class="bi bi-check-circle"></i>
                        </div>
                        <h2>{{ $ticketsStats->sum() }}</h2>
                        <p>{{ __('إجمالي البلاغات المسجلة') }}</p>
                    </div>
                </div>
            </div>




        </div>
<!-- فلاتر البحث -->
<div class="card filters-card">
    <div class="card-header d-flex justify-content-between align-items-center">
        <h5>{{ __('تصفية المحادثات') }}</h5>
        <button class="btn btn-sm btn-outline-secondary" type="button" data-bs-toggle="collapse" data-bs-target="#filterCollapse" aria-expanded="false">
            <i class="bi bi-funnel"></i> {{ __('عرض/إخفاء الفلاتر') }}
        </button>
    </div>
    <div class="collapse show" id="filterCollapse">
        <div class="card-body">
            <form id="filter-form" action="{{ url()->current() }}" method="GET">
                @if($department)
                    <input type="hidden" name="department" value="{{ $department }}">
                @endif
                
                
                <div class="row g-3 mb-4 align-items-end">
                    <!-- المستخدم -->
                    {{-- <div class="col-md-3">
                        <label for="user_id" class="form-label fw-bold">{{ __('المستخدم') }}</label>
                        <select class="form-select form-select-lg" id="user_id" name="user_id">
                            <option value="">{{ __('جميع المستخدمين') }}</option>
                            @foreach($allUsers as $user)
                                <option value="{{ $user->id }}" {{ request('user_id') == $user->id ? 'selected' : '' }}>
                                    {{ $user->name }} ({{ $user->email }})
                                </option>
                            @endforeach
                        </select>
                    </div> --}}

                    <!-- من تاريخ -->
                    <div class="col-md-3">
                        <label for="date_from" class="form-label fw-bold">{{ __('من تاريخ') }}</label>
                        <input type="date" class="form-control form-control-lg" id="date_from" name="date_from" value="{{ request('date_from') }}">
                    </div>

                    <!-- إلى تاريخ -->
                    <div class="col-md-3">
                        <label for="date_to" class="form-label fw-bold">{{ __('إلى تاريخ') }}</label>
                        <input type="date" class="form-control form-control-lg" id="date_to" name="date_to" value="{{ request('date_to') }}">
                    </div>

                    <!-- بحث -->
                    <div class="col-md-3">
                        <label for="keyword" class="form-label fw-bold">{{ __('بحث في الرسائل') }}</label>
                        <input type="text" class="form-control form-control-lg" id="keyword" name="keyword" value="{{ request('keyword') }}" placeholder="{{ __('اكتب كلمة للبحث...') }}">
                    </div>





                    <div class="col-md-3">
                        <label for="ticket_status" class="form-label fw-bold">{{ __('حالة البلاغات') }}</label>
                        <select name="ticket_status" id="ticket_status" class="form-select form-select-lg">
                            <option value="">{{ __('كل الحالات') }}</option>
                            <option value="{{ \App\Models\DepartmentTicket::STATUS_OPEN }}" {{ request('ticket_status') === \App\Models\DepartmentTicket::STATUS_OPEN ? 'selected' : '' }}>{{ __('مفتوح') }}</option>
                            <option value="{{ \App\Models\DepartmentTicket::STATUS_IN_PROGRESS }}" {{ request('ticket_status') === \App\Models\DepartmentTicket::STATUS_IN_PROGRESS ? 'selected' : '' }}>{{ __('قيد المعالجة') }}</option>
                            <option value="{{ \App\Models\DepartmentTicket::STATUS_RESOLVED }}" {{ request('ticket_status') === \App\Models\DepartmentTicket::STATUS_RESOLVED ? 'selected' : '' }}>{{ __('مغلق') }}</option>
                        </select>
                    </div>


                </div>

                <!-- الأزرار -->
                <div class="row">
                    <div class="col-12 text-center">
                        <button type="submit" class="btn btn-lg btn-primary me-2">
                            <i class="bi bi-filter"></i> {{ __('تصفية') }}
                        </button>
                        <a href="{{ url()->current() }}" class="btn btn-lg btn-secondary">
                            <i class="bi bi-arrow-clockwise"></i> {{ __('إعادة تعيين') }}
                        </a>
                    </div>
                </div>
            </form>
        </div>
    </div>
</div>

        <!-- واجهة المحادثات على طريقة واتساب -->
        <div class="chat-container">
            <!-- قائمة المحادثات -->
            <div class="conversations-list">
                <div class="list-header">
                    <h5 class="mb-0 py-2 px-3 bg-light border-bottom">{{ __('قائمة المحادثات') }}</h5>
                </div>
                <div class="conversation-search">
                    <input type="text" class="form-control form-control-sm" id="search-conversations" placeholder="{{ __('بحث في المحادثات...') }}">
                </div>
                <div class="conversations-container">
                    @forelse($conversationsData as $conversation)
                        <div class="conversation-item" 
                             data-conversation-id="{{ $conversation['item_offer_id'] }}"
                             data-bs-toggle="tooltip" 
                             title="{{ __('انقر لعرض المحادثة') }}">
                            <div class="d-flex">
                                @if(count($conversation['participants']) >= 2)
                                    <img src="{{ $conversation['participants'][0]->image ?? asset('assets/images/no_image_available.png') }}" 
                                         class="user-avatar" alt="User" onerror="onErrorImage(event)">
                                @else
                                    <img src="{{ isset($conversation['sender']) ? ($conversation['sender']->image ?? asset('assets/images/no_image_available.png')) : asset('assets/images/no_image_available.png') }}" 
                                         class="user-avatar" alt="User" onerror="onErrorImage(event)">
                                @endif
                                <div class="ms-2 flex-grow-1">
                                    <div class="d-flex justify-content-between align-items-center">
                                        <div class="fw-bold">
                                            @if(count($conversation['participants']) >= 2)
                                                {{ $conversation['participants'][0]->name }} ⟷ {{ $conversation['participants'][1]->name }}
                                            @elseif(isset($conversation['sender']))
                                                {{ $conversation['sender']->name }}
                                            @else
                                                {{ __('مستخدم غير معروف') }}
                                            @endif
                                        </div>
                                        <span class="small text-muted conversation-time" data-time="{{ $conversation['created_at'] }}">
                                            {{ \Carbon\Carbon::parse($conversation['created_at'])->timezone('Asia/Riyadh')->format('d/m/Y H:i') }}
                                        </span>
                                    </div>
                                    <div class="message-preview">
                                        {{ $conversation['last_message'] ?: __('ملف مرفق') }}
                                    </div>




                                                                        @php
                                        $departmentLabel = $conversation['department']
                                            ? ($availableDepartments[$conversation['department']] ?? ($conversation['department'] === 'general' ? __('قسم عام') : $conversation['department']))
                                            : __('قسم عام');
                                    @endphp
                                    <div class="d-flex justify-content-between align-items-center mt-2">
                                        <span class="badge bg-light text-secondary border">
                                            {{ $departmentLabel }}
                                        </span>
                                        @if($conversation['assigned_agent'])
                                            <small class="text-muted">
                                                <i class="bi bi-person-check me-1"></i>
                                                {{ $conversation['assigned_agent']->name }}
                                            </small>
                                        @else
                                            <small class="text-muted">{{ __('غير مسند') }}</small>
                                        @endif
                                    </div>
                                    @if($assignableAgents->isNotEmpty())
                                        <form action="{{ route('chat-monitor.assign', $conversation['conversation_id']) }}" method="POST" class="mt-2">
                                            @csrf
                                            <div class="input-group input-group-sm">
                                                <select name="assigned_to" class="form-select form-select-sm">
                                                    <option value="">{{ __('بدون تعيين') }}</option>
                                                    @foreach($assignableAgents as $agent)
                                                        <option value="{{ $agent->id }}" {{ $conversation['assigned_to'] == $agent->id ? 'selected' : '' }}>
                                                            {{ $agent->name }}
                                                        </option>
                                                    @endforeach
                                                </select>
                                                <button class="btn btn-outline-primary" type="submit">
                                                    <i class="bi bi-save"></i>
                                                </button>
                                            </div>
                                        </form>
                                    @endif




                                </div>
                            </div>
                        </div>
                    @empty
                        <div class="p-3 text-center text-muted">
                            <i class="bi bi-chat-dots d-block fs-2 mb-2"></i>
                            {{ __('لا توجد محادثات متاحة') }}
                        </div>
                    @endforelse
                </div>
            </div>

            <!-- عرض المحادثة المحددة -->
            <div class="chat-view">
                <div class="view-header">
                    <h5 class="mb-0 py-2 px-3 bg-light border-bottom">{{ __('عرض المحادثة') }}</h5>
                </div>
                <div id="empty-state" class="empty-chat">
                    <i class="bi bi-chat-dots"></i>
                    {{-- <p>{{ __('اختر محادثة لعرض الرسائل') }}</p> --}}
                </div>

                
                
                <div id="loading-state" class="chat-loading d-none">
                    <div class="spinner-border text-primary" role="status">
                        <span class="visually-hidden">{{ __('جاري التحميل...') }}</span>
                    </div>
                    <span class="ms-2">{{ __('جاري تحميل المحادثة...') }}</span>
                </div>

                <!-- سيتم إضافة محتوى المحادثة هنا عبر JavaScript -->
                <div id="chat-content" class="d-none">
                    <div class="chat-header" id="chat-header">
                        <!-- سيتم إضافة معلومات المستخدم هنا -->
                    </div>
                    <div class="messages-container" id="messages-container">
                        <!-- سيتم إضافة الرسائل هنا -->
                    </div>
                    <div class="chat-actions">
                        <a href="#" id="return-to-list" class="btn btn-sm btn-secondary d-md-none">
                            <i class="bi bi-arrow-left"></i> {{ __('العودة') }}
                        </a>
                    </div>
                </div>
            </div>
        </div>




        <div class="card mt-4">
            <div class="card-header d-flex justify-content-between align-items-center">
                <h5 class="mb-0">{{ __('سجل البلاغات والدعم') }}</h5>
                <span class="text-muted small">{{ __('يتم عرض البلاغات المرتبطة بالقسم الحالي.') }}</span>
            </div>
            <div class="card-body">
                <form action="{{ route('chat-monitor.tickets.store') }}" method="POST" class="row g-3 align-items-end mb-4">
                    @csrf
                    <input type="hidden" name="department" value="{{ $department }}">
                    <div class="col-md-4">
                        <label class="form-label fw-bold" for="ticket-subject">{{ __('موضوع البلاغ') }}</label>
                        <input type="text" name="subject" id="ticket-subject" class="form-control" placeholder="{{ __('ادخل عنواناً واضحاً') }}" required>
                    </div>
                    <div class="col-md-4">
                        <label class="form-label fw-bold" for="ticket-conversation">{{ __('رقم المحادثة (اختياري)') }}</label>
                        <input type="text" name="chat_conversation_id" id="ticket-conversation" class="form-control" list="conversationOptions" placeholder="{{ __('اختر محادثة أو اتركه فارغاً') }}">
                    </div>
                    <div class="col-md-4">
                        <label class="form-label fw-bold" for="ticket-agent">{{ __('تعيين إلى') }}</label>
                        <select name="assigned_to" id="ticket-agent" class="form-select">
                            <option value="">{{ __('يتم التعيين لاحقاً') }}</option>
                            @foreach($assignableAgents as $agent)
                                <option value="{{ $agent->id }}">{{ $agent->name }}</option>
                            @endforeach
                        </select>
                    </div>
                    <div class="col-12">
                        <label class="form-label fw-bold" for="ticket-description">{{ __('وصف البلاغ') }}</label>
                        <textarea name="description" id="ticket-description" class="form-control" rows="3" placeholder="{{ __('اشرح تفاصيل المشكلة أو الطلب') }}"></textarea>
                    </div>
                    <div class="col-12 text-end">
                        <button type="submit" class="btn btn-primary">
                            <i class="bi bi-plus-circle me-1"></i>{{ __('إضافة بلاغ جديد') }}
                        </button>
                    </div>
                </form>

                <datalist id="conversationOptions">
                    @foreach($conversationsData as $conversation)
                        <option value="{{ $conversation['conversation_id'] }}">#{{ $conversation['conversation_id'] }} - {{ $conversation['sender']->name ?? __('محادثة') }}</option>
                    @endforeach
                </datalist>

                <div class="table-responsive">
                    <table class="table table-striped align-middle">
                        <thead class="bg-light">
                            <tr>
                                <th>{{ __('الموضوع') }}</th>
                                <th>{{ __('القسم') }}</th>
                                <th>{{ __('الحالة الحالية') }}</th>
                                <th>{{ __('المكلف') }}</th>
                                <th>{{ __('المبلغ') }}</th>
                                <th>{{ __('تم الإنشاء') }}</th>
                                <th class="text-center">{{ __('إجراءات') }}</th>
                            </tr>
                        </thead>
                        <tbody>
                            @forelse($tickets as $ticket)
                                <tr>
                                    <td>
                                        <div class="fw-semibold">{{ $ticket->subject }}</div>
                                        @if($ticket->chat_conversation_id)
                                            <small class="text-muted">{{ __('محادثة رقم') }}: {{ $ticket->chat_conversation_id }}</small>
                                        @endif
                                    </td>
                                    <td>{{ $availableDepartments[$ticket->department] ?? ($ticket->department === 'general' ? __('قسم عام') : $ticket->department) }}</td>
                                    <td>
                                        @php
                                            $statusClasses = [
                                                \App\Models\DepartmentTicket::STATUS_OPEN => 'bg-warning text-dark',
                                                \App\Models\DepartmentTicket::STATUS_IN_PROGRESS => 'bg-info text-dark',
                                                \App\Models\DepartmentTicket::STATUS_RESOLVED => 'bg-success',
                                            ];
                                        @endphp
                                        <span class="badge {{ $statusClasses[$ticket->status] ?? 'bg-secondary' }}">
                                            {{ match ($ticket->status) {
                                                \App\Models\DepartmentTicket::STATUS_OPEN => __('مفتوح'),
                                                \App\Models\DepartmentTicket::STATUS_IN_PROGRESS => __('قيد المعالجة'),
                                                \App\Models\DepartmentTicket::STATUS_RESOLVED => __('مغلق'),
                                                default => $ticket->status,
                                            } }}
                                        </span>
                                    </td>
                                    <td>{{ optional($ticket->assignedAgent)->name ?? __('غير محدد') }}</td>
                                    <td>{{ optional($ticket->reporter)->name ?? __('غير محدد') }}</td>
                                    <td>{{ optional($ticket->created_at)->format('Y-m-d H:i') }}</td>
                                    <td>
                                        <form action="{{ route('chat-monitor.tickets.update-status', $ticket) }}" method="POST" class="row g-2 align-items-center">
                                            @csrf
                                            <div class="col-md-5">
                                                <select name="status" class="form-select form-select-sm">
                                                    <option value="{{ \App\Models\DepartmentTicket::STATUS_OPEN }}" {{ $ticket->status === \App\Models\DepartmentTicket::STATUS_OPEN ? 'selected' : '' }}>{{ __('مفتوح') }}</option>
                                                    <option value="{{ \App\Models\DepartmentTicket::STATUS_IN_PROGRESS }}" {{ $ticket->status === \App\Models\DepartmentTicket::STATUS_IN_PROGRESS ? 'selected' : '' }}>{{ __('قيد المعالجة') }}</option>
                                                    <option value="{{ \App\Models\DepartmentTicket::STATUS_RESOLVED }}" {{ $ticket->status === \App\Models\DepartmentTicket::STATUS_RESOLVED ? 'selected' : '' }}>{{ __('مغلق') }}</option>
                                                </select>
                                            </div>
                                            <div class="col-md-5">
                                                <select name="assigned_to" class="form-select form-select-sm">
                                                    <option value="">{{ __('غير محدد') }}</option>
                                                    @foreach($assignableAgents as $agent)
                                                        <option value="{{ $agent->id }}" {{ $ticket->assigned_to === $agent->id ? 'selected' : '' }}>{{ $agent->name }}</option>
                                                    @endforeach
                                                </select>
                                            </div>
                                            <div class="col-md-2 text-end">
                                                <button type="submit" class="btn btn-sm btn-outline-primary">
                                                    <i class="bi bi-save"></i>
                                                </button>
                                            </div>
                                        </form>
                                    </td>
                                </tr>
                            @empty
                                <tr>
                                    <td colspan="7" class="text-center text-muted">{{ __('لا توجد بلاغات مسجلة لهذا القسم حتى الآن.') }}</td>
                                </tr>
                            @endforelse
                        </tbody>
                    </table>
                </div>

                <div class="mt-3">
                    {{ $tickets->links() }}
                </div>
            </div>
        </div>







    </section>
@endsection


@php
    $testConversationRouteTemplate = \Illuminate\Support\Facades\Route::has('chat-monitor.test-conversation')
        ? route('chat-monitor.test-conversation', ['id' => '__ID__'])
        : null;
@endphp

<script src="https://code.jquery.com/jquery-3.7.1.min.js" integrity="sha256-/JqT3SQfawRcv/BIHPThkBvs0OEvtFFmqPF/lYI/Cxo=" crossorigin="anonymous"></script>
{{-- @section('script') --}}
<script>
    $(document).ready(function() {
        console.log("Document ready - initializing chat monitor...");
        
        // تهيئة Select2
        if ($.fn.select2) {
            $('#user_id').select2({
                theme: 'bootstrap-5',
                width: '100%',
                dropdownParent: $('#filterCollapse'),
                language: {
                    noResults: function() {
                        return "{{ __('لا توجد نتائج') }}";
                    }
                },
                templateResult: formatOption,
                templateSelection: formatOption
            });
        }
        
        // دالة تنسيق خيارات Select2
        function formatOption(option) {
            if (!option.id) {
                return option.text;
            }
            return $('<span>' + option.text + '</span>');
        }
        
        // تفعيل تلميحات البيانات
        $('[data-bs-toggle="tooltip"]').tooltip();
        
        // تنفيذ البحث في المحادثات
        $("#search-conversations").on("keyup", function() {
            var value = $(this).val().toLowerCase();
            $(".conversation-item").filter(function() {
                $(this).toggle($(this).text().toLowerCase().indexOf(value) > -1)
            });
        });
        
        // عند النقر على محادثة
        $(document).on("click", ".conversation-item", function(e) {
            e.preventDefault();
            const conversationId = $(this).data('conversation-id');
            console.log("تم النقر على المحادثة:", conversationId);
            
            if (!conversationId) {
                console.error("معرف المحادثة غير موجود!");
                return;
            }
            
            // تحديث الحالة النشطة
            $(".conversation-item").removeClass("active");
            $(this).addClass("active");
            
            // عرض حالة التحميل
            $("#empty-state").addClass("d-none");
            $("#chat-content").addClass("d-none");
            $("#loading-state").removeClass("d-none");
            
            // عرض المحادثة باستخدام بيانات الاختبار
            displayConversation(conversationId);
            
            // إخفاء قائمة المحادثات في الأجهزة الصغيرة
            if (window.innerWidth < 768) {
                $(".conversations-list").hide();
                $(".chat-view").show();
            }
        });
        
        // العودة إلى القائمة في الأجهزة الصغيرة
        $("#return-to-list").on("click", function(e) {
            e.preventDefault();
            $(".conversations-list").show();
            $(".chat-view").hide();
        });
    });
    
    // عرض المحادثة
    function displayConversation(conversationIdOrData) {
        console.log("بدء عرض المحادثة...");
        
        try {
            // التحقق مما إذا كان المعامل هو معرف محادثة أو كائن بيانات
            if (typeof conversationIdOrData === 'object') {
                // إذا كان كائن بيانات، عرض المحادثة مباشرة
                displayConversationData(conversationIdOrData);
                return;
            }


            
            // إذا كان معرف محادثة، جلب البيانات أولاً
            const conversationId = conversationIdOrData;
            




            // استخدام طريق الاختبار للتحقق من البيانات
            const testConversationRouteTemplate = @json($testConversationRouteTemplate);

            if (!testConversationRouteTemplate) {
                console.error("رابط اختبار المحادثة غير متوفر.");
                showError("لا يمكن تحميل بيانات المحادثة التجريبية في الوقت الحالي.");
                return;
            }

            const testUrl = testConversationRouteTemplate.replace('__ID__', conversationId) + "?_=" + new Date().getTime();
            
            
            console.log("رابط طلب الاختبار:", testUrl);
            
            $.ajax({
                url: testUrl,
                type: "GET",
                dataType: "json",
                headers: {
                    'X-Requested-With': 'XMLHttpRequest',
                    'Accept': 'application/json'
                },
                success: function(response) {
                    console.log("تم استلام بيانات الاختبار بنجاح:", response);
                    
                    if (response.error) {
                        console.error("خطأ في بيانات الاختبار:", response.message);
                        showError("خطأ في بيانات الاختبار: " + response.message);
                        return;
                    }
                    
                    console.log("عدد الرسائل المستلمة:", response.chats_count);
                    console.log("عدد المستخدمين المستلمين:", response.users_count);
                    
                    // عرض المحادثة باستخدام بيانات الاختبار
                    displayConversationData(response);
                },
                error: function(xhr, status, error) {
                    console.error("خطأ في تحميل بيانات الاختبار:", error);
                    console.error("حالة الخطأ:", status);
                    console.error("رمز الحالة:", xhr.status);
                    console.error("استجابة الخطأ:", xhr.responseText);
                    
                    try {
                        const errorResponse = JSON.parse(xhr.responseText);
                        console.log("تفاصيل الخطأ:", errorResponse);
                    } catch (e) {
                        console.log("لا يمكن تحليل استجابة الخطأ كـ JSON");
                    }
                    
                    showError("حدث خطأ أثناء تحميل المحادثة. يرجى المحاولة مرة أخرى.");
                }
            });
        } catch (error) {
            console.error("خطأ أثناء عرض المحادثة:", error);
            console.error("تفاصيل الخطأ:", error.message);
            console.error("مكان الخطأ:", error.stack);
            
            showError("حدث خطأ أثناء عرض المحادثة. يرجى المحاولة مرة أخرى.");
        }
    }
    
    // عرض رسالة خطأ
    function showError(message) {
        Swal.fire({
            icon: 'error',
            title: "{{ __('خطأ') }}",
            text: message
        });
        
        $("#loading-state").addClass("d-none");
        $("#empty-state").removeClass("d-none");
    }
    
    // عرض بيانات المحادثة
    function displayConversationData(data) {
        console.log("عرض بيانات المحادثة:", data);
        
        try {
            // تأكد من أن البيانات تحتوي على المعلومات المطلوبة
            if (!data) {
                console.error("البيانات غير صالحة:", data);
                showError("بيانات المحادثة غير صالحة");
                return;
            }
            
            // استخدام معرف المحادثة المناسب
            const conversationId = data.id || data.item_offer_id;
            if (!conversationId) {
                console.error("معرف المحادثة غير موجود:", data);
                showError("معرف المحادثة غير موجود");
                return;
            }
            
            console.log("معرف المحادثة:", conversationId);
            console.log("عدد الرسائل:", data.chats ? data.chats.length : 0);
            console.log("المستخدمون:", data.users);
            
            // تحديث معلومات المستخدمين في الهيدر
            let headerHtml = '';
            
            // التحقق من وجود بيانات المستخدمين
            if (data.users && Object.keys(data.users).length > 0) {
                // الحصول على مستخدمين من كائن المستخدمين
                const userIds = Object.keys(data.users);
                console.log("معرفات المستخدمين:", userIds);
                
                const firstUser = data.users[userIds[0]];
                let secondUser = null;
                
                // إذا كان هناك أكثر من مستخدم، نعرض المستخدم الثاني أيضًا
                if (userIds.length > 1) {
                    secondUser = data.users[userIds[1]];
                }
                
                console.log("المستخدم الأول:", firstUser);
                if (secondUser) console.log("المستخدم الثاني:", secondUser);
                
                headerHtml = `
                    <img src="${firstUser.image || "{{ asset('assets/images/no_image_available.png') }}"}" 
                         class="user-avatar" alt="User" onerror="onErrorImage(event)">
                    <div>
                        <div class="user-name">${firstUser.name} ${secondUser ? ' ⟷ ' + secondUser.name : ''}</div>
                        <div class="conversation-id">{{ __('محادثة رقم') }}: #${conversationId}</div>
                    </div>
                `;
            } else {
                headerHtml = `
                    <img src="{{ asset('assets/images/no_image_available.png') }}" class="user-avatar" alt="User">
                    <div>
                        <div class="user-name">{{ __('محادثة') }} #${conversationId}</div>
                    </div>
                `;
            }
            $("#chat-header").html(headerHtml);
            console.log("تم تحديث رأس المحادثة");
            
            // عرض الرسائل
            let messagesHtml = '';
            let lastSenderId = null;
            let currentUserId = {{ auth()->id() }};
            
            console.log("معرف المستخدم الحالي:", currentUserId);
            
            if (data.chats && data.chats.length > 0) {
                console.log("جاري معالجة " + data.chats.length + " رسالة...");
                
                data.chats.forEach((chat, index) => {
                    console.log("معالجة الرسالة #" + (index + 1), chat);
                    
                    if (!chat || !chat.sender_id) {
                        console.error("بيانات الرسالة غير صالحة:", chat);
                        return;
                    }
                    
                    // تحديد ما إذا كان المستخدم هو المرسل أو المستقبل
                    // نفترض أن المستخدم الأول في القائمة هو المرسل دائمًا
                    const userIds = Object.keys(data.users);
                    const firstUserId = userIds[0];
                    const isSender = parseInt(chat.sender_id) === parseInt(firstUserId);
                    
                    // الرسائل المرسلة من المرسل تظهر على اليمين
                    const messageClass = isSender ? 'message-sender' : 'message-receiver';
                    
                    const userInfo = data.users && data.users[chat.sender_id] ? data.users[chat.sender_id].name : '{{ __('مستخدم غير معروف') }}';
                    
                    messagesHtml += `
                        <div class="message">
                            <div class="${messageClass}">
                    `;
                    
                    // إضافة اسم المستخدم بشكل بسيط
                    messagesHtml += `<div class="message-username">${userInfo}</div>`;
                    
                    if (chat.message) {
                        messagesHtml += `<div class="message-text">${chat.message}</div>`;
                    }
                    
                    if (chat.file) {
                        const fileUrl = chat.file;
                        const fileExt = fileUrl.split('.').pop().toLowerCase();
                        
                        // عرض جميع الملفات كروابط تنزيل
                        messagesHtml += `
                            <div class="message-file">
                                <a href="${fileUrl}" class="btn btn-sm btn-light" download>
                                    <i class="bi bi-file-earmark"></i> {{ __('تنزيل الملف') }}
                                </a>
                            </div>
                        `;
                    }
                    
                    if (chat.audio) {
                        // عرض الصوت كرابط تنزيل بدلاً من مشغل الصوت
                        messagesHtml += `
                            <div class="message-file">
                                <a href="${chat.audio}" class="btn btn-sm btn-light" download>
                                    <i class="bi bi-file-music"></i> {{ __('تنزيل الملف الصوتي') }}
                                </a>
                            </div>
                        `;
                    }
                    
                    // تنسيق التاريخ والوقت بتوقيت الرياض
                    const messageDate = new Date(chat.created_at);
                    const options = { 
                        timeZone: 'Asia/Riyadh',
                        hour: '2-digit', 
                        minute: '2-digit',
                        day: '2-digit',
                        month: '2-digit',
                        year: 'numeric'
                    };
                    const formattedTime = messageDate.toLocaleString('ar-SA', options);
                    
                    messagesHtml += `
                            <div class="message-time">
                                <i class="bi bi-clock me-1"></i> ${formattedTime}
                            </div>
                            </div>
                        </div>
                    `;
                    
                    lastSenderId = chat.sender_id;
                });
                
            } else {
                messagesHtml = `
                    <div class="text-center p-5">
                        <i class="bi bi-chat-dots fs-1 text-muted mb-3"></i>
                        <p class="fs-5">{{ __('لا توجد رسائل في هذه المحادثة') }}</p>
                    </div>
                `;
            }
            
            $("#messages-container").html(messagesHtml);
            console.log("تم تحديث محتوى الرسائل");
            
            // تحسين السكرول - تأخير التمرير لضمان تحميل جميع العناصر
            setTimeout(function() {
                const messagesContainer = document.getElementById('messages-container');
                if (messagesContainer) {
                    messagesContainer.scrollTop = messagesContainer.scrollHeight;
                    console.log("تم التمرير إلى آخر رسالة بعد التأخير");
                }
            }, 100);
            
            // إظهار المحادثة
            $("#loading-state").addClass("d-none");
            $("#chat-content").removeClass("d-none");
            console.log("تم إظهار محتوى المحادثة");
            
        } catch (error) {
            console.error("خطأ أثناء عرض بيانات المحادثة:", error);
            console.error("تفاصيل الخطأ:", error.message);
            console.error("مكان الخطأ:", error.stack);
            
            showError("حدث خطأ أثناء عرض المحادثة. يرجى المحاولة مرة أخرى.");
        }
    }
    
    // معالجة خطأ تحميل الصور
    function onErrorImage(event) {
        console.log("خطأ في تحميل الصورة، استخدام الصورة الافتراضية");
        event.target.src = "{{ asset('assets/images/no_image_available.png') }}";
    }
    
    // دالة تنسيق التاريخ والوقت بتوقيت الرياض
    function formatDateTimeRiyadh(dateString) {
        // إنشاء كائن تاريخ
        const date = new Date(dateString);
        
        // تحويل التاريخ إلى توقيت الرياض (UTC+3)
        const options = { 
            timeZone: 'Asia/Riyadh',
            hour: '2-digit', 
            minute: '2-digit',
            day: '2-digit',
            month: '2-digit',
            year: 'numeric'
        };
        
        // تنسيق التاريخ والوقت
        return date.toLocaleString('ar-SA', options);
    }
</script>