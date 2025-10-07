@extends('layouts.main')

@section('title')
    {{ __('الإحالات والنقاط') }}
@endsection





@section('css')
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"
          integrity="sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY=" crossorigin=""/>
    <style>
        .quick-stat-card h2 {
            font-weight: 700;
            font-size: 2rem;
        }

        #rejection_map {
            height: 320px;
            border-radius: 0.75rem;
        }

        .list-group-flush > .list-group-item {
            border-width: 0 0 1px;
        }

        .challenge-chart-container {
            min-height: 320px;
        }
    </style>
@endsection




@section('page-title')
    <div class="page-title">
        <div class="row">
            <div class="col-12 col-md-6 order-md-1 order-last">
                <h4>@yield('title')</h4>
                <p class="text-muted mb-0">{{ __('نظرة شاملة على أداء الإحالات، التحديات، ومحاولات التحقق') }}</p>
            </div>
            <div class="col-12 col-md-6 order-md-2 order-first"></div>
        </div>
    </div>
@endsection

@section('content')
    <section class="section">
        <div class="row g-3">
            <div class="col-xl-3 col-md-6">
                <div class="card quick-stat-card shadow-sm h-100 border-0">
                    <div class="card-body text-center">
                        <div class="text-muted mb-2">{{ __('إجمالي الإحالات المكتملة') }}</div>
                        <h2 class="mb-0" id="stat_total_referrals">0</h2>
                        <small class="text-success" id="stat_total_referrals_hint">{{ __('جارٍ التحديث...') }}</small>
                    </div>
                </div>
            </div>
            <div class="col-xl-3 col-md-6">
                <div class="card quick-stat-card shadow-sm h-100 border-0">
                    <div class="card-body text-center">
                        <div class="text-muted mb-2">{{ __('إحالات ناجحة داخل مأرب') }}</div>
                        <h2 class="mb-0 text-primary" id="stat_inside_marib">0</h2>
                        <small class="text-muted">{{ __('تم التحقق من الموقع داخل النطاق') }}</small>
                    </div>
                </div>
            </div>
            <div class="col-xl-3 col-md-6">
                <div class="card quick-stat-card shadow-sm h-100 border-0">
                    <div class="card-body text-center">
                        <div class="text-muted mb-2">{{ __('إحالات ناجحة خارج مأرب') }}</div>
                        <h2 class="mb-0 text-warning" id="stat_outside_marib">0</h2>
                        <small class="text-muted">{{ __('تم رصدها خارج نطاق المحافظة') }}</small>
                    </div>
                </div>
            </div>
            <div class="col-xl-3 col-md-6">
                <div class="card quick-stat-card shadow-sm h-100 border-0">
                    <div class="card-body text-center">
                        <div class="text-muted mb-2">{{ __('حالات الرفض') }}</div>
                        <h2 class="mb-0 text-danger" id="stat_rejected">0</h2>
                        <small class="text-muted" id="stat_rejected_ratio">0%</small>
                    </div>
                </div>
            </div>
        </div>

        <div class="row g-3 mt-1">
            <div class="col-xl-8">
                <div class="card shadow-sm h-100 border-0">
                    <div class="card-header d-flex justify-content-between align-items-center">
                        <h5 class="mb-0">{{ __('التحديات النشطة') }}</h5>
                        <span class="badge bg-success" id="active_challenges_count">0</span>
                    </div>
                    <div class="card-body challenge-chart-container">
                        <canvas id="activeChallengesChart" height="240"></canvas>
                        <div class="alert alert-info mt-3 mb-0" id="active_challenges_empty" style="display: none;">
                            {{ __('لا توجد تحديات نشطة في الوقت الحالي.') }}
                        </div>
                    </div>
                </div>
            </div>
            <div class="col-xl-4">
                <div class="card shadow-sm h-100 border-0">
                    <div class="card-header">
                        <h5 class="mb-0">{{ __('إدارة التحديات السريعة') }}</h5>
                    </div>
                    <div class="card-body">
                        <p class="text-muted small mb-3">
                            {{ __('اطلع على أهم التحديات النشطة واضغط للوصول إلى واجهة التعديل الكاملة.') }}
                        </p>
                        <ul class="list-group list-group-flush" id="challenge_quick_list"></ul>
                        <a href="{{ route('challenges.index') }}" class="btn btn-outline-primary w-100 mt-3">
                            {{ __('الانتقال إلى إدارة التحديات') }}
                        </a>
                    </div>
                </div>
            </div>
        </div>

        <div class="row g-3 mt-1">
            <div class="col-xl-8">
                <div class="card shadow-sm border-0">
                    <div class="card-header d-flex flex-wrap gap-2 align-items-center">
                        <h5 class="mb-0">{{ __('سجل الإحالات') }}</h5>
                        <div class="ms-auto d-flex flex-wrap gap-2">
                            <select id="challenge_filter" class="form-select form-select-sm">
                                <option value="">{{ __('جميع التحديات') }}</option>
                            </select>
                            <input type="search" id="referral_search" class="form-control form-control-sm"
                                   placeholder="{{ __('بحث بالاسم أو الكود') }}" />
                        </div>
                    </div>
                    <div class="card-body p-0">
                        <div class="table-responsive">
                            <table class="table table-hover mb-0" id="referrals_table" aria-describedby="referralsSummary"
                                   data-toggle="table" data-url="{{ route('referrals.list') }}"
                                   data-side-pagination="server" data-pagination="true" data-page-list="[5, 10, 20, 50]"
                                   data-mobile-responsive="true" data-query-params="referralsQueryParams"
                                   data-sort-name="created_at" data-sort-order="desc">
                                <thead class="table-light">
                                <tr>
                                    <th scope="col" data-field="id" data-sortable="true">{{ __('الرقم') }}</th>
                                    <th scope="col" data-field="referrer.name" data-sortable="true">{{ __('المُحيل') }}</th>
                                    <th scope="col" data-field="referred_user.name" data-sortable="true">{{ __('المستخدم المُحال') }}</th>
                                    <th scope="col" data-field="challenge.title" data-sortable="true">{{ __('التحدي') }}</th>
                                    <th scope="col" data-field="points" data-sortable="true">{{ __('النقاط') }}</th>
                                    <th scope="col" data-field="created_at" data-sortable="true" data-formatter="dateFormatter">
                                        {{ __('التاريخ') }}
                                    </th>
                                </tr>
                                </thead>
                            </table>

                        </div>
                    </div>
                </div>
            </div>
            <div class="col-xl-4">
                <div class="card shadow-sm h-100 border-0">
                    <div class="card-header">
                        <h5 class="mb-0">{{ __('أفضل المُحيلين') }}</h5>
                    </div>
                    <div class="card-body">
                        <ul class="list-group list-group-flush" id="top_users_list"></ul>
                    </div>
                </div>
            </div>
        </div>

        <div class="row g-3 mt-1">
            <div class="col-xl-8">
                <div class="card shadow-sm border-0">
                    <div class="card-header">
                        <div class="row g-2 align-items-center">
                            <div class="col-md-4">
                                <h5 class="mb-0">{{ __('محاولات الإحالة') }}</h5>
                            </div>
                            <div class="col-md-8">
                                <div class="d-flex gap-2 flex-wrap justify-content-md-end">
                                    <select id="attempt_status_filter" class="form-select form-select-sm">
                                        <option value="">{{ __('جميع الحالات') }}</option>
                                        <option value="approved">{{ __('ناجحة') }}</option>
                                        <option value="pending">{{ __('قيد المراجعة') }}</option>
                                        <option value="rejected">{{ __('مرفوضة') }}</option>
                                    </select>
                                    <select id="attempt_referrer_filter" class="form-select form-select-sm">
                                        <option value="">{{ __('جميع المُحيلين') }}</option>
                                    </select>
                                    <input type="search" id="attempt_search" class="form-control form-control-sm"
                                           placeholder="{{ __('بحث بالاسم أو الكود') }}" />
                                </div>
                            </div>
                        </div>
                    </div>
                    <div class="card-body p-0">
                        <div class="table-responsive">
                            <table class="table table-hover mb-0" id="attempts_table" aria-describedby="attemptsSummary"
                                   data-toggle="table" data-url="{{ route('referrals.attempts') }}"
                                   data-side-pagination="server" data-pagination="true" data-page-list="[5, 10, 20, 50]"
                                   data-mobile-responsive="true" data-query-params="attemptsQueryParams"
                                   data-sort-name="created_at" data-sort-order="desc">
                                <thead class="table-light">
                                <tr>
                                    <th scope="col" data-field="id" data-sortable="true">{{ __('الرقم') }}</th>
                                    <th scope="col" data-field="code" data-sortable="true">{{ __('كود الدعوة') }}</th>
                                    <th scope="col" data-field="referrer.name" data-sortable="true">{{ __('المُحيل') }}</th>
                                    <th scope="col" data-field="referred_user.name" data-sortable="true">{{ __('المستخدم المُحال') }}</th>
                                    <th scope="col" data-field="challenge.title" data-sortable="true">{{ __('التحدي') }}</th>
                                    <th scope="col" data-field="status" data-sortable="true" data-formatter="statusBadgeFormatter">
                                        {{ __('الحالة') }}
                                    </th>
                                    <th scope="col" data-field="admin_area" data-sortable="true">{{ __('النطاق الإداري') }}</th>
                                    <th scope="col" data-field="created_at" data-sortable="true" data-formatter="dateFormatter">
                                        {{ __('التاريخ') }}
                                    </th>
                                </tr>
                                </thead>
                            </table>
                        </div>
                    </div>
                </div>
            </div>
            <div class="col-xl-4">
                <div class="card shadow-sm h-100 border-0">
                    <div class="card-header d-flex justify-content-between align-items-center">
                        <h5 class="mb-0">{{ __('مواقع حالات الرفض') }}</h5>
                        <span class="badge bg-danger" id="rejection_locations_count">0</span>
                    </div>
                    <div class="card-body">
                        <div id="rejection_map" class="mb-3"></div>
                        <div class="small text-muted mb-2">{{ __('آخر حالات الرفض حسب الإحداثيات') }}</div>
                        <div class="list-group list-group-flush" id="rejection_locations"></div>
                    </div>
                </div>
            </div>
        </div>
    </section>
