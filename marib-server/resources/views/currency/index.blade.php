@extends('layouts.main')

@section('title')
    {{ __('Currency Rates Management') }}
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
    <script src="https://cdnjs.cloudflare.com/ajax/libs/moment.js/2.29.4/moment.min.js"></script>
    <section class="section">
        <div class="row">


            @can('currency-rate-import')
                <div class="col-12">
                    <div class="card mb-3">
                        <div class="card-body">
                            <h5 class="card-title mb-3">{{ __('Bulk import currency rates') }}</h5>
                            <p class="text-muted small mb-3">
                                {{ __('Upload a CSV or Excel file with the columns: currency_name, governorate_code, sell_price, buy_price. Optional columns: source, quoted_at, is_default.') }}
                            </p>
                            <form id="currency-import-form" action="{{ route('currency.import') }}" method="POST" enctype="multipart/form-data">
                                @csrf
                                <div class="row g-3 align-items-end">
                                    <div class="col-md-6 col-lg-4">
                                        <label for="currency-import-file" class="form-label">{{ __('Select file') }}</label>
                                        <input type="file" class="form-control" id="currency-import-file" name="file" accept=".csv,.xlsx,.xls" required>
                                    </div>
                                    <div class="col-md-auto">
                                        <button type="submit" class="btn btn-outline-primary">{{ __('Import rates') }}</button>
                                    </div>
                                    <div class="col-md text-muted small">
                                        {{ __('Each currency must include at least one governorate row with sell and buy prices.') }}
                                    </div>
                                </div>
                            </form>
                            <div id="currency-import-success" class="alert alert-success mt-3 d-none" role="alert"></div>
                            <div id="currency-import-error" class="alert alert-danger mt-3 d-none" role="alert"></div>
                            <div id="currency-import-report" class="mt-3 border rounded p-3 d-none"></div>
                        </div>
                    </div>
                </div>
            @endcan


            <div class="col-12">

                <div class="card">
                    <div class="card-header d-flex flex-wrap justify-content-between align-items-center gap-2">
                        <h5 class="card-title mb-0">{{ __('Currency Rates') }}</h5>
                        @can('currency-rate-create')
                            <a href="{{ route('currency.create') }}" class="btn btn-primary btn-sm">
                                {{ __('إضافة عملة') }}
                            </a>
                        @endcan
                    </div>

                    <div class="card-body">
                        <div class="row">
                            <div class="col-12">
                                <table class="table table-borderless table-striped" aria-describedby="mydesc"
                                       id="table_list" data-toggle="table" data-url="{{ route('currency.show') }}"
                                       data-click-to-select="true" data-side-pagination="server" data-pagination="true"
                                       data-page-list="[5, 10, 20, 50, 100, 200]" data-search="true"
                                       data-show-columns="true" data-show-refresh="true"
                                       data-fixed-columns="true" data-fixed-number="1" {{-- data-fixed-right-number="1" --}}
                                       data-trim-on-search="false" data-mobile-responsive="true"
                                       data-sort-name="id" data-sort-order="desc"
                                       data-pagination-successively-size="3" data-query-params="queryParams">
                                    <thead>
                                    <tr>
                                        <th scope="col" data-field="id" data-sortable="true">{{ __('ID') }}</th>
                                        <th scope="col" data-field="currency_name" data-sortable="true">{{ __('Currency Name') }}</th>
                                        <th scope="col" data-field="sell_price" data-sortable="true">{{ __('Sell Price') }}</th>
                                        <th scope="col" data-field="buy_price" data-sortable="true">{{ __('Buy Price') }}</th>
                                        <th scope="col" data-field="icon_url" data-formatter="iconFormatter">{{ __('Icon') }}</th>
                                        <th scope="col" data-field="last_updated_at" data-sortable="true" data-formatter="dateFormatter">{{ __('Last Updated') }}</th>
                                        <th scope="col" data-field="history" data-formatter="historyHourlyFormatter" data-visible="false">{{ __('Last Hourly Snapshot') }}</th>
                                        <th scope="col" data-field="history" data-formatter="historyDailyFormatter" data-visible="false">{{ __('Last Daily Aggregate') }}</th>
                                        <th scope="col" data-field="history" data-formatter="historyQualityFormatter">{{ __('Source Quality') }}</th>

                                        @can('currency-rate-edit')
                                            <th scope="col" data-field="operate" data-events="currencyEvents"
                                                data-escape="false" data-formatter="operateFormatter">{{ __('Action') }}</th>
                                        @endcan
                                    </tr>
                                    </thead>
                                </table>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>


    </section>
@endsection

