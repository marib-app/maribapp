@extends('layouts.main')


@section('css')
    @parent
    <link rel="stylesheet" href="https://cdn.datatables.net/1.13.7/css/dataTables.bootstrap5.min.css">
@endsection




@section('title')
    {{ __('Manual Payment Requests') }}
@endsection

@section('page-title')
    <div class="page-title">
        <div class="row">
            <div class="col-12 col-md-6 order-md-1 order-last">
                <h4>@yield('title')</h4>
            </div>
            <div class="col-12 col-md-6 order-md-2 order-first text-md-end">
                <nav aria-label="breadcrumb" class="breadcrumb-header">
                    <ol class="breadcrumb">
                        <li class="breadcrumb-item"><a href="{{ route('home') }}">{{ __('Dashboard') }}</a></li>
                        <li class="breadcrumb-item active" aria-current="page">{{ __('Manual Payment Requests') }}</li>
                    </ol>
                </nav>
            </div>
        </div>
    </div>
@endsection

@section('content')
    <section class="section">


        <div class="row g-3">


            @if(!empty($departmentSummary))
                <div class="col-12">
                    <div class="card shadow-sm border-0 mb-4">
                        <div class="card-body">
                            <div class="d-flex justify-content-between align-items-center mb-4 flex-wrap gap-2">
                                <div>
                                    <h5 class="card-title mb-1">{{ __('Department Performance') }}</h5>
                                    <p class="text-muted small mb-0">{{ __('Review manual payment progress per department at a glance.') }}</p>
                                </div>
                            </div>
                            <div class="row g-3">
                                @foreach($departmentSummary as $department)
                                    <div class="col-xl-4 col-lg-6">
                                        <div class="border rounded-3 p-3 h-100">
                                            <div class="d-flex justify-content-between align-items-start mb-3">
                                                <div>
                                                    <h6 class="mb-1">{{ $department['label'] }}</h6>
                                                    <span class="text-muted small">{{ __('Total Requests') }}: {{ number_format($department['total'] ?? 0) }}</span>
                                                </div>
                                                <button type="button" class="btn btn-outline-primary btn-sm" data-filter-department="{{ $department['key'] }}">
                                                    <i class="fa fa-filter me-1"></i>{{ __('Filter') }}
                                                </button>
                                            </div>
                                            <div class="d-flex flex-wrap gap-2">
                                                <span class="badge bg-warning text-dark">{{ __('Pending') }}: {{ number_format($department[\App\Models\ManualPaymentRequest::STATUS_PENDING] ?? 0) }}</span>
                                                <span class="badge bg-success">{{ __('Approved') }}: {{ number_format($department[\App\Models\ManualPaymentRequest::STATUS_APPROVED] ?? 0) }}</span>
                                                <span class="badge bg-danger">{{ __('Rejected') }}: {{ number_format($department[\App\Models\ManualPaymentRequest::STATUS_REJECTED] ?? 0) }}</span>
                                            </div>
                                        </div>
                                    </div>
                                @endforeach
                            </div>
                        </div>
                    </div>
                </div>
            @endif


            <div class="col-12">
                <div class="row g-3 mb-4">
                    <div class="col-12">
                        <h5 class="fw-bold mb-0">{{ __('Payment Overview') }}</h5>
                    </div>
                    <div class="col-lg-3 col-sm-6">
                        <div class="card shadow-sm border-0 h-100">
                            <div class="card-body">
                                <div class="d-flex justify-content-between align-items-center mb-2">
                                    <small class="text-muted fw-semibold">{{ __('Total Requests') }}</small>
                                    <span class="badge bg-secondary-subtle text-secondary">{{ __('Requests') }}</span>
                                </div>
                                <h3 class="fw-bold mb-0">{{ number_format($summary['total'] ?? 0) }}</h3>
                            </div>
                        </div>
                    </div>
                    <div class="col-lg-3 col-sm-6">
                        <div class="card shadow-sm border-0 h-100">
                            <div class="card-body">
                                <div class="d-flex justify-content-between align-items-center mb-2">
                                    <small class="text-muted fw-semibold">{{ __('Pending Requests') }}</small>
                                    <span class="badge bg-warning text-dark">{{ __('Pending') }}</span>
                                </div>
                                <h3 class="fw-bold mb-0">{{ number_format($summary['pending'] ?? 0) }}</h3>
                            </div>
                        </div>
                    </div>
                    <div class="col-lg-3 col-sm-6">
                        <div class="card shadow-sm border-0 h-100">
                            <div class="card-body">
                                <div class="d-flex justify-content-between align-items-center mb-2">
                                    <small class="text-muted fw-semibold">{{ __('Approved Requests') }}</small>
                                    <span class="badge bg-success">{{ __('Approved') }}</span>
                                </div>
                                <h3 class="fw-bold mb-0">{{ number_format($summary['approved'] ?? 0) }}</h3>
                            </div>
                        </div>
                    </div>
                    <div class="col-lg-3 col-sm-6">
                        <div class="card shadow-sm border-0 h-100">
                            <div class="card-body">
                                <div class="d-flex justify-content-between align-items-center mb-2">
                                    <small class="text-muted fw-semibold">{{ __('Rejected Requests') }}</small>
                                    <span class="badge bg-danger">{{ __('Rejected') }}</span>
                                </div>
                                <h3 class="fw-bold mb-0">{{ number_format($summary['rejected'] ?? 0) }}</h3>
                            </div>
                        </div>
                    </div>


                    <div class="col-12">
                        <p class="text-muted small mb-0">{{ __('Totals shown reflect the entire system (unfiltered).') }}</p>
                    </div>

                </div>
            </div>

            <div class="col-12">
                <div class="card shadow-sm border-0 mb-4">
                    <div class="card-body">
                        <div class="d-flex justify-content-between align-items-center mb-4 flex-wrap gap-2">
                            <h5 class="card-title mb-0">{{ __('Gateway Breakdown') }}</h5>
                            <div class="d-flex flex-wrap gap-2">
                                <span class="badge bg-primary">{{ __('Bank Transfer') }}: {{ number_format($gatewaySummary['manual_bank'] ?? 0) }}</span>
                                <span class="badge bg-success">{{ __('East Yemen Bank') }}: {{ number_format($gatewaySummary['east_yemen_bank'] ?? 0) }}</span>
                                <span class="badge bg-warning text-dark">{{ __('Wallet') }}: {{ number_format($gatewaySummary['wallet'] ?? 0) }}</span>
                            </div>
                        </div>
                        <div class="row g-3">
                            <div class="col-md-4">
                                <div class="border border-primary border-2 rounded-3 p-3 h-100">
                                    <div class="d-flex justify-content-between align-items-center mb-2">
                                        <span class="fw-semibold text-primary">{{ __('Bank Transfer') }}</span>
                                        <span class="badge bg-primary"><i class="fa fa-university"></i></span>
                                    </div>
                                    <div class="d-flex align-items-baseline gap-2">
                                        <h4 class="fw-bold mb-0">{{ number_format($gatewaySummary['manual_bank'] ?? 0) }}</h4>
                                        <span class="text-muted small">{{ __('Requests') }}</span>
                                    </div>
                                </div>
                            </div>
                            <div class="col-md-4">
                                <div class="border border-success border-2 rounded-3 p-3 h-100">
                                    <div class="d-flex justify-content-between align-items-center mb-2">
                                        <span class="fw-semibold text-success">{{ __('East Yemen Bank') }}</span>
                                        <span class="badge bg-success"><i class="fa fa-building-columns"></i></span>
                                    </div>
                                    <div class="d-flex align-items-baseline gap-2">
                                        <h4 class="fw-bold mb-0">{{ number_format($gatewaySummary['east_yemen_bank'] ?? 0) }}</h4>
                                        <span class="text-muted small">{{ __('Requests') }}</span>
                                    </div>
                                </div>
                            </div>
                            <div class="col-md-4">
                                <div class="border border-warning border-2 rounded-3 p-3 h-100">
                                    <div class="d-flex justify-content-between align-items-center mb-2">
                                        <span class="fw-semibold text-warning">{{ __('Wallet') }}</span>
                                        <span class="badge bg-warning text-dark"><i class="fa fa-wallet"></i></span>
                                    </div>
                                    <div class="d-flex align-items-baseline gap-2">
                                        <h4 class="fw-bold mb-0">{{ number_format($gatewaySummary['wallet'] ?? 0) }}</h4>
                                        <span class="text-muted small">{{ __('Requests') }}</span>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <div class="col-12">
                <div class="card shadow-sm border-0 mb-4">
                    <div class="card-body">
                        <div class="d-flex flex-column flex-lg-row justify-content-between align-items-start align-items-lg-center gap-3">
                            <div>
                                <h5 class="card-title mb-1">{{ __('Quick Actions') }}</h5>
                                <p class="text-muted small mb-0">{{ __('Focus on specific payment requests instantly.') }}</p>
                            </div>
                            <div class="d-flex flex-column flex-lg-row gap-2 w-100 justify-content-lg-end">
                                <div class="btn-group" role="group">
                                    <button type="button" class="btn btn-outline-primary btn-sm" data-filter-status="pending">{{ __('View Pending') }}</button>
                                    <button type="button" class="btn btn-outline-success btn-sm" data-filter-status="approved">{{ __('View Approved') }}</button>
                                    <button type="button" class="btn btn-outline-danger btn-sm" data-filter-status="rejected">{{ __('View Rejected') }}</button>
                                </div>
                                <div class="btn-group" role="group">
                                    <button type="button" class="btn btn-outline-primary btn-sm" data-filter-gateway="manual_bank">{{ __('View Bank Transfers') }}</button>
                                    <button type="button" class="btn btn-outline-success btn-sm" data-filter-gateway="east_yemen_bank">{{ __('View East Yemen Bank') }}</button>
                                    <button type="button" class="btn btn-outline-warning btn-sm" data-filter-gateway="wallet">{{ __('View Wallet') }}</button>
                                </div>


                                @if(!empty($departmentSummary))
                                    <div class="btn-group" role="group">
                                        @foreach($departmentSummary as $department)
                                            <button type="button" class="btn btn-outline-dark btn-sm d-flex align-items-center gap-2" data-filter-department="{{ $department['key'] }}">
                                                <span>{{ $department['label'] }}</span>
                                                <span class="badge bg-secondary text-light">{{ number_format($department['total'] ?? 0) }}</span>
                                            </button>
                                        @endforeach
                                    </div>
                                @endif

                                <button type="button" class="btn btn-outline-secondary btn-sm active" data-filter-reset>{{ __('Show All') }}</button>
                            </div>
                        </div>
                    </div>
                </div>
            </div>



    <div class="col-12">
                <div class="card mb-3 shadow-sm border-0">
                    <div class="card-header d-flex justify-content-between align-items-center">
                        <h5 class="card-title mb-0">{{ __('Advanced Filters') }}</h5>
                        <button type="button" class="btn btn-link text-decoration-none" data-bs-toggle="collapse"
                                data-bs-target="#manual-payment-filter-body" aria-expanded="false">
                            <i class="fa fa-filter me-1"></i>{{ __('Toggle Filters') }}
                        </button>
                    </div>
                    <div class="collapse" id="manual-payment-filter-body">
                        <div class="card-body">
                            <form id="manual-payment-filters" class="row g-3">
                                <div class="col-md-4 col-lg-3">
                                    <label for="filter-search" class="form-label">{{ __('Search') }}</label>
                                    <input type="text" class="form-control" id="filter-search" name="search"
                                           placeholder="{{ __('Reference, user or gateway') }}">
                                </div>
                                <div class="col-md-4 col-lg-2">
                                    <label for="filter-status" class="form-label">{{ __('Status') }}</label>
                                    <select class="form-select" id="filter-status" name="status">
                                        <option value="">{{ __('All') }}</option>
                                        @foreach($statuses as $key => $label)
                                            <option value="{{ $key }}">{{ $label }}</option>
                                        @endforeach
                                    </select>
                                </div>
                                <div class="col-md-4 col-lg-2">
                                    <label for="filter-payment-gateway" class="form-label">{{ __('Payment Gateway') }}</label>
                                    <select class="form-select" id="filter-payment-gateway" name="payment_gateway">
                                        <option value="">{{ __('All') }}</option>

                                        <option value="manual_bank">{{ __('Bank Transfer') }}</option>
                                        <option value="east_yemen_bank">{{ __('East Yemen Bank') }}</option>
                                        <option value="wallet">{{ __('Wallet') }}</option>

                                        @foreach($paymentGateways as $key => $label)
                                            @if(!in_array($key, ['manual_bank', 'east_yemen_bank', 'wallet'], true))
                                                <option value="{{ $key }}">{{ $label }}</option>
                                            @endif
                                            
                                            @endforeach
                                    </select>
                                </div>

                                <div class="col-md-4 col-lg-2">
                                    <label for="filter-payable-type" class="form-label">{{ __('Payable Type') }}</label>
                                    <select class="form-select" id="filter-payable-type" name="payable_type">
                                        <option value="">{{ __('All') }}</option>
                                        @foreach($payableTypes as $key => $label)
                                            <option value="{{ $key }}">{{ $label }}</option>
                                        @endforeach
                                    </select>
                                </div>



                                <div class="col-md-4 col-lg-2">
                                    <label for="filter-department" class="form-label">{{ __('Department') }}</label>
                                    <select class="form-select" id="filter-department" name="department">
                                        <option value="">{{ __('All') }}</option>
                                        @foreach($departments as $key => $label)
                                            <option value="{{ $key }}">{{ $label }}</option>
                                        @endforeach
                                    </select>
                                </div>

                                <div class="col-md-4 col-lg-2">
                                    <label for="filter-date-from" class="form-label">{{ __('Date From') }}</label>
                                    <input type="date" class="form-control" id="filter-date-from" name="from">

                                </div>
                                <div class="col-md-4 col-lg-2">
                                    <label for="filter-date-to" class="form-label">{{ __('Date To') }}</label>
                                    <input type="date" class="form-control" id="filter-date-to" name="to">
                                </div>
                                <div class="col-12 d-flex gap-2 justify-content-end mt-3">
                                    <button type="submit" class="btn btn-primary">
                                        <i class="fa fa-search me-1"></i>{{ __('Apply Filters') }}
                                    </button>
                                    <button type="button" class="btn btn-outline-secondary" id="manual-payment-reset">
                                        <i class="fa fa-undo me-1"></i>{{ __('Clear Filters') }}
                                    </button>
                                </div>
                            </form>
                        </div>
                    </div>
                </div>
            </div>

            <div class="col-12">
                <div class="card shadow-sm border-0">
                    <div class="card-body">

                        <div class="mb-3">
                            <label for="manual-payment-transaction-search" class="form-label">{{ __('Search by Transaction ID') }}</label>
                            <input type="text" id="manual-payment-transaction-search" class="form-control" placeholder="{{ __('Search by Transaction ID') }}">
                        </div>

                        <table class="table table-borderless table-striped" id="manual-payments-table" style="width:100%">

                            <thead>
                            <tr>
                                <th>{{ __('Transaction ID') }}</th>

                                <th>{{ __('User') }}</th>
                                <th>{{ __('Amount') }}</th>
                                <th>{{ __('Currency') }}</th>
                                <th>{{ __('Gateway') }}</th>
                                <th>{{ __('Payable Type') }}</th>
                                <th>{{ __('Status') }}</th>
                                <th>{{ __('Submitted At') }}</th>
                                <th class="text-center">{{ __('Actions') }}</th>
                            </tr>
                            </thead>
                            <tbody></tbody>


                        </table>

                        <div class="mt-3">
                            <div id="manual-payment-meta" class="small text-muted"></div>
                            
                            <div id="manual-payment-feedback" class="small mt-1"></div>



                        </div>

                    </div>
                </div>
            </div>
        </div>
    </section>


