@extends('layouts.main')

@section('title')
    {{ __('Payment Transactions') }}
@endsection

@section('page-title')
    <div class="page-title">
        <div class="row">
            <div class="col-12 col-md-6 order-md-1 order-last">
                <h4>@yield('title')</h4>
            </div>
            <div class="col-12 col-md-6 order-md-2 order-first"></div>
        </div>
    </div>
@endsection

@section('content')
    <section class="section">
        <div class="row">
            <div class="col-md-12">
                <div class="card">
                    <div class="card-body">

                        {{-- <div class="row " id="toolbar"> --}}

                        <div class="row">
                            <div class="col-12">
                                <table class="table table-borderless table-striped" aria-describedby="mydesc"
                                       id="table_list" data-toggle="table" data-url="{{ route('package.payment-transactions.show') }}"
                                       data-click-to-select="true" data-side-pagination="server" data-pagination="true"
                                       data-page-list="[5, 10, 20, 50, 100, 200]" data-search="true"
                                       data-search-align="right" data-toolbar="#toolbar" data-show-columns="true"
                                       data-show-refresh="true" data-fixed-columns="true" data-fixed-number="1"
                                       data-fixed-right-number="1" data-trim-on-search="false" data-responsive="true"
                                       data-sort-name="id" data-sort-order="desc" data-pagination-successively-size="3"
                                       data-escape="true"
                                       data-query-params="queryParams" data-table="packages"
                                       data-show-export="true" data-export-options='{"fileName": "user-package-list","ignoreColumn": ["operate"]}' data-export-types="['pdf','json', 'xml', 'csv', 'txt', 'sql', 'doc', 'excel']"
                                       data-mobile-responsive="true">
                                    <thead class="thead-dark">
                                    <tr>
                                        <th scope="col" data-field="id" data-align="center" data-sortable="true">{{ __('ID') }}</th>
                                        <th scope="col" data-field="user.name" data-align="center" data-sortable="false">{{ __('User Name') }}</th>
                                        <th scope="col" data-field="amount" data-align="center" data-sortable="false">{{ __('Amount') }}</th>
                                        <th scope="col" data-field="gateway_label" data-align="center">{{ __('Payment Gateway') }}</th>
                                        <th scope="col" data-field="payment_status" data-align="center" data-sortable="true">{{ __('Payment Status') }}</th>
                                        <th scope="col" data-field="created_at" data-align="center" data-sortable="true">{{ __('Created At') }}</th>
                                    </tr>
                                    </thead>
                                </table>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
@endsection



@section('js')
    <script>
        (function () {
            const normalizedChannelKey = 'normalized_channel';
            const gatewayFieldAliases = ['gateway_label', 'payment_gateway', 'gateway_key'];
            const originalQueryParams = window.queryParams ?? (p => p);

            function parseFilterPayload(raw) {
                if (raw === null || typeof raw === 'undefined' || raw === '') {
                    return { value: null, serialized: false };
                }

                if (typeof raw === 'string') {
                    try {
                        const parsed = JSON.parse(raw);
                        if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
                            return { value: { ...parsed }, serialized: true };
                        }
                    } catch (error) {
                        return { value: null, serialized: true };
                    }

                    return { value: null, serialized: true };
                }

                if (typeof raw === 'object' && !Array.isArray(raw)) {
                    return { value: { ...raw }, serialized: false };
                }

                return { value: null, serialized: false };
            }

            function remapGatewayKey(container) {
                if (!container?.value) {
                    return false;
                }

                const filters = container.value;
                let mutated = false;

                gatewayFieldAliases.forEach(alias => {
                    if (Object.prototype.hasOwnProperty.call(filters, alias)) {
                        const value = filters[alias];
                        if (typeof value !== 'undefined') {
                            filters[normalizedChannelKey] = value;
                        }
                        delete filters[alias];
                        mutated = true;
                    }
                });

                return mutated;
            }

            function normalizeGroupBy(value) {
                if (typeof value === 'string') {
                    return gatewayFieldAliases.includes(value) ? normalizedChannelKey : value;
                }

                if (Array.isArray(value)) {
                    return value.map(item => gatewayFieldAliases.includes(item) ? normalizedChannelKey : item);
                }

                return value;
            }

            window.queryParams = function (params) {
                const initial = originalQueryParams(params) ?? {};
                const next = { ...initial };

                if (typeof next.sort === 'string' && gatewayFieldAliases.includes(next.sort)) {
                    next.sort = normalizedChannelKey;
                }

                next.group_by = normalizeGroupBy(next.group_by);

                const filterPayload = parseFilterPayload(next.filter);
                if (remapGatewayKey(filterPayload)) {
                    next.filter = filterPayload.serialized ? JSON.stringify(filterPayload.value) : filterPayload.value;
                }

                const filtersPayload = parseFilterPayload(next.filters);
                if (remapGatewayKey(filtersPayload)) {
                    next.filters = filtersPayload.serialized ? JSON.stringify(filtersPayload.value) : filtersPayload.value;
                }

                return next;
            };
        })();
    </script>
@endsection