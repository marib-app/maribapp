@extends('layouts.main')

@section('title')
    {{ __('Metal Rates Management') }}
@endsection




@section('page-title')
    <div class="page-title">
        <div class="row">
            <div class="col-12 col-md-6 order-md-1 order-last">
                <h4>@yield('title')</h4>
            </div>
        </div>
    </div>
@endsection

@section('content')

    <script src="https://cdnjs.cloudflare.com/ajax/libs/moment.js/2.29.4/moment.min.js"></script>


    <section class="section">
        <div class="row">
            <div class="col-12">
                @if ($errors->any())
                    <div class="alert alert-danger">
                        <ul class="mb-0">
                            @foreach ($errors->all() as $error)
                                <li>{{ $error }}</li>
                            @endforeach
                        </ul>
                    </div>
                @endif

                @if (session('success'))
                    <div class="alert alert-success alert-dismissible fade show" role="alert">
                        {{ session('success') }}
                        <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
                    </div>
                @endif
            </div>
        </div>

        <div class="row">
            <div class="col-12">

                <div class="card">
                    <div class="card-header d-flex flex-wrap justify-content-between align-items-center gap-2">

                        <div class="d-flex align-items-center gap-2">
                            <h5 class="card-title mb-0">{{ __('Metal Rates') }}</h5>
                            <span class="badge bg-light text-dark" id="metalRatesCount">{{ $metalRateCount }}</span>
                        
                        </div>
                    
                        @can('metal-rate-create')
                            <a href="{{ route('metal-rates.create') }}" class="btn btn-primary btn-sm">
                                {{ __('إضافة معدن') }}
                            </a>
                        @endcan


                    </div>
                    <div class="card-body">
                        <div class="table-responsive">
                            <table class="table table-borderless table-striped"
                                   id="metal_rates_table"
                                   data-toggle="table"
                                   data-url="{{ route('metal-rates.show') }}"
                                   data-click-to-select="true"
                                   data-side-pagination="server"
                                   data-pagination="true"
                                   data-page-list="[5, 10, 20, 50, 100, 200]"
                                   data-search="true"
                                   data-show-columns="true"
                                   data-show-refresh="true"
                                   data-fixed-columns="true"
                                   data-fixed-number="1"
                                   data-trim-on-search="false"
                                   data-mobile-responsive="true"
                                   data-sort-name="id"
                                   data-sort-order="desc"
                                   data-pagination-successively-size="3"
                                   data-query-params="metalRatesQueryParams"
                                   data-response-handler="metalRatesResponseHandler">
                                <thead>
                                <tr>
                                    <th scope="col" data-field="id" data-sortable="true">{{ __('ID') }}</th>
                                    <th scope="col" data-field="display_name" data-sortable="true">{{ __('Name') }}</th>
                                    <th scope="col" data-field="sell_price" data-sortable="true" data-formatter="metalPriceFormatter">{{ __('Sell Price') }}</th>
                                    <th scope="col" data-field="buy_price" data-sortable="true" data-formatter="metalPriceFormatter">{{ __('Buy Price') }}</th>
                                    <th scope="col" data-field="icon_url" data-formatter="metalIconFormatter">{{ __('Icon') }}</th>
                                    <th scope="col" data-field="last_updated_at" data-sortable="true" data-formatter="metalDateFormatter">{{ __('Last Updated') }}</th>
                                    <th scope="col" data-field="history" data-formatter="metalHistoryQualityFormatter">{{ __('Source Quality') }}</th>
                                    <th scope="col" data-field="history" data-formatter="metalHistoryHourlyFormatter" data-visible="false">{{ __('Last Hourly Snapshot') }}</th>
                                    <th scope="col" data-field="history" data-formatter="metalHistoryDailyFormatter" data-visible="false">{{ __('Last Daily Aggregate') }}</th>
                                    @canany(['metal-rate-edit', 'metal-rate-delete'])
                                        <th scope="col" data-field="operate" data-events="metalRateEvents" data-escape="false" data-formatter="metalOperateFormatter">{{ __('Action') }}</th>
                                    @endcanany
                                </tr>
                                </thead>
                            </table>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </section>

@endsection