@endsection





@section('js')
    @parent
    <script src="https://cdn.datatables.net/1.13.7/js/jquery.dataTables.min.js"></script>
    <script src="https://cdn.datatables.net/1.13.7/js/dataTables.bootstrap5.min.js"></script>
@endsection



@section('script')
    <script>

        const MANUAL_PAYMENT_FILTER_STORAGE_KEY = 'mpr_filters_v2';
        const MANUAL_PAYMENT_FILTER_KEYS = ['search', 'status', 'payment_gateway', 'payable_type', 'department', 'from', 'to'];

        const MANUAL_PAYMENT_STATUS_MAP = {
            pending: 'pending',
            in_review: 'pending',
            'in-review': 'pending',
            review: 'pending',
            approved: 'approved',
            accepted: 'approved',
            completed: 'approved',
            rejected: 'rejected',
            declined: 'rejected'
        };


        const MANUAL_PAYMENT_GATEWAY_MAP = {
            manual: 'manual_bank',
            manual_bank: 'manual_bank',
            'manual-bank': 'manual_bank',
            manualbank: 'manual_bank',
            east: 'east_yemen_bank',
            east_yemen_bank: 'east_yemen_bank',
            'east-yemen-bank': 'east_yemen_bank',
            eastyemenbank: 'east_yemen_bank',


            wallet: 'wallet'
        };




        const MANUAL_PAYMENT_GATEWAY_STYLES = {
            manual_bank: 'bg-primary',
            east_yemen_bank: 'bg-success',
            wallet: 'bg-warning text-dark'
        };

        const MANUAL_PAYMENT_STATUS_STYLES = {
            approved: 'bg-success',
            pending: 'bg-warning text-dark',
            rejected: 'bg-danger'
        };



        const manualPaymentNumberFormatter = (function () {
            if (typeof Intl !== 'undefined' && typeof Intl.NumberFormat === 'function') {
                const formatter = new Intl.NumberFormat('ar-EG');
                return (value) => formatter.format(Number(value) || 0);
            }

            return (value) => String(Number(value) || 0);
        })();

        let manualPaymentFilters = loadInitialManualPaymentFilters();




        document.addEventListener('DOMContentLoaded', () => {
            if (!manualPaymentFilters || Object.keys(manualPaymentFilters).length === 0) {
                return;
            }

            const filterBody = document.getElementById('manual-payment-filter-body');
            if (filterBody && typeof bootstrap !== 'undefined' && typeof bootstrap.Collapse === 'function') {
                const collapseInstance = bootstrap.Collapse.getOrCreateInstance(filterBody, {toggle: false});
                collapseInstance.show();
            }

            const filterToggleButton = document.querySelector('[data-bs-target="#manual-payment-filter-body"]');
            if (filterToggleButton) {
                filterToggleButton.setAttribute('aria-expanded', 'true');
            }
        });




        let manualPaymentLastRequestStart = 0;
        let manualPaymentForceFirstPage = false;


        function normalizeManualPaymentStatus(value) {
            if (typeof value !== 'string') {
                return null;
            }

            const normalized = value.trim().toLowerCase();

            if (normalized === '') {
                return null;
            }

            if (Object.prototype.hasOwnProperty.call(MANUAL_PAYMENT_STATUS_MAP, normalized)) {
                return MANUAL_PAYMENT_STATUS_MAP[normalized];
            }

            return ['pending', 'approved', 'rejected'].includes(normalized) ? normalized : null;
        }

        function normalizeManualPaymentGateway(value) {
            if (typeof value !== 'string') {
                return null;
            }

            const normalized = value.trim().toLowerCase();

            if (normalized === '') {
                return null;
            }

            return MANUAL_PAYMENT_GATEWAY_MAP[normalized] ?? normalized;
        }

        function normalizeManualPaymentFilterValue(key, value) {
            if (value === undefined || value === null) {
                return null;
            }

            if (typeof value !== 'string') {
                return value;
            }

            const trimmed = value.trim();

            if (trimmed === '' || trimmed.toLowerCase() === 'null') {
                return null;
            }

            if (key === 'status') {
                return normalizeManualPaymentStatus(trimmed);
            }

            if (key === 'payment_gateway') {
                return normalizeManualPaymentGateway(trimmed);
            }

            return trimmed;
        }



        function loadInitialManualPaymentFilters() {
            const filters = {};
            const storedRaw = localStorage.getItem(MANUAL_PAYMENT_FILTER_STORAGE_KEY);


            if (storedRaw) {
                try {
                    const parsed = JSON.parse(storedRaw);
                    if (parsed && typeof parsed === 'object') {
                        Object.entries(parsed).forEach(([key, value]) => {
                            const normalized = normalizeManualPaymentFilterValue(key, value);
                            if (normalized !== null && normalized !== '') {
                                filters[key] = normalized;
                            }
                        });
                    }

                } catch (error) {
                    console.warn('Failed to parse stored manual payment filters', error);


                }

            }

            try {
                const url = new URL(window.location.href);
                MANUAL_PAYMENT_FILTER_KEYS.forEach((key) => {
                    if (!url.searchParams.has(key)) {
                        return;
                    }

                    const normalized = normalizeManualPaymentFilterValue(key, url.searchParams.get(key));

                    if (normalized === null || normalized === '') {
                        delete filters[key];
                    } else {
                        filters[key] = normalized;
                    }
                });
            } catch (error) {
                console.warn('Failed to parse manual payment filters from URL', error);
            }




            return filters;

        }


        function persistManualPaymentFilters() {
            try {
                localStorage.setItem(MANUAL_PAYMENT_FILTER_STORAGE_KEY, JSON.stringify(manualPaymentFilters));
            } catch (error) {
                console.warn('Failed to persist manual payment filters', error);
            }
        }


        function hydrateManualPaymentFilters($form) {



            Object.entries(manualPaymentFilters).forEach(([key, value]) => {
                const $field = $form.find(`[name="${key}"]`);
                if ($field.length) {
                    $field.val(value);
                }
            });




        }

        function updateQuickFilterButtons() {
            const status = normalizeManualPaymentStatus(manualPaymentFilters.status ?? '') ?? '';
            const gateway = normalizeManualPaymentGateway(manualPaymentFilters.payment_gateway ?? '') ?? '';
            const department = normalizeManualPaymentFilterValue('department', manualPaymentFilters.department ?? '') ?? '';
            const search = normalizeManualPaymentFilterValue('search', manualPaymentFilters.search ?? '') ?? '';



            $('[data-filter-status]').each(function () {
                const value = normalizeManualPaymentStatus($(this).data('filter-status')) ?? '';
                $(this).toggleClass('active', value !== '' && value === status);


            });

            $('[data-filter-gateway]').each(function () {
                const value = normalizeManualPaymentGateway($(this).data('filter-gateway')) ?? '';
                $(this).toggleClass('active', value !== '' && value === gateway);


            });


            $('[data-filter-department]').each(function () {
                const rawValue = $(this).data('filter-department');
                const value = normalizeManualPaymentFilterValue(
                    'department',
                    typeof rawValue === 'string' ? rawValue : (rawValue ?? '')
                ) ?? '';

                $(this).toggleClass('active', value !== '' && value === department);
            });

            const hasActiveFilters = MANUAL_PAYMENT_FILTER_KEYS.some((key) => {

                if (key === 'status') {
                    return status !== '';
                }

                if (key === 'payment_gateway') {
                    return gateway !== '';
                }


                if (key === 'department') {
                    return department !== '';
                }


                if (key === 'search') {
                    return search !== '';
                }

                const value = manualPaymentFilters[key];

                if (value === undefined || value === null) {
                    return false;
                }

                if (typeof value === 'string') {
                    return value.trim() !== '';
                }

                return true;
            });

            $('[data-filter-reset]').toggleClass('active', !hasActiveFilters);

        }






        function setManualPaymentFeedback(message = '', type = '') {
            const $feedback = $('#manual-payment-feedback');
            $feedback.removeClass('text-danger text-info text-success text-muted');

            if (!message) {
                $feedback.text('');
                return;
            }

            let className = 'text-muted';

            if (type === 'danger') {
                className = 'text-danger';
            } else if (type === 'info') {
                className = 'text-info';
            } else if (type === 'success') {
                className = 'text-success';
            }

            $feedback.addClass(className).text(message);
        }


       function updateManualPaymentMeta(info, json) {
            const $meta = $('#manual-payment-meta');

            if (!info) {
                $meta.text('');
                return;
            }

            const totalLabel = '{{ __('Total records') }}';
            const filteredLabel = '{{ __('Filtered results') }}';
            const pageLabel = '{{ __('Page') }}';
            const ofLabel = '{{ __('of') }}';

            const total = Number(json?.recordsTotal ?? info.recordsTotal ?? 0);
            const filtered = Number(json?.recordsFiltered ?? info.recordsDisplay ?? 0);
            const currentPage = Number(info.page ?? 0) + 1;
            const lastPage = Number(info.pages ?? 0) || 1;

            const parts = [
                `${totalLabel}: ${manualPaymentNumberFormatter(total)}`,
                `${filteredLabel}: ${manualPaymentNumberFormatter(filtered)}`,
                `${pageLabel} ${manualPaymentNumberFormatter(currentPage)} ${ofLabel} ${manualPaymentNumberFormatter(lastPage)}`
            ];

            $meta.text(parts.join(' • '));
        }

        function syncManualPaymentQueryString(info) {
            try {
                const url = new URL(window.location.href);

                MANUAL_PAYMENT_FILTER_KEYS.forEach((key) => {
                    const value = manualPaymentFilters[key];
                    if (value === undefined || value === null || value === '') {
                        url.searchParams.delete(key);
                    } else {
                        url.searchParams.set(key, value);
                    }
                });

                if (info) {
                    url.searchParams.set('page', (info.page ?? 0) + 1);
                    url.searchParams.set('length', info.length ?? 10);
                } else {
                    url.searchParams.delete('page');
                    url.searchParams.delete('length');
                }

                url.searchParams.delete('per_page');
                url.searchParams.delete('limit');
                url.searchParams.delete('current_page');

                window.history.replaceState({}, '', url.toString());
            } catch (error) {
                console.warn('Failed to sync manual payment query string', error);
            }
        }



        function applyManualPaymentFiltersFromForm($form, dataTable) {
            const formData = $form.serializeArray();
            const filters = {};

            formData.forEach((field) => {
                const normalized = normalizeManualPaymentFilterValue(field.name, field.value);
                if (normalized !== null && normalized !== '') {
                    filters[field.name] = normalized;
                }
            });




            manualPaymentFilters = filters;
            persistManualPaymentFilters();
            const $transactionSearch = $('#manual-payment-transaction-search');
            if ($transactionSearch.length) {
                $transactionSearch.val(manualPaymentFilters.search ?? '');
            }

            updateQuickFilterButtons();
            setManualPaymentFeedback('');
            dataTable.page('first').draw(false);
        }

        $(function () {
            const $table = $('#manual-payments-table');
            const $form = $('#manual-payment-filters');

            hydrateManualPaymentFilters($form);
            updateQuickFilterButtons();

            const dataTable = $table.DataTable({
                processing: true,
                serverSide: true,
                deferLoading: 0,
                searching: false,
                lengthMenu: [10, 20, 50, 100],
                ajax: {
                    url: '{{ route('manual-payments.table') }}',
                    data: function (params) {
                        const filters = { ...manualPaymentFilters };
                        const searchValue = filters.search ?? '';

                        if (!params.search) {
                            params.search = { value: '', regex: false };
                        }

                        params.search.value = searchValue;

                        MANUAL_PAYMENT_FILTER_KEYS.forEach((key) => {
                            if (key === 'search') {
                                return;
                            }

                            if (filters[key] !== undefined) {
                                params[key] = filters[key];
                            } else {
                                delete params[key];
                            }
                        });
                    },
                    dataSrc: function (json) {
                        if (!json || typeof json !== 'object') {
                            setManualPaymentFeedback('{{ __('Unable to load manual payment requests. Please try again later.') }}', 'danger');
                            return [];
                        }

                        return Array.isArray(json.data) ? json.data : [];
                    },
                    error: function () {
                        setManualPaymentFeedback('{{ __('Unable to load manual payment requests. Please try again later.') }}', 'danger');
                    }
                },
                order: [[7, 'desc']],
                columns: [
                    {
                        data: 'transaction_id',
                        defaultContent: '—',
                        render: function (data) {
                            return data ?? '—';
                        }
                    },
                    { data: 'user_name', defaultContent: '—' },
                    { data: 'amount_fmt', defaultContent: '0.00', className: 'text-end text-nowrap' },
                    { data: 'currency', defaultContent: '' },
                    {
                        data: 'payment_gateway_label',
                        defaultContent: '—',
                        render: function (data, type, row) {
                            if (type !== 'display') {
                                return data ?? '';
                            }

                            const key = normalizeManualPaymentGateway(row?.payment_gateway ?? '') ?? '';
                            const classes = MANUAL_PAYMENT_GATEWAY_STYLES[key] ?? 'bg-secondary';
                            const label = data ?? '—';

                            return '<span class="badge ' + classes + '">' + label + '</span>';
                        }
                    },
                    { data: 'payable_label', defaultContent: '—' },
                    {
                        data: 'status_label',
                        defaultContent: '—',
                        render: function (data, type, row) {
                            if (type !== 'display') {
                                return data ?? '';
                            }

                            const key = normalizeManualPaymentStatus(row?.status ?? '') ?? '';
                            const classes = MANUAL_PAYMENT_STATUS_STYLES[key] ?? 'bg-secondary';
                            const label = data ?? '—';

                            return '<span class="badge ' + classes + '">' + label + '</span>';
                        }
                    },
                    { data: 'created_at_human', defaultContent: '—', className: 'text-nowrap' },
                    {
                        data: 'actions',
                        orderable: false,
                        searchable: false,
                        defaultContent: '',
                        className: 'text-center text-nowrap',
                        render: function (data, type) {
                            if (type === 'display') {
                                return data ?? '';
                            }



                            const element = document.createElement('div');
                            element.innerHTML = data ?? '';
                            return element.textContent || '';
                        }
                    }
                ],
                language: {
                    emptyTable: '{{ __('No manual payments found for the current filters.') }}'
                }
            });


            const $transactionSearch = $('#manual-payment-transaction-search');
            if ($transactionSearch.length) {
                const initialSearch = manualPaymentFilters.search ?? '';
                if (initialSearch) {
                    $transactionSearch.val(initialSearch);
                }

                $transactionSearch.on('input', function () {
                    const rawValue = $(this).val();
                    const normalized = normalizeManualPaymentFilterValue('search', rawValue);

                    if (normalized === null || normalized === '') {
                        delete manualPaymentFilters.search;
                        $('#filter-search').val('');
                    } else {
                        manualPaymentFilters.search = normalized;
                        $('#filter-search').val(normalized);
                    }

                    persistManualPaymentFilters();
                    updateQuickFilterButtons();
                    setManualPaymentFeedback('');
                    dataTable.page('first').draw(false);
                });
            }



            dataTable.on('preXhr.dt', function (event, settings, params) {
                manualPaymentLastRequestStart = params.start || 0;
            });


            dataTable.on('xhr.dt', function (event, settings, json) {
                const rows = Array.isArray(json?.data) ? json.data : [];
                const filtered = Number(json?.recordsFiltered ?? 0);



                if (!manualPaymentForceFirstPage && rows.length === 0 && filtered > 0 && manualPaymentLastRequestStart > 0) {
                    manualPaymentForceFirstPage = true;
                    dataTable.page('first').draw(false);
                    return;
                }


                manualPaymentForceFirstPage = false;
   

                const info = dataTable.page.info();
                updateManualPaymentMeta(info, json);
                syncManualPaymentQueryString(info);


                if (filtered === 0) {
                    setManualPaymentFeedback('{{ __('No manual payments found for the current filters.') }}', 'info');
                } else {
                    setManualPaymentFeedback('');



                }
            });
            dataTable.on('error.dt', function () {
                setManualPaymentFeedback('{{ __('Unable to load manual payment requests. Please try again later.') }}', 'danger');
            });






            $form.on('submit', function (event) {
                event.preventDefault();
                applyManualPaymentFiltersFromForm($form, dataTable);
            });

            $('#manual-payment-reset').on('click', function () {
                manualPaymentFilters = {};
                persistManualPaymentFilters();


                $form[0].reset();
                $('#manual-payment-transaction-search').val('');


                updateQuickFilterButtons();
                setManualPaymentFeedback('');

                dataTable.page('first').draw(false);

            });

            $('[data-filter-status]').on('click', function () {
                const rawValue = $(this).data('filter-status');
                const normalized = normalizeManualPaymentStatus(rawValue);
                const current = normalizeManualPaymentStatus($('#filter-status').val());

                $('#filter-status').val(normalized && normalized === current ? '' : (normalized ?? ''));


                applyManualPaymentFiltersFromForm($form, dataTable);
            });

            $('[data-filter-gateway]').on('click', function () {
                const rawValue = $(this).data('filter-gateway');
                const normalized = normalizeManualPaymentGateway(rawValue);
                const current = normalizeManualPaymentGateway($('#filter-payment-gateway').val());

                $('#filter-payment-gateway').val(normalized && normalized === current ? '' : (normalized ?? ''));


                applyManualPaymentFiltersFromForm($form, dataTable);
            });


            $('[data-filter-department]').on('click', function () {
                const rawValue = $(this).data('filter-department');
                const normalized = normalizeManualPaymentFilterValue(
                    'department',
                    typeof rawValue === 'string' ? rawValue : (rawValue ?? '')
                );
                const current = normalizeManualPaymentFilterValue('department', $('#filter-department').val());

                $('#filter-department').val(normalized && normalized === current ? '' : (normalized ?? ''));


                applyManualPaymentFiltersFromForm($form, dataTable);
            });


            $('[data-filter-reset]').on('click', function () {
                $('#manual-payment-reset').trigger('click');
            });

            window.addEventListener('manual-payment-refresh', function () {
                dataTable.draw(false);


            });


        });





    </script>
@endsection