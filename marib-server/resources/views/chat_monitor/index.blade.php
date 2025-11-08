@extends('layouts.main')

@section('title')
    {{ __('مراقبة المحادثات') }}
@endsection

@section('css')
    <style>
        .chat-monitor-dashboard {
            --chat-card-gradient: linear-gradient(145deg, #ffffff 0%, #f7f9fb 100%);
            --chat-card-shadow: 0 10px 30px rgba(15, 35, 95, 0.08);
            --chat-heading-color: var(--bs-body-color);
            --chat-muted-color: var(--bs-secondary-color, #6c757d);
            --chat-border-color: var(--bs-border-color, #edf0f7);
            --chat-panel-bg: var(--bs-tertiary-bg, #fafbfc);
            --chat-panel-contrast: var(--bs-body-bg, #ffffff);
            --chat-scroll-thumb: color-mix(in srgb, var(--bs-body-color) 20%, transparent);
            --chat-tile-bg: var(--bs-tertiary-bg, #ffffff);
            --chat-tile-hover-border: color-mix(in srgb, var(--bs-primary) 45%, transparent);
            --chat-text-soft: color-mix(in srgb, var(--bs-body-color) 70%, var(--bs-body-bg));
            --chat-agent-gradient-start: var(--bs-primary, #3558ff);
            --chat-agent-gradient-end: color-mix(in srgb, var(--bs-primary, #4776e6) 80%, #3558ff);
            --chat-client-bg: var(--bs-body-bg, #ffffff);
            --chat-client-border: color-mix(in srgb, var(--bs-body-color) 10%, transparent);
        }

        [data-bs-theme="dark"] .chat-monitor-dashboard {
            --chat-card-gradient: linear-gradient(145deg, color-mix(in srgb, var(--bs-body-bg) 80%, #1f2937), color-mix(in srgb, var(--bs-body-bg) 60%, #111827));
            --chat-card-shadow: 0 12px 30px rgba(0, 0, 0, 0.45);
            --chat-panel-bg: color-mix(in srgb, var(--bs-body-bg) 85%, #111827);
            --chat-panel-contrast: color-mix(in srgb, var(--bs-body-bg) 95%, #0f172a);
            --chat-scroll-thumb: color-mix(in srgb, var(--bs-body-color) 40%, transparent);
            --chat-tile-bg: color-mix(in srgb, var(--bs-body-bg) 92%, #0b1120);
            --chat-client-bg: color-mix(in srgb, var(--bs-body-bg) 80%, #0f172a);
            --chat-client-border: color-mix(in srgb, var(--bs-body-color) 25%, transparent);
            --chat-muted-color: color-mix(in srgb, var(--bs-body-color) 65%, var(--bs-body-bg));
        }

        .chat-monitor-dashboard .stat-card {
            border: none;
            border-radius: 16px;
            padding: 22px;
            background: var(--chat-card-gradient);
            box-shadow: var(--chat-card-shadow);
            height: 100%;
            display: flex;
            flex-direction: column;
            justify-content: space-between;
        }

        .chat-monitor-dashboard .stat-card h2 {
            font-size: 30px;
            margin: 10px 0 4px;
            font-weight: 700;
            color: var(--chat-heading-color);
        }

        .chat-monitor-dashboard .stat-card small {
            color: var(--chat-muted-color);
        }

        .chat-monitor-dashboard .stat-card .stat-icon {
            width: 52px;
            height: 52px;
            border-radius: 12px;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            font-size: 24px;
            color: #fff;
        }

        .chat-monitor-dashboard .filter-card .form-label {
            font-weight: 600;
            color: var(--chat-heading-color);
        }

        .chat-monitor-dashboard .text-muted {
            color: var(--chat-muted-color) !important;
        }

        .chat-monitor-dashboard .chat-workspace-card {
            border-radius: 18px;
            overflow: hidden;
        }

        .chat-workspace {
            display: grid;
            grid-template-columns: 340px 1fr;
            min-height: 520px;
            height: clamp(520px, 70vh, 820px);
        }

        .chat-workspace > .conversation-panel,
        .chat-workspace > .reader-panel {
            min-height: 0;
        }

        @media (max-width: 992px) {
            .chat-workspace {
                grid-template-columns: 1fr;
                height: auto;
            }
        }

        .conversation-panel {
            border-right: 1px solid var(--chat-border-color);
            background-color: var(--chat-panel-bg);
            display: flex;
            flex-direction: column;
            height: 100%;
        }

        .conversation-list {
            flex: 1;
            overflow-y: auto;
            padding: 12px;
        }

        .conversation-list::-webkit-scrollbar,
        .reader-messages::-webkit-scrollbar {
            width: 6px;
        }

        .conversation-list::-webkit-scrollbar-thumb,
        .reader-messages::-webkit-scrollbar-thumb {
            background: var(--chat-scroll-thumb);
            border-radius: 4px;
        }

        .conversation-tile {
            width: 100%;
            border: 1px solid transparent;
            border-radius: 14px;
            background-color: var(--chat-tile-bg);
            padding: 14px;
            text-align: start;
            transition: all 0.2s ease;
            display: flex;
            flex-direction: column;
            gap: 8px;
            margin-bottom: 10px;
        }

        .conversation-tile.active,
        .conversation-tile:hover {
            border-color: var(--chat-tile-hover-border);
            box-shadow: 0 12px 30px rgba(55, 71, 133, 0.12);
        }

        .conversation-tile .tile-title {
            font-weight: 600;
            color: var(--chat-heading-color);
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        .conversation-tile .tile-meta {
            font-size: 12px;
            color: var(--chat-muted-color);
            display: flex;
            justify-content: space-between;
            flex-wrap: wrap;
            gap: 6px;
        }

        .conversation-tile .tile-preview {
            font-size: 13px;
            color: var(--chat-text-soft);
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
        }

        .conversation-tile .badge {
            background-color: color-mix(in srgb, var(--chat-heading-color) 12%, var(--chat-panel-contrast));
            color: var(--chat-heading-color);
        }

        .reader-panel {
            background-color: var(--chat-panel-contrast);
            display: flex;
            flex-direction: column;
            height: 100%;
            color: var(--chat-heading-color);
        }

        .reader-header {
            padding: 20px;
            border-bottom: 1px solid var(--chat-border-color);
        }

        .reader-messages {
            flex: 1;
            padding: 24px;
            background: var(--chat-panel-bg);
            overflow-y: auto;
            display: flex;
            flex-direction: column;
            gap: 10px;
            color: var(--chat-heading-color);
        }

        .reader-composer {
            padding: 20px;
            border-top: 1px solid var(--chat-border-color);
            background-color: var(--chat-panel-contrast);
            color: var(--chat-heading-color);
        }

        .message-bubble {
            max-width: 75%;
            padding: 14px 16px;
            border-radius: 18px;
            position: relative;
            font-size: 14px;
            line-height: 1.5;
            word-break: break-word;
            align-self: flex-start;
        }

        .message-bubble .message-author {
            font-weight: 600;
            margin-bottom: 6px;
            font-size: 12px;
        }

        .message-bubble .message-time {
            font-size: 11px;
            color: rgba(255, 255, 255, 0.8);
            margin-top: 8px;
            display: inline-flex;
            gap: 4px;
            align-items: center;
        }

        .bubble-agent {
            align-self: flex-end;
            background: linear-gradient(135deg, var(--chat-agent-gradient-start), var(--chat-agent-gradient-end));
            color: #fff;
            border-bottom-right-radius: 4px;
        }

        .bubble-client {
            align-self: flex-start;
            background: var(--chat-client-bg);
            color: var(--chat-heading-color);
            border: 1px solid var(--chat-client-border);
            border-bottom-left-radius: 4px;
        }

        .bubble-client .message-time {
            color: var(--chat-muted-color);
        }


        .reader-state {
            padding: 80px 20px;
            color: var(--chat-heading-color);
        }

        .reader-state small {
            color: var(--chat-muted-color);
        }

    </style>
@endsection
@section('content')
    @php
        $totalConversations = $conversations->total();
        $averageMessages = $totalConversations > 0 ? round($totalMessages / $totalConversations, 1) : 0;
    @endphp

    <section class="section chat-monitor-dashboard">
        <div class="row g-3">
            <div class="col-12 col-sm-6 col-xl-3">
                <div class="stat-card">
                    <div class="stat-icon bg-primary"><i class="bi bi-chat-dots"></i></div>
                    <div>
                        <p class="text-muted mb-1">{{ __('إجمالي الرسائل') }}</p>
                        <h2>{{ number_format($totalMessages) }}</h2>
                        <small>{{ __('كل الرسائل المتداولة عبر المنصة') }}</small>
                    </div>
                </div>
            </div>
            <div class="col-12 col-sm-6 col-xl-3">
                <div class="stat-card">
                    <div class="stat-icon bg-success"><i class="bi bi-activity"></i></div>
                    <div>
                        <p class="text-muted mb-1">{{ __('المحادثات النشطة') }}</p>
                        <h2>{{ number_format($totalConversations) }}</h2>
                        <small>{{ __('يشمل نتائج الترشيح الحالية') }}</small>
                    </div>
                </div>
            </div>
            <div class="col-12 col-sm-6 col-xl-3">
                <div class="stat-card">
                    <div class="stat-icon bg-warning text-dark"><i class="bi bi-people"></i></div>
                    <div>
                        <p class="text-muted mb-1">{{ __('وكلاء متاحون') }}</p>
                        <h2>{{ number_format($assignableAgents->count()) }}</h2>
                        <small>{{ __('وكلاء يملكون صلاحية مراقبة المحادثات') }}</small>
                    </div>
                </div>
            </div>
            <div class="col-12 col-sm-6 col-xl-3">
                <div class="stat-card">
                    <div class="stat-icon bg-info"><i class="bi bi-graph-up"></i></div>
                    <div>
                        <p class="text-muted mb-1">{{ __('متوسط الرسائل لكل محادثة') }}</p>
                        <h2>{{ number_format($averageMessages, 1) }}</h2>
                        <small>{{ __('يساعد على تقييم كثافة التواصل') }}</small>
                    </div>
                </div>
            </div>
        </div>

        <div class="card filter-card border-0 shadow-sm mt-4">
            <div class="card-body">
                <form method="GET" action="{{ route('chat-monitor.index') }}" class="row g-3 align-items-end">
                    <div class="col-12 col-md-3">
                        <label class="form-label" for="keyword">{{ __('بحث نصي') }}</label>
                        <input type="text" name="keyword" id="keyword" class="form-control"
                               placeholder="{{ __('اسم مستخدم، رقم محادثة، كلمة مفتاحية...') }}"
                               value="{{ request('keyword') }}">
                    </div>
                    <div class="col-12 col-md-3">
                        <label class="form-label" for="user_id">{{ __('مستخدم محدد') }}</label>
                        <select name="user_id" id="user_id" class="form-select">
                            <option value="">{{ __('جميع المستخدمين') }}</option>
                            @foreach($allUsers as $user)
                                <option value="{{ $user->id }}" {{ request('user_id') == $user->id ? 'selected' : '' }}>
                                    {{ $user->name }} ({{ $user->email }})
                                </option>
                            @endforeach
                        </select>
                    </div>
                    <div class="col-6 col-md-2">
                        <label class="form-label" for="date_from">{{ __('من تاريخ') }}</label>
                        <input type="date" name="date_from" id="date_from" class="form-control"
                               value="{{ request('date_from') }}">
                    </div>
                    <div class="col-6 col-md-2">
                        <label class="form-label" for="date_to">{{ __('إلى تاريخ') }}</label>
                        <input type="date" name="date_to" id="date_to" class="form-control"
                               value="{{ request('date_to') }}">
                    </div>
                    <div class="col-12 col-md-2">
                        <label class="form-label" for="department-filter">{{ __('القسم') }}</label>
                        <select name="department" id="department-filter" class="form-select">
                            <option value="">{{ __('كل الأقسام') }}</option>
                            @foreach($availableDepartments as $key => $label)
                                <option value="{{ $key }}" {{ $department === $key ? 'selected' : '' }}>
                                    {{ $label }}
                                </option>
                            @endforeach
                        </select>
                    </div>
                    <div class="col-12 d-flex gap-2 justify-content-end">
                        <a href="{{ route('chat-monitor.index') }}" class="btn btn-light">
                            <i class="bi bi-arrow-counterclockwise me-1"></i>{{ __('إعادة التعيين') }}
                        </a>
                        <button type="submit" class="btn btn-primary">
                            <i class="bi bi-filter-circle me-1"></i>{{ __('تطبيق الفلاتر') }}
                        </button>
                    </div>
                </form>
            </div>
        </div>

        <div class="card chat-workspace-card mt-4 border-0 shadow-sm">
            <div class="card-header bg-white d-flex flex-wrap gap-2 align-items-center justify-content-between">
                <h5 class="mb-0">{{ __('جميع المحادثات في التطبيق') }}</h5>
                <button type="button" class="btn btn-outline-secondary" id="refreshConversations">
                    <i class="bi bi-arrow-repeat me-1"></i>{{ __('تحديث القائمة') }}
                </button>
            </div>
            <div class="chat-workspace">
                <div class="conversation-panel">
                    <div class="conversation-list" id="conversationList">
                        @forelse($conversationsData as $conversation)
                            @php
                                $departmentLabel = $conversation['department']
                                    ? ($availableDepartments[$conversation['department']] ?? ($conversation['department'] === 'general' ? __('قسم عام') : $conversation['department']))
                                    : __('قسم عام');
                                $assignedName = optional($conversation['assigned_agent'])->name;
                                $assignedId = $conversation['assigned_to'];
                            @endphp
                            <button type="button" class="conversation-tile"
                                    data-conversation-id="{{ $conversation['item_offer_id'] }}"
                                    data-conversation-key="{{ $conversation['conversation_id'] }}"
                                    data-assigned-name="{{ $assignedName }}"
                                    data-assigned-id="{{ $assignedId }}"
                                    data-department-label="{{ $departmentLabel }}"
                                    data-created-at="{{ $conversation['created_at'] }}">
                                <div class="tile-title">
                                    <span>#{{ $conversation['conversation_id'] ?? $conversation['item_offer_id'] }}</span>
                                    <span class="badge rounded-pill bg-light text-dark">
                                        {{ $conversation['total_messages'] }} {{ __('رسالة') }}
                                    </span>
                                </div>
                                <div class="tile-preview">
                                    {{ \Illuminate\Support\Str::limit($conversation['last_message'] ?? __('لا يوجد محتوى'), 80) }}
                                </div>
                                <div class="tile-meta">
                                    <span><i class="bi bi-diagram-3 me-1"></i>{{ $departmentLabel }}</span>
                                    <span>
                                        <i class="bi bi-person-workspace me-1"></i>
                                        {{ $assignedName ?? __('غير معيّن') }}
                                    </span>
                                    <span class="text-muted">
                                        <i class="bi bi-clock-history me-1"></i>
                                        {{ optional($conversation['created_at']) ? \Carbon\Carbon::parse($conversation['created_at'])->diffForHumans() : '' }}
                                    </span>
                                </div>
                            </button>
                        @empty
                            <div class="text-center text-muted py-5">
                                <i class="bi bi-chat-left-dots fs-1 d-block mb-3"></i>
                                <p class="mb-0">{{ __('لا توجد محادثات مطابقة للمرشحات الحالية.') }}</p>
                            </div>
                        @endforelse
                    </div>
                    <div class="conversation-pagination border-top p-3">
                        {{ $conversations->links() }}
                    </div>
                </div>
                <div class="reader-panel" id="conversationPanel">
                    <div id="chatEmptyState" class="reader-state text-center">
                        <i class="bi bi-chat-square-text fs-1 mb-3 d-block"></i>
                        <p class="mb-1">{{ __('اختر محادثة من القائمة لمعاينة التفاصيل والرد.') }}</p>
                        <small>{{ __('تظهر المحادثات هنا بمجرد اختيار أي محادثة من القائمة اليمنى.') }}</small>
                    </div>
                    <div id="chatLoadingState" class="reader-state text-center d-none">
                        <div class="spinner-border text-primary mb-3" role="status"></div>
                        <p class="mb-0">{{ __('يتم تحميل المحادثة ...') }}</p>
                    </div>
                    <div id="chatContent" class="d-none h-100 d-flex flex-column">
                        <div class="reader-header d-flex flex-wrap gap-3 align-items-center justify-content-between">
                            <div class="d-flex align-items-center gap-3">
                                <img id="chatPartnerAvatar" src="{{ asset('assets/images/no_image_available.png') }}" alt="avatar" width="56" height="56" class="rounded-circle border">
                                <div>
                                    <h5 class="mb-1" id="chatPartnerName">—</h5>
                                    <div class="text-muted small" id="chatConversationMeta"></div>
                                </div>
                            </div>
                            <div class="d-flex gap-2">
                                <button type="button" class="btn btn-outline-secondary btn-sm" id="reassignConversationBtn"
                                        data-bs-toggle="modal" data-bs-target="#assignConversationModal" disabled>
                                    <i class="bi bi-person-plus me-1"></i>{{ __('تعيين لوكيل آخر') }}
                                </button>
                                <button type="button" class="btn btn-outline-secondary btn-sm" id="markCompleteBtn" disabled>
                                    <i class="bi bi-check2-circle me-1"></i>{{ __('إغلاق المحادثة') }}
                                </button>
                            </div>
                        </div>
                        <div class="reader-messages" id="chatMessages"></div>
                        <div class="reader-composer">
                            <div class="input-group">
                                <textarea id="chatReplyInput" class="form-control" rows="2"
                                          placeholder="{{ __('قريباً: سيتم دعم الرد المباشر من لوحة المراقبة') }}" disabled></textarea>
                                <button class="btn btn-primary" id="sendReplyBtn" type="button" disabled>
                                    <i class="bi bi-send-fill"></i>
                                </button>
                            </div>
                            <small class="text-muted d-block mt-2">
                                {{ __('يتم ربط الردود القادمة من هنا بمنصة الدعم الحالية. سنفعّل الإرسال فور ربط واجهة البرمجة.') }}
                            </small>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </section>

    <div class="modal fade" id="assignConversationModal" tabindex="-1" aria-hidden="true">
        <div class="modal-dialog">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title">{{ __('تعيين المحادثة لوكيل') }}</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                </div>
                <form id="assignConversationForm" method="POST" action="#">
                    @csrf
                    <div class="modal-body">
                        <input type="hidden" id="assignConversationId" name="conversation_id">
                        <div class="mb-3">
                            <label class="form-label" for="assignAgentSelect">{{ __('الوكيل المسؤول') }}</label>
                            <select class="form-select" id="assignAgentSelect" name="assigned_to">
                                <option value="">{{ __('غير معيّن') }}</option>
                                @foreach($assignableAgents as $agent)
                                    <option value="{{ $agent->id }}">{{ $agent->name }}</option>
                                @endforeach
                            </select>
                        </div>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-light" data-bs-dismiss="modal">{{ __('إلغاء') }}</button>
                        <button type="submit" class="btn btn-primary">{{ __('حفظ التعيين') }}</button>
                    </div>
                </form>
            </div>
        </div>
    </div>
@endsection
@section('script')
    <script>
        document.addEventListener('DOMContentLoaded', function () {
            const conversationTiles = document.querySelectorAll('.conversation-tile');
            const viewRouteTemplate = @json(route('chat-monitor.view-conversation', ['id' => '__ID__']));
            const assignRouteTemplate = @json(route('chat-monitor.assign', ['conversation' => '__ID__']));
            const chatEmptyState = document.getElementById('chatEmptyState');
            const chatLoadingState = document.getElementById('chatLoadingState');
            const chatContent = document.getElementById('chatContent');
            const chatMessages = document.getElementById('chatMessages');
            const chatPartnerName = document.getElementById('chatPartnerName');
            const chatConversationMeta = document.getElementById('chatConversationMeta');
            const chatPartnerAvatar = document.getElementById('chatPartnerAvatar');
            const reassignBtn = document.getElementById('reassignConversationBtn');
            const assignConversationIdInput = document.getElementById('assignConversationId');
            const assignForm = document.getElementById('assignConversationForm');
            const assignSelect = document.getElementById('assignAgentSelect');
            const refreshButton = document.getElementById('refreshConversations');
            const currentUserId = {{ auth()->id() ?? 'null' }};
            let activeTile = null;

            function setState(state) {
                chatEmptyState.classList.toggle('d-none', state !== 'empty');
                chatLoadingState.classList.toggle('d-none', state !== 'loading');
                chatContent.classList.toggle('d-none', state !== 'content');
            }

            function escapeHtml(text) {
                const div = document.createElement('div');
                div.appendChild(document.createTextNode(text ?? ''));
                return div.innerHTML;
            }

            function createMessageBubble(message, users) {
                const sender = users[String(message.sender_id)] || null;
                const isAgent = currentUserId !== null && parseInt(message.sender_id, 10) === parseInt(currentUserId, 10);
                const bubble = document.createElement('div');
                bubble.className = 'message-bubble ' + (isAgent ? 'bubble-agent ms-auto' : 'bubble-client me-auto');
                const authorName = sender ? sender.name : '{{ __('مستخدم غير معروف') }}';
                const createdAt = message.created_at ? new Date(message.created_at) : null;
                bubble.innerHTML = `
                    <div class="message-author">${escapeHtml(authorName)}</div>
                    <div class="message-text">${message.message ? escapeHtml(message.message) : '{{ __('(رسالة بدون نص)') }}'}</div>
                    ${message.file ? `<div class="mt-2"><a class="btn btn-sm btn-light" target="_blank" href="${message.file}"><i class="bi bi-paperclip me-1"></i>{{ __('عرض المرفق') }}</a></div>` : ''}
                    ${message.audio ? `<div class="mt-2"><audio controls src="${message.audio}" class="w-100"></audio></div>` : ''}
                    <div class="message-time">${createdAt ? createdAt.toLocaleString('ar-EG') : ''}</div>
                `;
                return bubble;
            }

            function renderConversation(data, tile) {
                const users = data.users || {};
                const partner = Object.values(users).find(user => parseInt(user.id, 10) !== parseInt(currentUserId ?? -1, 10)) || Object.values(users)[0];
                chatPartnerName.textContent = partner ? partner.name : '{{ __('محادثة بدون اسم') }}';
                chatPartnerAvatar.src = partner && partner.image ? partner.image : '{{ asset('assets/images/no_image_available.png') }}';
                const departmentLabel = tile?.dataset.departmentLabel || '{{ __('قسم غير محدد') }}';
                chatConversationMeta.textContent = `#${data.conversation_id ?? data.id} · ${departmentLabel}`;

                chatMessages.innerHTML = '';
                (data.chats || []).forEach(message => {
                    chatMessages.appendChild(createMessageBubble(message, users));
                });
                chatMessages.scrollTop = chatMessages.scrollHeight;

                if (tile) {
                    reassignBtn.disabled = false;
                    assignSelect.value = tile.dataset.assignedId || '';
                    reassignBtn.dataset.conversationId = tile.dataset.conversationKey;
                }
            }

            function loadConversation(tile) {
                const conversationId = tile.dataset.conversationId;
                setState('loading');
                fetch(viewRouteTemplate.replace('__ID__', encodeURIComponent(conversationId)), {
                    headers: {
                        'Accept': 'application/json',
                        'X-Requested-With': 'XMLHttpRequest'
                    }
                })
                    .then(response => {
                        if (!response.ok) throw new Error();
                        return response.json();
                    })
                    .then(data => {
                        setState('content');
                        renderConversation(data, tile);
                    })
                    .catch(() => {
                        setState('empty');
                        if (window.Swal) {
                            Swal.fire('Oops', '{{ __('تعذر تحميل المحادثة، حاول مرة أخرى لاحقاً.') }}', 'error');
                        }
                    });
            }

            conversationTiles.forEach(tile => {
                tile.addEventListener('click', function () {
                    if (activeTile) {
                        activeTile.classList.remove('active');
                    }
                    this.classList.add('active');
                    activeTile = this;
                    loadConversation(this);
                });
            });

            if (refreshButton) {
                refreshButton.addEventListener('click', () => window.location.reload());
            }

            const assignModal = document.getElementById('assignConversationModal');
            assignModal?.addEventListener('show.bs.modal', function () {
                if (!activeTile) {
                    assignConversationIdInput.value = '';
                    return;
                }
                assignConversationIdInput.value = activeTile.dataset.conversationKey;
                assignSelect.value = activeTile.dataset.assignedId || '';
                assignForm.action = assignRouteTemplate.replace('__ID__', encodeURIComponent(activeTile.dataset.conversationKey));
            });

        });
    </script>
@endsection
