@extends('layouts.main')


@section('css')
    @parent
    <link rel="stylesheet" href="https://cdn.datatables.net/1.13.7/css/dataTables.bootstrap5.min.css">
@endsection




@section('title')
    {{ __('Payment Requests') }}
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
                        <li class="breadcrumb-item active" aria-current="page">{{ __('Payment Requests') }}</li>
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
                                                    <span class="text-muted small">{{ __('Total Requests') }}:
                                                        <span data-summary-department-key="{{ $department['key'] }}" data-summary-department-field="total">{{ number_format($department['total'] ?? 0) }}</span>
                                                    </span>
                                                
                                                </div>
                                                <button type="button" class="btn btn-outline-primary btn-sm" data-filter-department="{{ $department['key'] }}">
                                                    <i class="fa fa-filter me-1"></i>{{ __('Filter') }}
                                                </button>
                                            </div>
                                            <div class="d-flex flex-wrap gap-2">
                                                <span class="badge bg-warning text-dark">{{ __('Pending') }}:
                                                    <span data-summary-department-key="{{ $department['key'] }}" data-summary-department-field="pending">{{ number_format($department['pending'] ?? 0) }}</span>
                                                </span>
                                                <span class="badge bg-success">{{ __('Success') }}:
                                                    <span data-summary-department-key="{{ $department['key'] }}" data-summary-department-field="succeed">{{ number_format($department['succeed'] ?? 0) }}</span>
                                                </span>
                                                <span class="badge bg-danger">{{ __('Failed') }}:
                                                    <span data-summary-department-key="{{ $department['key'] }}" data-summary-department-field="failed">{{ number_format($department['failed'] ?? 0) }}</span>
                                                </span>
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
                                <h3 class="fw-bold mb-0" data-summary-field="total">{{ number_format($summary['total'] ?? 0) }}</h3>
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
                                <h3 class="fw-bold mb-0" data-summary-field="pending">{{ number_format($summary['pending'] ?? 0) }}</h3>
                            </div>
                        </div>
                    </div>

                    <div class="col-lg-3 col-sm-6">
                        <div class="card shadow-sm border-0 h-100">
                            <div class="card-body">
                                <div class="d-flex justify-content-between align-items-center mb-2">
                                    <small class="text-muted fw-semibold">{{ __('Successful Requests') }}</small>
                                    <span class="badge bg-success">{{ __('Success') }}</span>
                                </div>
                                <h3 class="fw-bold mb-0" data-summary-field="succeed">{{ number_format($summary['succeed'] ?? 0) }}</h3>

                            </div>
                        </div>
                    </div>

                    <div class="col-lg-3 col-sm-6">
                        <div class="card shadow-sm border-0 h-100">
                            <div class="card-body">
                                <div class="d-flex justify-content-between align-items-center mb-2">
                                    <small class="text-muted fw-semibold">{{ __('Failed Requests') }}</small>
                                    <span class="badge bg-danger">{{ __('Failed') }}</span>
                                </div>
                                <h3 class="fw-bold mb-0" data-summary-field="failed">{{ number_format($summary['failed'] ?? 0) }}</h3>

                            </div>
                        </div>
                    </div>
                    <div class="col-lg-3 col-sm-6">
                        <div class="card shadow-sm border-0 h-100">
                            <div class="card-body">
                                <div class="d-flex justify-content-between align-items-center mb-2">
                                    <small class="text-muted fw-semibold">{{ __('Total Amount') }}</small>
                                    <span class="badge bg-dark text-white">{{ __('Value') }}</span>
                                </div>
                                <h3 class="fw-bold mb-0" data-summary-field="amount">{{ number_format($summary['amount'] ?? 0, 2) }}</h3>
                            </div>
                        </div>
                    </div>


                    <div class="col-12">
                        <p class="text-muted small mb-0" data-summary-note>{{ __('Totals shown reflect the entire system (unfiltered).') }}</p>
                    </div>

                </div>
            </div>

            <div class="col-12">
                <div class="card shadow-sm border-0 mb-4">
                    <div class="card-body">
                        <div class="d-flex justify-content-between align-items-center mb-4 flex-wrap gap-2">
                            <h5 class="card-title mb-0">{{ __('Gateway Breakdown') }}</h5>
                            <div class="d-flex flex-wrap gap-2">
                                <span class="badge bg-primary">{{ __('East Yemen Bank') }}: <span data-summary-gateway="east_yemen_bank">{{ number_format($gatewaySummary['east_yemen_bank'] ?? 0) }}</span></span>
                                <span class="badge bg-info text-dark">{{ __('Bank Transfer') }}: <span data-summary-gateway="manual_banks">{{ number_format($gatewaySummary['manual_banks'] ?? 0) }}</span></span>
                                <span class="badge bg-warning text-dark">{{ __('Wallet') }}: <span data-summary-gateway="wallet">{{ number_format($gatewaySummary['wallet'] ?? 0) }}</span></span>
                                <span class="badge bg-success">{{ __('Cash') }}: <span data-summary-gateway="cash">{{ number_format($gatewaySummary['cash'] ?? 0) }}</span></span>


                            </div>
                        </div>
                        <div class="row g-3">
                            <div class="col-md-3 col-sm-6">

                                <div class="border border-primary border-2 rounded-3 p-3 h-100">
                                    <div class="d-flex justify-content-between align-items-center mb-2">
                                        <span class="fw-semibold text-primary">{{ __('East Yemen Bank') }}</span>
                                        <span class="badge bg-primary"><i class="fa fa-university"></i></span>
                                    </div>
                                    <div class="d-flex align-items-baseline gap-2">
                                        <h4 class="fw-bold mb-0" data-summary-gateway="east_yemen_bank">{{ number_format($gatewaySummary['east_yemen_bank'] ?? 0) }}</h4>

                                        <span class="text-muted small">{{ __('Requests') }}</span>
                                    </div>
                                </div>
                            </div>
                            <div class="col-md-3 col-sm-6">
                                <div class="border border-info border-2 rounded-3 p-3 h-100">
                                    <div class="d-flex justify-content-between align-items-center mb-2">
                                        <span class="fw-semibold text-info">{{ __('Bank Transfer') }}</span>
                                        <span class="badge bg-info text-dark"><i class="fa fa-user-cog"></i></span>
                                    </div>
                                    <div class="d-flex align-items-baseline gap-2">
                                        <h4 class="fw-bold mb-0 text-info" data-summary-gateway="manual_banks">{{ number_format($gatewaySummary['manual_banks'] ?? 0) }}</h4>

                                        <span class="text-muted small">{{ __('Requests') }}</span>
                                    </div>
                                </div>
                            </div>
                            <div class="col-md-3 col-sm-6">

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

                            <div class="col-md-3 col-sm-6">
                                <div class="border border-success border-2 rounded-3 p-3 h-100">
                                    <div class="d-flex justify-content-between align-items-center mb-2">
                                        <span class="fw-semibold text-success">{{ __('Cash') }}</span>
                                        <span class="badge bg-success"><i class="fa fa-money-bill-wave"></i></span>
                                    </div>
                                    <div class="d-flex align-items-baseline gap-2">
                                        <h4 class="fw-bold mb-0" data-summary-gateway="cash">{{ number_format($gatewaySummary['cash'] ?? 0) }}</h4>
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
                        <h5 class="card-title mb-3">{{ __('Category Breakdown') }}</h5>
                        <div class="row g-3">
                            <div class="col-md-4">
                                <div class="border border-secondary border-2 rounded-3 p-3 h-100">
                                    <div class="d-flex justify-content-between align-items-center mb-2">
                                        <span class="fw-semibold text-secondary">{{ __('Orders') }}</span>
                                        <span class="badge bg-secondary"><i class="fa fa-shopping-cart"></i></span>
                                    </div>
                                    <div class="d-flex align-items-baseline gap-2">
                                        <h4 class="fw-bold mb-0" data-summary-category="orders">{{ number_format($categorySummary['orders'] ?? 0) }}</h4>
                                        <span class="text-muted small">{{ __('Requests') }}</span>
                                    </div>
                                </div>
                            </div>
                            <div class="col-md-4">
                                <div class="border border-info border-2 rounded-3 p-3 h-100">
                                    <div class="d-flex justify-content-between align-items-center mb-2">
                                        <span class="fw-semibold text-info">{{ __('Packages') }}</span>
                                        <span class="badge bg-info text-dark"><i class="fa fa-box"></i></span>
                                    </div>
                                    <div class="d-flex align-items-baseline gap-2">
                                        <h4 class="fw-bold mb-0" data-summary-category="packages">{{ number_format($categorySummary['packages'] ?? 0) }}</h4>
                                        <span class="text-muted small">{{ __('Requests') }}</span>
                                    </div>
                                </div>

                            </div>
                            <div class="col-md-4">
                                <div class="border border-warning border-2 rounded-3 p-3 h-100">
                                    <div class="d-flex justify-content-between align-items-center mb-2">
                                        <span class="fw-semibold text-warning">{{ __('Wallet Top-up') }}</span>
                                        <span class="badge bg-warning text-dark"><i class="fa fa-arrow-up"></i></span>
                                    </div>
                                    <div class="d-flex align-items-baseline gap-2">
                                        <h4 class="fw-bold mb-0" data-summary-category="top_ups">{{ number_format($categorySummary['top_ups'] ?? 0) }}</h4>
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
                                      <button type="button" class="btn btn-outline-success btn-sm" data-filter-status="succeed">{{ __('View Successful') }}</button>
                                      <button type="button" class="btn btn-outline-danger btn-sm" data-filter-status="failed">{{ __('View Failed') }}</button>
                                  </div>
                                  <div class="btn-group" role="group">
                                      <button type="button" class="btn btn-outline-primary btn-sm" data-filter-gateway="east_yemen_bank">{{ __('View East Yemen Bank') }}</button>
                                      <button type="button" class="btn btn-outline-dark btn-sm" data-filter-gateway="manual_banks">{{ __('View Bank Transfers') }}</button>

                                      <button type="button" class="btn btn-outline-warning btn-sm" data-filter-gateway="wallet">{{ __('View Wallet') }}</button>
                                      <button type="button" class="btn btn-outline-success btn-sm" data-filter-gateway="cash">{{ __('View Cash') }}</button>
                                  </div>
                                  <div class="btn-group" role="group">
                                      <button type="button" class="btn btn-outline-secondary btn-sm" data-filter-category="orders">{{ __('View Orders') }}</button>
                                      <button type="button" class="btn btn-outline-info btn-sm" data-filter-category="packages">{{ __('View Packages') }}</button>
                                      <button type="button" class="btn btn-outline-warning btn-sm" data-filter-category="top_ups">{{ __('View Top-ups') }}</button>
                                  </div>

                                  @if(!empty($departmentSummary))
                                      <div class="btn-group" role="group">
                                          @foreach($departmentSummary as $department)
                                              <button type="button" class="btn btn-outline-dark btn-sm d-flex align-items-center gap-2" data-filter-department="{{ $department['key'] }}">
                                                  <span>{{ $department['label'] }}</span>
                                                  <span class="badge bg-secondary text-light">
                                                      <span data-summary-department-key="{{ $department['key'] }}" data-summary-department-field="total">{{ number_format($department['total'] ?? 0) }}</span>
                                                  </span>
                                              </button>
                                          @endforeach
                                      </div>
                                  @endif

                                  <button type="button" class="btn btn-outline-secondary btn-sm active" data-filter-reset>{{ __('Show All') }}</button>
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



                                        @foreach($paymentGateways as $key => $label)
                                            <option value="{{ $key }}">{{ $label }}</option>
                                        @endforeach
                                    </select>
                                </div>

                                <div class="col-md-4 col-lg-2">
                                    <label for="filter-payable-type" class="form-label">{{ __('Category') }}</label>
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

                        <table class="table table-borderless table-striped" id="payment-requests-table" style="width:100%">

                            <thead>
                            <tr>
                                <th>{{ __('Transaction ID') }}</th>

                                <th>{{ __('User') }}</th>
                                <th>{{ __('Amount') }}</th>
                                <th>{{ __('Currency') }}</th>
                                <th>{{ __('Gateway') }}</th>
                                <th>{{ __('Department') }}</th>
                                <th>{{ __('Category') }}</th>
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

        const MANUAL_PAYMENT_FILTER_STORAGE_KEY = 'mpr_filters_v4';
        const MANUAL_PAYMENT_FILTER_KEYS = ['search', 'status', 'payment_gateway', 'payable_type', 'category', 'department', 'from', 'to'];

        const MANUAL_PAYMENT_STATUS_MAP = {
            pending: 'pending',
            processing: 'pending',
            in_review: 'pending',
            'in-review': 'pending',
            review: 'pending',
            reviewing: 'pending',
            under_review: 'pending',
            'under-review': 'pending',
            awaiting: 'pending',
            waiting: 'pending',
            initiated: 'pending',
            open: 'pending',
            new: 'pending',
            succeed: 'succeed',
            success: 'succeed',
            succeeded: 'succeed',
            approved: 'succeed',
            accepted: 'succeed',
            completed: 'succeed',
            complete: 'succeed',
            paid: 'succeed',
            done: 'succeed',
            settled: 'succeed',
            confirmed: 'succeed',
            failed: 'failed',
            failure: 'failed',
            error: 'failed',
            cancelled: 'failed',
            canceled: 'failed',
            rejected: 'failed',
            declined: 'failed',
            void: 'failed',
            refunded: 'failed'
        };


        const MANUAL_PAYMENT_GATEWAY_MAP = {
            'manual-requests': 'manual_banks',
            'manual-request': 'manual_banks',
            manualrequest: 'manual_banks',
            manualrequests: 'manual_banks',
            manualpayments: 'manual_banks',
            manualpayment: 'manual_banks',
            manual_transfer: 'manual_banks',
            'manual-transfer': 'manual_banks',
            'manual transfers': 'manual_banks',
            manual_transfers: 'manual_banks',
            'manual-transfers': 'manual_banks',
            manualtransfers: 'manual_banks',
            manualtransfer: 'manual_banks',
            manual: 'manual_banks',
            manual_payment: 'manual_banks',
            'manual-payment': 'manual_banks',
            'manual payment': 'manual_banks',
            offline: 'manual_banks',
            internal: 'manual_banks',
            'manual banks': 'manual_banks',
            manual_bank: 'manual_banks',
            'manual-bank': 'manual_banks',
            manualbank: 'manual_banks',
            manualbanks: 'manual_banks',
            manualbanking: 'manual_banks',
            bank: 'manual_banks',
            bank_transfer: 'manual_banks',
            'bank-transfer': 'manual_banks',
            'bank transfer': 'manual_banks',
            banktransfer: 'manual_banks',
            bank_alsharq: 'east_yemen_bank',
            'bank-alsharq': 'east_yemen_bank',
            'bank alsharq': 'east_yemen_bank',
            bankalsharqbank: 'east_yemen_bank',
            'bank_alsharq_bank': 'east_yemen_bank',
            'bank-alsharq-bank': 'east_yemen_bank',
            'bank alsharq bank': 'east_yemen_bank',
            alsharq: 'east_yemen_bank',
            'al-sharq': 'east_yemen_bank',
            'al sharq': 'east_yemen_bank',
            east: 'east_yemen_bank',
            east_yemen_bank: 'east_yemen_bank',
            'east-yemen-bank': 'east_yemen_bank',
            'east yemen bank': 'east_yemen_bank',
            eastyemenbank: 'east_yemen_bank',
            wallet: 'wallet',
            wallet_balance: 'wallet',
            wallet_gateway: 'wallet',
            wallet_top_up: 'wallet',
            'wallet-top-up': 'wallet',
            wallettopup: 'wallet',
            cash: 'cash',
            cod: 'cash',
            cash_on_delivery: 'cash',
            cashcollection: 'cash',
            cash_collect: 'cash'
        };

        const MANUAL_PAYMENT_CATEGORY_MAP = {
            order: 'orders',
            orders: 'orders',
            cart: 'orders',
            cart_order: 'orders',
            'cart-order': 'orders',
            cartorder: 'orders',
            package: 'packages',
            packages: 'packages',
            user_purchased_package: 'packages',
            userpurchasedpackage: 'packages',
            user_purchased_packages: 'packages',
            userpurchasedpackages: 'packages',
            wallet: 'top_ups',
            wallet_top_up: 'top_ups',
            'wallet-top-up': 'top_ups',
            wallettopup: 'top_ups',
            topup: 'top_ups',
            top_ups: 'top_ups',
            'top-ups': 'top_ups',
            topups: 'top_ups'
        };


        const MANUAL_PAYMENT_GATEWAY_STYLES = {
            east_yemen_bank: 'bg-primary',
            manual_banks: 'bg-info text-dark',
            wallet: 'bg-warning text-dark',
            cash: 'bg-success'
        };

        const MANUAL_PAYMENT_GATEWAY_LABEL_OVERRIDES = {
            east_yemen_bank: @json(__('East Yemen Bank')),
            manual_banks: @json(__('Bank Transfer')),
            wallet: @json(__('Wallet')),
            cash: @json(__('Cash')),
        };

        const MANUAL_PAYMENT_DEPARTMENT_STYLES = {
            shein: 'bg-info text-dark',
            computer: 'bg-secondary text-white',
            store: 'bg-primary text-white'
        };

        const MANUAL_PAYMENT_STATUS_STYLES = {
            pending: 'bg-warning text-dark',
            succeed: 'bg-success',
            failed: 'bg-danger'
        };

        const MANUAL_PAYMENT_CATEGORY_STYLES = {
            orders: 'bg-secondary',
            packages: 'bg-info text-dark',
            top_ups: 'bg-warning text-dark'
        };



        const manualPaymentNumberFormatter = (function () {
            if (typeof Intl !== 'undefined' && typeof Intl.NumberFormat === 'function') {
                const formatter = new Intl.NumberFormat('ar-EG');
                return (value) => formatter.format(Number(value) || 0);
            }

            return (value) => String(Number(value) || 0);
        })();


        const manualPaymentCurrencyFormatter = (function () {
            if (typeof Intl !== 'undefined' && typeof Intl.NumberFormat === 'function') {
                const formatter = new Intl.NumberFormat('ar-EG', {
                    minimumFractionDigits: 2,
                    maximumFractionDigits: 2,
                });

                return (value) => formatter.format(Number(value) || 0);
            }

            return (value) => {
                const numericValue = Number(value);
                return Number.isFinite(numericValue) ? numericValue.toFixed(2) : '0.00';
            };
        })();



        function manualPaymentEscapeHtml(value) {
            if (value === undefined || value === null) {
                return '';
            }

            const element = document.createElement('div');
            element.textContent = String(value);
            return element.innerHTML;
        }

        let manualPaymentInitialDrawTriggered = false;
        let manualPaymentOriginalErrMode = null;
        let manualPaymentHasActiveFilters = false;



        function safeManualPaymentStorageGet(key) {
            try {
                if (typeof window !== 'undefined' && window.localStorage) {
                    return window.localStorage.getItem(key);
                }
            } catch (error) {
                console.warn('Failed to access manual payment storage', error);
            }

            return null;
        }

        function safeManualPaymentStorageSet(key, value) {
            try {
                if (typeof window !== 'undefined' && window.localStorage) {
                    window.localStorage.setItem(key, value);
                }
            } catch (error) {
                console.warn('Failed to persist manual payment storage', error);
            }
        }



        function enableManualPaymentDebugErrors() {
            if (!window.jQuery || !$.fn.dataTable || !$.fn.dataTable.ext) {
                return;
            }

            if (manualPaymentOriginalErrMode === null) {
                manualPaymentOriginalErrMode = $.fn.dataTable.ext.errMode;
            }

            $.fn.dataTable.ext.errMode = 'alert';
        }

        function restoreManualPaymentErrorMode() {
            if (!window.jQuery || !$.fn.dataTable || !$.fn.dataTable.ext) {
                return;
            }

            if (manualPaymentOriginalErrMode !== null) {
                $.fn.dataTable.ext.errMode = manualPaymentOriginalErrMode;
            }
        }
        let manualPaymentFilters = loadInitialManualPaymentFilters() || {};


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

            return ['pending', 'succeed', 'failed'].includes(normalized) ? normalized : null;
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


        function resolveManualPaymentGatewayLabel(row, fallback, normalizedGateway) {
            const safeRow = row && typeof row === 'object' ? row : {};
            const rawGatewayValue = typeof safeRow.gateway_key === 'string'
                ? safeRow.gateway_key
                : (typeof safeRow.gateway_code === 'string'
                    ? safeRow.gateway_code
                    : (typeof safeRow.channel === 'string'
                        ? safeRow.channel
                        : (typeof safeRow.payment_gateway === 'string'
                            ? safeRow.payment_gateway
                            : (typeof safeRow.payment_method === 'string' ? safeRow.payment_method : '')
                        )));


            const normalized = normalizedGateway
                ?? normalizeManualPaymentGateway(rawGatewayValue)

                ?? null;

            const valueOrNull = (candidate) => {
                if (candidate === undefined || candidate === null) {
                    return null;
                }

                if (typeof candidate === 'object') {
                    return null;
                }

                const stringValue = typeof candidate === 'string' ? candidate : String(candidate);
                const trimmed = stringValue.trim();

                if (trimmed === '' || trimmed.toLowerCase() === 'null') {
                    return null;
                }

                return trimmed;
            };

            const candidates = [

                safeRow.gateway_label,
                safeRow.payment_gateway_label,
                safeRow.channel_label,
                safeRow.payment_gateway_name,
                safeRow.manual_bank_name,
                safeRow.bank_name,
                fallback,

                safeRow.payment_gateway,
                safeRow.gateway_key,
                safeRow.channel,
                rawGatewayValue,
            ];

            for (const candidate of candidates) {
                const resolved = valueOrNull(candidate);

                if (resolved !== null) {
                    return resolved;
                }

            }

            if (normalized && Object.prototype.hasOwnProperty.call(MANUAL_PAYMENT_GATEWAY_LABEL_OVERRIDES, normalized)) {
                return MANUAL_PAYMENT_GATEWAY_LABEL_OVERRIDES[normalized];
            }

            return '—';
        }


        function normalizeManualPaymentCategory(value) {
            if (typeof value !== 'string') {
                return null;
            }

            const normalized = value.trim().toLowerCase();

            if (normalized === '') {
                return null;
            }

            return MANUAL_PAYMENT_CATEGORY_MAP[normalized] ?? (['orders', 'packages', 'top_ups'].includes(normalized) ? normalized : null);
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

            if (key === 'payment_gateway' || key === 'channel' || key === 'gateway_key') {
                return normalizeManualPaymentGateway(trimmed);
            }

            if (key === 'payable_type' || key === 'category') {
                return normalizeManualPaymentCategory(trimmed);
            }

            return trimmed;
        }



        function loadInitialManualPaymentFilters() {
            const filters = {};
            const storedRaw = safeManualPaymentStorageGet(MANUAL_PAYMENT_FILTER_STORAGE_KEY);


            if (storedRaw) {
                try {
                    const parsed = JSON.parse(storedRaw);
                    if (parsed && typeof parsed === 'object') {
                        Object.entries(parsed).forEach(([key, value]) => {
                            const normalized = normalizeManualPaymentFilterValue(key, value);
                            if (normalized !== null && normalized !== '') {
                                const targetKey = key === 'category' ? 'payable_type' : key;
                                filters[targetKey] = normalized;
                            
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
                    const targetKey = key === 'category' ? 'payable_type' : key;

                    if (normalized === null || normalized === '') {
                        delete filters[targetKey];

                    } else {
                        filters[targetKey] = normalized;

                    }
                });
            } catch (error) {
                console.warn('Failed to parse manual payment filters from URL', error);
            }




            return filters;

        }


        function persistManualPaymentFilters() {
            safeManualPaymentStorageSet(
                MANUAL_PAYMENT_FILTER_STORAGE_KEY,
                JSON.stringify(manualPaymentFilters ?? {})
            );
        }



        function applyManualPaymentFiltersToParams(params) {
            if (!params || typeof params !== 'object') {
                return params;
            }

            const filters = { ...manualPaymentFilters };
            const normalizedSearch = normalizeManualPaymentFilterValue('search', filters.search ?? '');
            const searchValue = normalizedSearch === null ? '' : normalizedSearch;

            if (!params.search || typeof params.search !== 'object') {
                params.search = { value: '', regex: false };
            }

            params.search.value = searchValue;

            MANUAL_PAYMENT_FILTER_KEYS.forEach((key) => {
                if (key === 'search') {
                    return;
                }

                const value = filters[key];

                if (value !== undefined && value !== null && value !== '') {
                    params[key] = value;
                } else {
                    delete params[key];
                }
            });

            if (filters.payable_type !== undefined && filters.payable_type !== null && filters.payable_type !== '') {
                params.payable_type = filters.payable_type;
                params.category = filters.payable_type;
            } else {
                delete params.payable_type;
                delete params.category;
            }

            return params;
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
            const category = normalizeManualPaymentCategory(manualPaymentFilters.payable_type ?? manualPaymentFilters.category ?? '') ?? '';


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


            $('[data-filter-category]').each(function () {
                const value = normalizeManualPaymentCategory($(this).data('filter-category')) ?? '';
                $(this).toggleClass('active', value !== '' && value === category);
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

                if (key === 'payment_gateway' || key === 'channel') {
                    return gateway !== '';
                }

                if (key === 'payable_type' || key === 'category') {
                    return category !== '';
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

            manualPaymentHasActiveFilters = hasActiveFilters;
            updateManualPaymentSummaryNote();

        }




        function manualPaymentRowsFromResponse(json) {
            if (!json || typeof json !== 'object') {
                return [];
            }

            const collectRows = (candidate, depth = 0) => {
                if (!candidate || depth > 5) {
                    return null;
                }

                if (Array.isArray(candidate)) {
                    if (candidate.length === 0) {
                        return [];
                    }

                    const arePlainRows = candidate.every((entry) => entry && typeof entry === 'object' && !Array.isArray(entry));


                    if (arePlainRows) {
                        return candidate;
                    }

                    for (const entry of candidate) {
                        const nested = collectRows(entry, depth + 1);
                        if (Array.isArray(nested) && nested.length > 0) {
                            return nested;
                        }
                    }

                    return null;
                }

                if (candidate && typeof candidate === 'object') {
                    if (Array.isArray(candidate.data)) {
                        return collectRows(candidate.data, depth + 1);
                    }

                    if (Array.isArray(candidate.rows)) {
                        return collectRows(candidate.rows, depth + 1);
                    }

                    for (const value of Object.values(candidate)) {
                        const nested = collectRows(value, depth + 1);
                        if (Array.isArray(nested) && nested.length > 0) {
                            return nested;
                        }
                    }
                }

                return null;
            };

            const resolved = collectRows(json);
            return Array.isArray(resolved) ? resolved : [];
        }

        function updateManualPaymentSummaryNote() {
            const noteElement = document.querySelector('[data-summary-note]');

            if (!noteElement) {
                return;
            }

            const message = manualPaymentHasActiveFilters
                ? '{{ __('Totals shown reflect the applied filters.') }}'
                : '{{ __('Totals shown reflect the entire system (unfiltered).') }}';

            noteElement.textContent = message;


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

            const total = Number(
                json?.recordsTotal
                ?? json?.total
                ?? json?.meta?.total
                ?? info.recordsTotal
                ?? 0
            );
            const filtered = Number(
                json?.recordsFiltered
                ?? json?.total
                ?? json?.meta?.filtered_total
                ?? info.recordsDisplay
                ?? info.recordsTotal
                ?? 0
            );


            const currentPage = Number(info.page ?? 0) + 1;
            const lastPage = Number(info.pages ?? 0) || 1;

            const parts = [
                `${totalLabel}: ${manualPaymentNumberFormatter(total)}`,
                `${filteredLabel}: ${manualPaymentNumberFormatter(filtered)}`,
                `${pageLabel} ${manualPaymentNumberFormatter(currentPage)} ${ofLabel} ${manualPaymentNumberFormatter(lastPage)}`
            ];

            $meta.text(parts.join(' • '));
        }






        function updateManualPaymentSummary(data = {}) {
            const summary = data && typeof data.summary === 'object' ? data.summary : null;
            const gatewaySummary = data && typeof data.gateway_summary === 'object' ? data.gateway_summary : null;
            const categorySummary = data && typeof data.category_summary === 'object' ? data.category_summary : null;
            const departmentSummary = Array.isArray(data?.department_summary) ? data.department_summary : null;

            if (summary && Object.keys(summary).length > 0) {
                const summaryFields = {
                    total: Number(summary.total ?? summary.total_requests ?? 0),
                    pending: Number(summary.pending ?? 0),
                    succeed: Number(summary.succeed ?? 0),
                    failed: Number(summary.failed ?? 0),
                    amount: Number(summary.amount ?? summary.total_amount ?? 0),
                };

                document.querySelectorAll('[data-summary-field]').forEach((element) => {
                    if (!(element instanceof HTMLElement)) {
                        return;
                    }

                    const field = element.getAttribute('data-summary-field');


                    if (!field || !(field in summaryFields)) {
                        return;
                    }


                    const value = summaryFields[field] ?? 0;


                    if (field === 'amount') {
                        element.textContent = manualPaymentCurrencyFormatter(value);
                    } else {
                        element.textContent = manualPaymentNumberFormatter(value);
                    }
                });
            }

            if (gatewaySummary) {
                document.querySelectorAll('[data-summary-gateway]').forEach((element) => {
                    if (!(element instanceof HTMLElement)) {
                        return;
                    }



                    const key = element.getAttribute('data-summary-gateway');


                    if (!key) {
                        return;
                    }


                    const value = Number(gatewaySummary[key] ?? 0);
                    element.textContent = manualPaymentNumberFormatter(value);
                });
            }


            if (categorySummary) {
                document.querySelectorAll('[data-summary-category]').forEach((element) => {
                    if (!(element instanceof HTMLElement)) {
                        return;
                    }




                    const key = element.getAttribute('data-summary-category');


                    if (!key) {
                        return;
                    }

                    const value = Number(categorySummary[key] ?? 0);
                    element.textContent = manualPaymentNumberFormatter(value);
                });
            }

            if (departmentSummary) {
                const departmentMap = departmentSummary.reduce((carry, entry) => {
                    if (!entry || typeof entry !== 'object' || typeof entry.key !== 'string') {
                        return carry;
                    }

                    const key = entry.key;
                    carry[key] = {
                        total: Number(entry.total ?? 0),
                        pending: Number(entry.pending ?? 0),
                        succeed: Number(entry.succeed ?? 0),
                        failed: Number(entry.failed ?? 0),
                    };


                    return carry;
                }, {});

                document.querySelectorAll('[data-summary-department-key]').forEach((element) => {
                    if (!(element instanceof HTMLElement)) {
                        return;
                    }

                    const key = element.getAttribute('data-summary-department-key');
                    const field = element.getAttribute('data-summary-department-field');

                    if (!key || !field) {
                        return;
                    }

                    const entry = departmentMap[key] ?? null;
                    const value = entry && Object.prototype.hasOwnProperty.call(entry, field)
                        ? Number(entry[field] ?? 0)
                        : 0;

                    element.textContent = manualPaymentNumberFormatter(value);
                });
            }
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



                if (manualPaymentFilters.payable_type !== undefined && manualPaymentFilters.payable_type !== '') {
                    url.searchParams.set('payable_type', manualPaymentFilters.payable_type);
                    url.searchParams.set('category', manualPaymentFilters.payable_type);
                } else {
                    url.searchParams.delete('payable_type');
                    url.searchParams.delete('category');
                }


                if (info) {
                    url.searchParams.set('page', (info.page ?? 0) + 1);
                    const infoLength = Number(info.length ?? 20) || 20;
                    url.searchParams.set('length', infoLength);
                
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
                    const targetKey = field.name === 'category' ? 'payable_type' : field.name;
                    filters[targetKey] = normalized;
                
                }
            });




            manualPaymentFilters = { ...filters };
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
            const $table = $('#payment-requests-table');


            if (!$table.length) {
                return;
            }


            const $form = $('#manual-payment-filters');

            if ($form.length) {
                hydrateManualPaymentFilters($form);
            }

            updateQuickFilterButtons();
            enableManualPaymentDebugErrors();

            const dataTable = $table.DataTable({
                processing: true,
                serverSide: true,
                searching: false,
                lengthMenu: [10, 20, 50, 100],
                pageLength: 20,

                stateSave: true,
                stateDuration: 0,
                stateLoadParams: function (settings, data) {
                    if (!data || typeof data !== 'object') {
                        return;
                    }

                    if (typeof data.length !== 'number' || data.length <= 0) {
                        data.length = 20;
                    }

                    if (typeof data.start !== 'number' || data.start < 0) {
                        data.start = 0;
                    }
                },

                ajax: {
                    url: '{{ route('payment-requests.table') }}',
                    data: function (params) {
                        applyManualPaymentFiltersToParams(params);

                    },
                    dataSrc: function (json) {
                        if (!json || typeof json !== 'object') {
                            setManualPaymentFeedback('{{ __('Unable to load manual payment requests. Please try again later.') }}', 'danger');
                            return [];
                        }

                        if (json.error) {
                            const message = typeof json.message === 'string' && json.message.trim() !== ''
                                ? json.message
                                : '{{ __('Unable to load manual payment requests. Please try again later.') }}';
                            setManualPaymentFeedback(message, 'danger');
                            return [];
                        }

                        const rows = manualPaymentRowsFromResponse(json);

                        if (!Array.isArray(rows) || rows.length === 0) {
                            return [];
                        }

                        return rows;
                    
                    
                    },
                    error: function () {
                        setManualPaymentFeedback('{{ __('Unable to load manual payment requests. Please try again later.') }}', 'danger');
                        restoreManualPaymentErrorMode();



                    }
                },
                order: [[8, 'desc']],
                columns: [
                    {
                        data: 'reference',
                        name: 'reference',
                        defaultContent: '—',
                        render: function (data, type, row) {
                            if (type !== 'display') {
                                return data ?? row?.transaction_id ?? '';
                            }

                            return (row?.reference ?? row?.transaction_id ?? data ?? '—').toString();
                        }
                    },
                    { data: 'user_name', name: 'user_name', defaultContent: '—' },
                    {
                        data: 'amount',
                        name: 'amount',
                        defaultContent: '0.00',
                        className: 'text-end text-nowrap',
                        render: function (data, type, row) {
                            if (type === 'display') {
                                const value = typeof row?.amount_fmt === 'string'
                                    ? row.amount_fmt
                                    : Number(data ?? 0).toFixed(2);
                                return value;
                            }

                            return data ?? row?.amount ?? 0;
                        }
                    },
                    { data: 'currency', name: 'currency', defaultContent: '' },
                    {
                        data: 'channel',
                        name: 'channel',
                        defaultContent: '—',
                        render: function (data, type, row) {

                            const normalizedGateway = normalizeManualPaymentGateway(
                                row?.gateway_key ?? row?.gateway_code ?? row?.channel ?? row?.payment_gateway ?? row?.payment_method ?? ''
                            ) ?? '';

                            if (type === 'sort' || type === 'type') {
                                return normalizedGateway;
                            }


                            if (type !== 'display') {
                                return row?.gateway_label ?? row?.channel_label ?? data ?? '';
                            }

                            const classes = MANUAL_PAYMENT_GATEWAY_STYLES[normalizedGateway] ?? 'bg-secondary';
                            const label = resolveManualPaymentGatewayLabel(row ?? {}, data, normalizedGateway);


                            return '<span class="badge ' + classes + '">' + manualPaymentEscapeHtml(label) + '</span>';
                        }
                    },


                    {
                        data: 'department',
                        name: 'department',
                        defaultContent: '—',
                        render: function (data, type, row) {
                            const label = row?.department_label ?? data ?? '—';

                            
                            if (type !== 'display') {
                                return row?.department_label ?? data ?? '';
                            }

                            const key = (row?.department ?? '').toString().toLowerCase();
                            const classes = MANUAL_PAYMENT_DEPARTMENT_STYLES[key] ?? 'bg-secondary';

                            return '<span class="badge ' + classes + '">' + label + '</span>';
                        }
                    },


                    {
                        data: 'category',
                        name: 'category',
                        defaultContent: '—',
                        render: function (data, type, row) {
                            const label = row?.category_label ?? data ?? '—';


                            if (type !== 'display') {
                                return row?.category_label ?? data ?? '';
                            }

                            const key = normalizeManualPaymentCategory(row?.category ?? row?.payable_type ?? '') ?? '';
                            const classes = MANUAL_PAYMENT_CATEGORY_STYLES[key] ?? 'bg-secondary';

                            return '<span class="badge ' + classes + '">' + label + '</span>';
                        }
                    },
                    
                    {
                        data: 'status',
                        name: 'status',
                        defaultContent: '—',
                        render: function (data, type, row) {
                            const label = row?.status_label ?? data ?? '—';


                            if (type !== 'display') {
                                return label ?? '';
                            }

                            const key = normalizeManualPaymentStatus(row?.status ?? '') ?? '';
                            const classes = MANUAL_PAYMENT_STATUS_STYLES[key] ?? 'bg-secondary';

                            return '<span class="badge ' + classes + '">' + label + '</span>';
                        }
                    },
                    {
                        data: 'created_at',
                        name: 'created_at',
                        defaultContent: '—',
                        className: 'text-nowrap',
                        render: function (data, type, row) {
                            if (type === 'display') {
                                return row?.created_at_human ?? data ?? '—';
                            }

                            return data ?? row?.created_at ?? '';
                        }
                    },
                    
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

                },
                initComplete: function () {
                    restoreManualPaymentErrorMode();

                    if (!manualPaymentInitialDrawTriggered) {
                        manualPaymentInitialDrawTriggered = true;
                        this.api().draw(false);
                    }

                }
            });

            dataTable.on('destroy.dt', function () {
                restoreManualPaymentErrorMode();
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
                applyManualPaymentFiltersToParams(params);

                const fallbackLength = Number(dataTable.page.len()) || 20;
                const normalizedStart = Number.isFinite(Number(params?.start)) && Number(params.start) >= 0
                    ? Number(params.start)
                    : 0;
                const normalizedLength = Number.isFinite(Number(params?.length)) && Number(params.length) > 0
                    ? Number(params.length)
                    : fallbackLength;

                params.start = normalizedStart;
                params.length = normalizedLength;
                params.offset = normalizedStart;
                params.limit = normalizedLength;
                manualPaymentLastRequestStart = normalizedStart;
            });


            dataTable.on('xhr.dt', function (event, settings, json) {
                const rows = manualPaymentRowsFromResponse(json || {});
                const filtered = Number(
                    json?.recordsFiltered
                    ?? json?.total
                    ?? json?.meta?.filtered_total
                    ?? rows.length
                    ?? 0
                );



                updateManualPaymentSummary(json || {});


                if (!manualPaymentForceFirstPage && rows.length === 0 && filtered > 0 && manualPaymentLastRequestStart > 0) {
                    manualPaymentForceFirstPage = true;
                    dataTable.page('first').draw(false);
                    return;
                }


                manualPaymentForceFirstPage = false;
   

                const info = dataTable.page.info();
                updateManualPaymentMeta(info, json || {});
                syncManualPaymentQueryString(info);


                if (filtered === 0) {
                    setManualPaymentFeedback('{{ __('No manual payments found for the current filters.') }}', 'info');
                } else {
                    setManualPaymentFeedback('');



                }
            });
            dataTable.on('error.dt', function () {
                setManualPaymentFeedback('{{ __('Unable to load manual payment requests. Please try again later.') }}', 'danger');
                restoreManualPaymentErrorMode();


            });






            $form.on('submit', function (event) {
                event.preventDefault();
                applyManualPaymentFiltersFromForm($form, dataTable);
            });

            $('#manual-payment-reset').on('click', function () {
                manualPaymentFilters = {};
                persistManualPaymentFilters();


                if ($form.length) {
                    $form[0].reset();
                }

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


            $('[data-filter-category]').on('click', function () {
                const rawValue = $(this).data('filter-category');
                const normalized = normalizeManualPaymentCategory(rawValue);
                const current = normalizeManualPaymentCategory($('#filter-payable-type').val());

                $('#filter-payable-type').val(normalized && normalized === current ? '' : (normalized ?? ''));


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


            $(document).on('shown.bs.tab', 'a[data-bs-toggle="tab"]', function (event) {
                const targetSelector = $(event.target).attr('data-bs-target') || $(event.target).attr('href');
                if (!targetSelector) {
                    return;
                }

                const targetElement = document.querySelector(targetSelector);
                if (targetElement && targetElement.contains($table[0])) {
                    dataTable.columns.adjust().draw(false);
                }
            });


            window.addEventListener('manual-payment-refresh', function () {
                dataTable.draw(false);


            });


        });





    </script>
@endsection