@section('script')
    <script>
        const metalRatesI18n = {
            unknown: @json(__('Unknown')),
            deleteConfirm: @json(__('هل أنت متأكد من حذف هذا المعدن؟')),
            deleteError: @json(__('حدث خطأ أثناء حذف المعدن.')),
            deleteSuccessFallback: @json(__('تم حذف سعر المعدن بنجاح.')),
            fresh: @json(__('Fresh')),
            warning: @json(__('Warning')),
            stale: @json(__('Stale')),
        };

        function metalRatesQueryParams(params) {
            return params;
        }

        function metalRatesResponseHandler(res) {
            if (res && typeof res.total === 'number') {
                $('#metalRatesCount').text(res.total);
            }

            return res;
        }

        function metalIconFormatter(value, row) {
            if (!value) {
                return '<span class="text-muted">&mdash;</span>';
            }

            const alt = row.icon_alt ? $('<div>').text(row.icon_alt).html() : '';
            return '<img src="' + value + '" alt="' + alt + '" class="img-thumbnail" style="height:40px;max-width:40px;">';
        }

        function metalDateFormatter(value) {
            if (!value) {
                return '<span class="text-muted">&mdash;</span>';
            }

            return moment(value).isValid()
                ? moment(value).format('YYYY-MM-DD HH:mm')
                : value;
        }

        function metalPriceFormatter(value) {
            if (value === null || typeof value === 'undefined') {
                return '<span class="text-muted">&mdash;</span>';
            }

            const number = Number(value);

            if (Number.isNaN(number)) {
                return '<span class="text-muted">&mdash;</span>';
            }

            return number.toLocaleString(undefined, {
                minimumFractionDigits: 3,
                maximumFractionDigits: 3,
            });
        }

        function metalHistoryQualityFormatter(value) {
            const quality = (value?.source_quality || 'unknown').toLowerCase();
            const source = value?.source ? $('<div>').text(value.source).html() : '';

            const map = {
                fresh: { label: metalRatesI18n.fresh, class: 'badge bg-success-subtle text-success fw-semibold' },
                warning: { label: metalRatesI18n.warning, class: 'badge bg-warning-subtle text-warning-emphasis fw-semibold' },
                stale: { label: metalRatesI18n.stale, class: 'badge bg-danger-subtle text-danger fw-semibold' },
                unknown: { label: metalRatesI18n.unknown, class: 'badge bg-secondary-subtle text-secondary fw-semibold' },
            };

            const meta = map[quality] || map.unknown;

            const sourceMarkup = source ? `<span class="d-block text-muted small mt-1">${source}</span>` : '';

            return `<span class="${meta.class}">${meta.label}</span>${sourceMarkup}`;
        }

        function metalHistoryHourlyFormatter(value) {
            const timestamp = value?.last_hourly_at || value?.last_captured_at;
            if (!timestamp) {
                return '<span class="text-muted">&mdash;</span>';
            }

            return moment(timestamp).isValid()
                ? moment(timestamp).format('YYYY-MM-DD HH:mm')
                : timestamp;
        }

        function metalHistoryDailyFormatter(value) {
            const timestamp = value?.last_daily_at;
            if (!timestamp) {
                return '<span class="text-muted">&mdash;</span>';
            }

            return moment(timestamp).isValid()
                ? moment(timestamp).format('YYYY-MM-DD')
                : timestamp;
        }

        @canany(['metal-rate-edit', 'metal-rate-delete'])
            @can('metal-rate-edit')
                const metalRatesEditUrlTemplate = @json(route('metal-rates.edit', ['metalRate' => '__ID__']));
            @endcan

            @can('metal-rate-delete')
                const metalRatesDeleteUrlTemplate = @json(route('metal-rates.destroy', ['metalRate' => '__ID__']));
            @endcan

            function metalOperateFormatter(value, row) {
                const buttons = [];

                @can('metal-rate-edit')
                    if (row.id) {
                        const editUrl = metalRatesEditUrlTemplate.replace('__ID__', row.id);
                        buttons.push(
                            '<a class="btn btn-sm btn-outline-primary me-1" href="' + editUrl + '" title="{{ __('Edit') }}">'
                            + '<i class="bi bi-pencil-square"></i>'
                            + '</a>'
                        );
                    }
                @endcan

                @can('metal-rate-delete')
                    buttons.push(
                        '<button class="delete-metal-rate btn btn-sm btn-danger" title="{{ __('Delete') }}">'
                        + '<i class="bi bi-trash"></i>'
                        + '</button>'
                    );
                @endcan

                return buttons.join('') || '<span class="text-muted">&mdash;</span>';
            }

            @can('metal-rate-delete')
                window.metalRateEvents = {
                    'click .delete-metal-rate': function (e, value, row) {
                        if (!row?.id) {
                            return;
                        }

                        if (!confirm(metalRatesI18n.deleteConfirm)) {
                            return;
                        }

                        const deleteUrl = metalRatesDeleteUrlTemplate.replace('__ID__', row.id);

                        $.ajax({
                            url: deleteUrl,
                            type: 'DELETE',
                            headers: {
                                'X-CSRF-TOKEN': $('meta[name="csrf-token"]').attr('content')
                            },
                            success: function (response) {
                                if (response?.success) {
                                    $('#metal_rates_table').bootstrapTable('refresh');
                                    if (typeof showSuccessToast === 'function') {
                                        showSuccessToast(response.message || metalRatesI18n.deleteSuccessFallback);
                                    }
                                } else if (typeof showErrorToast === 'function') {
                                    showErrorToast(response?.message || metalRatesI18n.deleteError);
                                }
                            },
                            error: function () {
                                if (typeof showErrorToast === 'function') {
                                    showErrorToast(metalRatesI18n.deleteError);
                                }
                            }
                        });
                    }
                };
            @else
                window.metalRateEvents = {};
            @endcan
        @else
            function metalOperateFormatter() {
                return '<span class="text-muted">&mdash;</span>';
            }

            window.metalRateEvents = {};
        @endcanany
    </script>
@endsection