@endsection

@section('script')
    <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"
            integrity="sha256-FJn6+JfnWKIf4J+WTDSvCIclVpZhFVcx9c8FeP4K/7c=" crossorigin="anonymous"></script>
    <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"
            integrity="sha256-o9N1j7kP5S0bvvzv+gGZE7q0P5P4Pa09uN1P6zHPCg0=" crossorigin=""></script>
    <script>

        const routes = {
            referralsList: "{{ route('referrals.list') }}",
            referralsTopUsers: "{{ route('referrals.top-users') }}",
            referralsAttempts: "{{ route('referrals.attempts') }}",
            challengesList: "{{ route('challenges.list') }}",
        };
        const challengesIndexUrl = "{{ route('challenges.index') }}";
        let rejectionMapInstance = null;
        let rejectionMarkers = [];
        let challengesChart = null;


        function dateFormatter(value) {
            return value ? moment(value).format('YYYY-MM-DD HH:mm') : '—';
        }

        function statusBadgeFormatter(value) {
            if (!value) {
                return '<span class="badge bg-secondary">—</span>';
            }
            const normalized = value.toString().toLowerCase();
            const badges = {
                approved: 'bg-success',
                pending: 'bg-warning text-dark',
                rejected: 'bg-danger',
            };
            const label = {
                approved: '{{ __('ناجحة') }}',
                pending: '{{ __('قيد المراجعة') }}',
                rejected: '{{ __('مرفوضة') }}',
            };
            const badge = badges[normalized] || 'bg-secondary';
            const text = label[normalized] || value;
            return `<span class="badge ${badge}">${text}</span>`;
        
        
        }

        function referralsQueryParams(params) {
            params.challenge_id = $('#challenge_filter').val();
            params.search = $('#referral_search').val();
            return params;
        }

        function attemptsQueryParams(params) {
            params.status = $('#attempt_status_filter').val();
            params.referrer_id = $('#attempt_referrer_filter').val();
            params.search = $('#attempt_search').val();
            return params;
        }

        function debounce(func, wait) {
            let timeout;
            return function () {
                const context = this;
                const args = arguments;
                clearTimeout(timeout);
                timeout = setTimeout(() => func.apply(context, args), wait);
            };
        }

        function escapeHtml(text) {
            if (text === null || text === undefined) {
                return '';
            }
            return text.toString()
                .replace(/&/g, '&amp;')
                .replace(/</g, '&lt;')
                .replace(/>/g, '&gt;')
                .replace(/"/g, '&quot;')
                .replace(/'/g, '&#039;');
        }

        function initializeMap() {
            if (rejectionMapInstance) {
                return;
            }
            rejectionMapInstance = L.map('rejection_map', {
                center: [15.45, 45.3],
                zoom: 6,
                attributionControl: false,
            });

            L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
                maxZoom: 18,
            }).addTo(rejectionMapInstance);
        }

        function resetMarkers() {
            rejectionMarkers.forEach(marker => marker.remove());
            rejectionMarkers = [];
        }

        function updateRejectionMap(rejections) {
            initializeMap();
            resetMarkers();

            const markers = [];
            rejections.forEach(item => {
                const lat = parseFloat(item.lat);
                const lng = parseFloat(item.lng);
                if (!isNaN(lat) && !isNaN(lng)) {
                    const marker = L.marker([lat, lng]).addTo(rejectionMapInstance);
                    marker.bindPopup(`
                        <strong>${escapeHtml(item.code || '—')}</strong><br>
                        ${escapeHtml(item.admin_area || '{{ __('بدون نطاق') }}')}<br>
                        ${escapeHtml(item.status || '')}
                    `);
                    markers.push(marker);
                    rejectionMarkers.push(marker);
                }
            });

            if (markers.length) {
                const group = L.featureGroup(markers);
                rejectionMapInstance.fitBounds(group.getBounds().pad(0.3));
            } else {
                rejectionMapInstance.setView([15.45, 45.3], 6);
            }
        }

        function updateRejectionList(rejections) {
            const container = $('#rejection_locations');
            container.empty();

            if (!rejections.length) {
                container.append('<div class="list-group-item text-muted">{{ __('لا توجد حالات رفض مسجلة') }}</div>');
                return;
            }

            rejections.slice(0, 8).forEach(item => {
                const admin = escapeHtml(item.admin_area || '{{ __('غير محدد') }}');
                const lat = item.lat ? parseFloat(item.lat).toFixed(4) : '—';
                const lng = item.lng ? parseFloat(item.lng).toFixed(4) : '—';
                const createdAt = item.created_at ? moment(item.created_at).fromNow() : '—';
                container.append(`
                    <div class="list-group-item">
                        <div class="fw-semibold">${escapeHtml(item.code || '—')}</div>
                        <div class="small text-muted">${admin}</div>
                        <div class="small">{{ __('الإحداثيات') }}: ${lat}, ${lng}</div>
                        <div class="small text-muted">${createdAt}</div>
                    </div>
                `);
            });
        }

        function updateStatsFromAttempts(attempts) {
            const normalizedAttempts = attempts || [];
            const approvedAttempts = normalizedAttempts.filter(item => (item.status || '').toLowerCase() === 'approved');
            const rejectedAttempts = normalizedAttempts.filter(item => (item.status || '').toLowerCase() === 'rejected');

            const insideApproved = approvedAttempts.filter(isInsideMarib).length;
            const outsideApproved = approvedAttempts.length - insideApproved;

            $('#stat_inside_marib').text(insideApproved);
            $('#stat_outside_marib').text(outsideApproved);
            $('#stat_rejected').text(rejectedAttempts.length);

            const totalRelevant = approvedAttempts.length + rejectedAttempts.length;
            const ratio = totalRelevant ? ((rejectedAttempts.length / totalRelevant) * 100).toFixed(1) : '0.0';
            $('#stat_rejected_ratio').text(`${ratio}% {{ __('من إجمالي المحاولات') }}`);
            $('#rejection_locations_count').text(rejectedAttempts.length);

            updateRejectionMap(rejectedAttempts);
            updateRejectionList(rejectedAttempts);
            populateReferrerFilter(normalizedAttempts);
        }

        function isInsideMarib(attempt) {
            const adminArea = (attempt.admin_area || '').toString().toLowerCase();
            if (adminArea.includes('مأرب') || adminArea.includes('marib')) {
                return true;
            }

            const lat = parseFloat(attempt.lat);
            const lng = parseFloat(attempt.lng);

            if (isNaN(lat) || isNaN(lng)) {
                return false;
            }

            const withinLat = lat >= 14.5 && lat <= 16.0;
            const withinLng = lng >= 44.5 && lng <= 46.0;
            return withinLat && withinLng;
        }

        function populateReferrerFilter(attempts) {
            const select = $('#attempt_referrer_filter');
            const currentValue = select.val();
            const referrers = {};

            attempts.forEach(item => {
                if (!item.referrer) {
                    return;
                }
                const id = item.referrer.id;
                const name = item.referrer.name || `{{ __('مستخدم') }} #${id}`;
                if (!id) {
                    return;
                }
                referrers[id] = name;
            });

            const entries = Object.entries(referrers).sort((a, b) => a[1].localeCompare(b[1]));
            select.empty();
            select.append('<option value="">{{ __('جميع المُحيلين') }}</option>');
            entries.forEach(([id, name]) => {
                const selected = currentValue && currentValue.toString() === id.toString() ? 'selected' : '';
                select.append(`<option value="${id}" ${selected}>${escapeHtml(name)}</option>`);
            });
        }

        function loadReferralsSummary() {
            $.getJSON(routes.referralsList, {limit: 1}, function (response) {
                $('#stat_total_referrals').text(response.total || 0);
                const hint = response.rows && response.rows.length
                    ? moment(response.rows[0].created_at).fromNow()
                    : '{{ __('لا توجد بيانات حديثة') }}';
                $('#stat_total_referrals_hint').text(hint);
            });
        }

        function loadChallenges() {
            $.getJSON(routes.challengesList, {limit: 100}, function (response) {
                const rows = response.rows || [];
                const challengeFilter = $('#challenge_filter');
                const selected = challengeFilter.val();

                challengeFilter.empty();
                challengeFilter.append('<option value="">{{ __('جميع التحديات') }}</option>');
                rows.forEach(item => {
                    const option = `<option value="${item.id}" ${selected && selected == item.id ? 'selected' : ''}>${escapeHtml(item.title)}</option>`;
                    challengeFilter.append(option);
                });
                const active = rows.filter(item => item.is_active === 1 || item.is_active === true);
                $('#active_challenges_count').text(active.length);
                updateChallengesChart(active);
                updateChallengesQuickList(active);

            });
        }

        function updateChallengesChart(challenges) {
            const canvas = document.getElementById('activeChallengesChart');
            const emptyAlert = $('#active_challenges_empty');



            if (!challenges.length) {
                if (challengesChart) {
                    challengesChart.destroy();
                    challengesChart = null;
                }
                canvas.style.display = 'none';
                emptyAlert.show();
                return;
            }

            canvas.style.display = 'block';
            emptyAlert.hide();

            const labels = challenges.map(item => item.title);
            const data = challenges.map(item => item.required_referrals || 0);
            const backgroundColors = ['#0d6efd', '#198754', '#6610f2', '#ffc107', '#20c997', '#d63384'];
            const datasetColors = labels.map((_, index) => backgroundColors[index % backgroundColors.length]);

            if (challengesChart) {
                challengesChart.destroy();
            }

            challengesChart = new Chart(canvas.getContext('2d'), {
                type: 'bar',
                data: {
                    labels,
                    datasets: [{
                        label: '{{ __('الإحالات المطلوبة') }}',
                        data,
                        backgroundColor: datasetColors,
                        borderRadius: 6,
                    }],
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: {
                        legend: {
                            display: false,
                        },
                        tooltip: {
                            rtl: true,
                            callbacks: {
                                label: context => `${context.formattedValue} {{ __('إحالة') }}`,
                            },
                        },
                    },
                    scales: {
                        x: {
                            ticks: {
                                callback: value => labels[value],
                            },
                        },
                        y: {
                            beginAtZero: true,
                            ticks: {
                                precision: 0,
                            },
                        },
                    },
                },
            });
        }

        function updateChallengesQuickList(challenges) {
            const list = $('#challenge_quick_list');
            list.empty();

            if (!challenges.length) {
                list.append('<li class="list-group-item text-muted">{{ __('لا توجد تحديات نشطة للعرض') }}</li>');
                return;
            }

            challenges.slice(0, 5).forEach(item => {
                list.append(`
                    <li class="list-group-item">
                        <div class="fw-bold mb-1">${escapeHtml(item.title)}</div>
                        <div class="small text-muted">{{ __('الإحالات المطلوبة') }}: ${item.required_referrals || 0}</div>
                        <div class="small text-muted">{{ __('النقاط لكل إحالة') }}: ${item.points_per_referral || 0}</div>
                        <a class="btn btn-sm btn-outline-secondary mt-2" href="${challengesIndexUrl}#challenge-${item.id}">
                            {{ __('تعديل هذا التحدي') }}
                        </a>
                    </li>
                `);

            });

        }

        function loadTopUsers() {
            $.getJSON(routes.referralsTopUsers, function (response) {
                const list = $('#top_users_list');
                list.empty();
                const rows = response.rows || [];

                if (!rows.length) {
                    list.append('<li class="list-group-item text-muted">{{ __('لا توجد بيانات متاحة') }}</li>');
                    return;
                }

                rows.slice(0, 5).forEach(item => {
                    const userObj = item.user || {};
                    const name = userObj.name || item.name || '{{ __('مستخدم غير معروف') }}';
                    const totalPoints = item.total_points || 0;
                    const totalReferrals = item.total_referrals || 0;
                    const completedChallenges = item.completed_challenges || 0;
                    list.append(`
                        <li class="list-group-item d-flex justify-content-between align-items-start">
                            <div>
                                <div class="fw-semibold">${escapeHtml(name)}</div>
                                <div class="small text-muted">{{ __('إجمالي الإحالات') }}: ${totalReferrals}</div>
                                <div class="small text-muted">{{ __('التحديات المكتملة') }}: ${completedChallenges}</div>
                            </div>
                            <span class="badge bg-primary rounded-pill">${totalPoints}</span>
                        </li>
                    `);
                });
            });
        }

        function loadAttemptsSummary() {
            $.getJSON(routes.referralsAttempts, {limit: 'all'}, function (response) {
                updateStatsFromAttempts(response.rows || []);
            });
        }

        function initializeTables() {
            $('#referrals_table').bootstrapTable();
            $('#attempts_table').bootstrapTable();
        }

        function bindFilters() {
            $('#challenge_filter').on('change', function () {
                $('#referrals_table').bootstrapTable('refresh');
            });

            $('#attempt_status_filter, #attempt_referrer_filter').on('change', function () {
                $('#attempts_table').bootstrapTable('refresh');
            });

            const triggerReferralSearch = debounce(function () {
                $('#referrals_table').bootstrapTable('refresh');
            }, 400);
            $('#referral_search').on('input', triggerReferralSearch);

            const triggerAttemptSearch = debounce(function () {
                $('#attempts_table').bootstrapTable('refresh');
            }, 400);
            $('#attempt_search').on('input', triggerAttemptSearch);
        }

        function loadDashboard() {
            loadReferralsSummary();
            loadChallenges();
            loadTopUsers();
            loadAttemptsSummary();
        }

        $(document).ready(function () {
            initializeMap();
            initializeTables();
            bindFilters();
            loadDashboard();

        });
    </script>
@endsection