@section('script')
    <script>
        // function queryParams(params) {
        //     return {
        //         limit: params.limit,
        //         offset: params.offset,
        //         search: params.search,
        //         sort: params.sort,
        //         order: params.order
        //     };
        // }





        const currencyImportI18n = {
            updatedHeading: @json(__('Updated currencies')),
            warningsHeading: @json(__('Warnings')),
            errorsHeading: @json(__('Errors')),
            rowLabel: @json(__('Row')),
            currencyLabel: @json(__('Currency')),
            summaryTemplate: @json(__('Processed :rows rows. Updated :updated currencies.', ['rows' => ':rows', 'updated' => ':updated'])),
            updatedItemTemplate: @json(__('Updated :count quotes')),
        };


        @can('currency-rate-edit')
            const currencyEditUrlTemplate = @json(route('currency.edit', ['id' => '__ID__']));
        @endcan


        function iconFormatter(value, row, index) {
            if (!value) {
                return '<span class="text-muted">&mdash;</span>';
            }

            const alt = row.icon_alt ? $('<div>').text(row.icon_alt).html() : '';
            return '<img src="' + value + '" alt="' + alt + '" class="img-thumbnail" style="height:40px;max-width:40px;">';
        }



        function dateFormatter(value, row, index) {
            if (value) {
                return moment(value).format('YYYY-MM-DD HH:mm');
            } else {
                return '-';
            }
        }



        function historyHourlyFormatter(value, row) {
            const timestamp = row?.history?.last_hourly_at;
            if (!timestamp) {
                return '<span class="text-muted">—</span>';
            }

            return moment(timestamp).isValid()
                ? moment(timestamp).format('YYYY-MM-DD HH:mm')
                : timestamp;
        }

        function historyDailyFormatter(value, row) {
            const timestamp = row?.history?.last_daily_at;
            if (!timestamp) {
                return '<span class="text-muted">—</span>';
            }

            return moment(timestamp).isValid()
                ? moment(timestamp).format('YYYY-MM-DD')
                : timestamp;
        }

        function historyQualityFormatter(value, row) {
            const quality = (row?.history?.source_quality || 'unknown').toLowerCase();

            const map = {
                fresh: { label: '{{ __('Fresh') }}', class: 'badge bg-success-subtle text-success fw-semibold' },
                warning: { label: '{{ __('Warning') }}', class: 'badge bg-warning-subtle text-warning-emphasis fw-semibold' },
                stale: { label: '{{ __('Stale') }}', class: 'badge bg-danger-subtle text-danger fw-semibold' },
                unknown: { label: '{{ __('Unknown') }}', class: 'badge bg-secondary-subtle text-secondary fw-semibold' },
            };

            const meta = map[quality] || map.unknown;
            const source = row?.history?.source ? `<span class="d-block text-muted small mt-1">${row.history.source}</span>` : '';

            return `<span class="${meta.class}">${meta.label}</span>${source}`;
        }




        function renderCurrencyImportReport(container, report) {
            const target = container instanceof jQuery ? container : $(container);
            target.empty();

            if (!report) {
                target.addClass('d-none');
                return;
            }

            const errors = Array.isArray(report.errors) ? report.errors : [];
            const warnings = Array.isArray(report.warnings) ? report.warnings : [];
            const updated = Array.isArray(report.updated_currencies) ? report.updated_currencies : [];
            const rowsProcessed = typeof report.rows_processed === 'number' ? report.rows_processed : 0;

            if (!errors.length && !warnings.length && !updated.length) {
                target.addClass('d-none');
                return;
            }

            const wrapper = $('<div class="currency-import-report__content"></div>');
            const summaryText = currencyImportI18n.summaryTemplate
                .replace(':rows', rowsProcessed)
                .replace(':updated', updated.length);

            wrapper.append($('<p class="mb-2 small text-muted"></p>').text(summaryText));

            if (updated.length) {
                wrapper.append($('<h6 class="fw-semibold mb-1"></h6>').text(currencyImportI18n.updatedHeading));
                const list = $('<ul class="mb-2"></ul>');
                updated.forEach(function (entry) {
                    const countText = currencyImportI18n.updatedItemTemplate.replace(':count', entry?.quotes_updated ?? 0);
                    const label = entry?.currency_name ? entry.currency_name + ' — ' + countText : countText;
                    list.append($('<li class="small"></li>').text(label));
                });
                wrapper.append(list);
            }

            if (warnings.length) {
                wrapper.append($('<h6 class="fw-semibold mb-1"></h6>').text(currencyImportI18n.warningsHeading));
                wrapper.append(buildCurrencyImportIssueList(warnings));
            }

            if (errors.length) {
                wrapper.append($('<h6 class="fw-semibold mb-1"></h6>').text(currencyImportI18n.errorsHeading));
                wrapper.append(buildCurrencyImportIssueList(errors));
            }

            target.removeClass('d-none').append(wrapper);
        }

        function buildCurrencyImportIssueList(entries) {
            const list = $('<ul class="mb-2"></ul>');

            entries.forEach(function (entry) {
                const parts = [];

                if (typeof entry.row_number !== 'undefined') {
                    parts.push(currencyImportI18n.rowLabel + ' ' + entry.row_number);
                }

                if (entry.currency_name) {
                    parts.push(currencyImportI18n.currencyLabel + ': ' + entry.currency_name);
                }

                const prefix = parts.length ? parts.join(' · ') + ' — ' : '';
                const message = entry.message || '';

                list.append($('<li class="small"></li>').text(prefix + message));
            });

            return list;
        }


        function operateFormatter(value, row, index) {

            const buttons = [];

            @can('currency-rate-edit')
                const editUrl = currencyEditUrlTemplate.replace('__ID__', row.id);
                buttons.push(
                    '<a class="btn btn-sm btn-outline-primary me-1" href="' + editUrl + '" title="{{ __('Edit Currency Rate') }}">' +
                    '<i class="bi bi-pencil-square"></i>' +
                    '</a>'
                );
            @endcan

            
            @can('currency-rate-delete')
            buttons.push(
                '<a class="delete-currency btn btn-sm btn-danger" href="javascript:void(0)" title="{{ __('Delete') }}">',
                '<i class="bi bi-trash"></i>',
                '</a>'
            );
            @endcan


            buttons.push(
                '<button class="backfill-history btn btn-sm btn-outline-secondary ms-1" title="{{ __('Backfill history') }}">',
                '<i class="bi bi-clock-history"></i>',
                '</button>'
            );

            
            return buttons.join('');
        }

        window.currencyEvents = {

            'click .delete-currency': function (e, value, row, index) {
                if (confirm('هل أنت متأكد من حذف هذه العملة؟')) {
                    $.ajax({
                        url: '/currency/' + row.id,
                        type: 'DELETE',
                        headers: {
                            'X-CSRF-TOKEN': $('meta[name="csrf-token"]').attr('content')
                        },
                        success: function (response) {
                            if (response.success) {
                                $('#table_list').bootstrapTable('refresh');
                                showSuccessToast(response.message);
                            }
                        },
                        error: function (xhr) {
                            showErrorToast('حدث خطأ أثناء حذف العملة');
                            console.error(xhr);
                        }
                    });
                }


           },
            'click .backfill-history': function (e, value, row) {
                e.preventDefault();
                const defaultDays = row?.history?.range_hint ?? 7;
                const input = prompt('{{ __('Enter number of days to backfill (max 365)') }}', defaultDays);

                if (input === null) {
                    return;
                }

                const parsed = parseInt(input, 10);
                if (Number.isNaN(parsed) || parsed < 1 || parsed > 365) {
                    alert('{{ __('Please enter a valid number of days between 1 and 365.') }}');
                    return;
                }

                $.ajax({
                    url: `/currency/${row.id}/history/backfill`,
                    type: 'POST',
                    headers: {
                        'X-CSRF-TOKEN': $('meta[name="csrf-token"]').attr('content')
                    },
                    data: {
                        range_days: parsed
                    },
                    success: function (response) {
                        if (response.success) {
                            $('#table_list').bootstrapTable('refresh');
                            showSuccessToast(response.message);
                        } else if (response.message) {
                            showErrorToast(response.message);
                        }
                    },
                    error: function (xhr) {
                        const message = xhr?.responseJSON?.message || '{{ __('Unable to backfill history at the moment.') }}';
                        showErrorToast(message);
                        console.error(xhr);
                    }
                });

            }
        };






        $(function () {
            const form = $('#currency-import-form');

            if (!form.length) {
                return;
            }

            const successAlert = $('#currency-import-success');
            const errorAlert = $('#currency-import-error');
            const reportContainer = $('#currency-import-report');
            const submitButton = form.find('button[type="submit"]');

            form.on('submit', function (event) {
                event.preventDefault();

                successAlert.addClass('d-none').text('');
                errorAlert.addClass('d-none').text('');
                renderCurrencyImportReport(reportContainer, null);

                const formData = new FormData(this);

                submitButton.prop('disabled', true);

                $.ajax({
                    url: form.attr('action'),
                    method: 'POST',
                    data: formData,
                    processData: false,
                    contentType: false,
                    success: function (response) {
                        const message = response?.message || '{{ __('Currency rates imported successfully.') }}';
                        successAlert.removeClass('d-none').text(message);
                        showSuccessToast(message);
                        renderCurrencyImportReport(reportContainer, response.report);
                        $('#table_list').bootstrapTable('refresh');
                        form[0].reset();
                    },
                    error: function (xhr) {
                        const payload = xhr?.responseJSON;
                        const message = payload?.message || '{{ __('Unable to import currency rates at the moment.') }}';
                        errorAlert.removeClass('d-none').text(message);
                        showErrorToast(message);

                        if (payload?.errors && payload.errors.file) {
                            const validationMessage = payload.errors.file[0];
                            if (validationMessage && validationMessage !== message) {
                                errorAlert.append($('<div class="small mt-2"></div>').text(validationMessage));
                            }
                        }

                        renderCurrencyImportReport(reportContainer, payload?.report);
                    },
                    complete: function () {
                        submitButton.prop('disabled', false);
                    },
                });
            });
        });





        // $(function () {
        //     $('#table_list').bootstrapTable();
        // });
    </script>
@endsection

@push('scripts')
    <script src="{{ asset('js/currency.js') }}"></script>
@endpush
