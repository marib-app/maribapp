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
            @can('currency-rate-create')
                <div class="col-md-4">
                    <div class="card">
                        <div class="card-body">
                            {!! Form::open(['route' => 'currency.store', 'data-parsley-validate', 'class'=>'create-form', 'files' => true]) !!}
                            <div class="row">
                                <div class="col-md-12 col-12 form-group mandatory">
                                    {{ Form::label('currency_name', __('Currency Name'), ['class' => 'form-label']) }}
                                    {{ Form::text('currency_name', '', [
                                        'class' => 'form-control',
                                        'placeholder' => __('Enter Currency Name'),
                                        'data-parsley-required' => 'true',
                                    ]) }}
                                </div>



                                <div class="col-md-12 col-12 form-group">
                                    {{ Form::label('icon', __('Icon (optional)'), ['class' => 'form-label']) }}
                                    <input type="file" name="icon" id="create_icon" class="form-control icon-input"
                                           accept="image/png,image/jpeg,image/jpg,image/webp,image/svg+xml">
                                    <small class="text-muted">{{ __('Max 2MB. Allowed types: JPG, PNG, SVG, WEBP.') }}</small>

                                    <div class="currency-icon-preview mt-2 d-none" data-preview="create">
                                        <img src="" alt="" class="img-thumbnail preview-image" style="max-height: 120px;">
                                        <div class="mt-2">
                                            <button type="button" class="btn btn-outline-danger btn-sm clear-icon"
                                                    data-target="create">{{ __('Remove icon') }}</button>
                                        </div>
                                    </div>
                                </div>

                                <div class="col-md-12 col-12 form-group">
                                    {{ Form::label('icon_alt', __('Icon alternative text'), ['class' => 'form-label']) }}
                                    {{ Form::text('icon_alt', '', [
                                        'class' => 'form-control icon-alt-input',
                                        'placeholder' => __('Describe the icon for accessibility (optional)')
                                    ]) }}
                                </div>

                                <div class="col-12">
                                    <div class="d-flex align-items-center justify-content-between">
                                        <label class="form-label mb-1">{{ __('Governorate price sets') }}</label>
                                        <span class="badge bg-light text-dark">{{ __('Inline editable') }}</span>
                                    </div>
                                </div>

                                <div class="col-12">
                                    <p class="text-muted small mb-2">
                                        {{ __('Enter sell/buy values for each governorate. Leave a row blank to skip it and choose one default fallback set.') }}
                                    </p>
                                    @include('currency.partials.quote-table', [
                                        'governorates' => $governorates,
                                        'context' => 'create',
                                        'quotes' => [],
                                        'defaultGovernorateId' => null,
                                    ])
                                </div>

                                <div class="col-12 text-end form-group">
                                    {{ Form::submit(__('Add Currency'), ['class' => 'btn btn-primary']) }}
                                </div>
                            </div>
                            {!! Form::close() !!}
                        </div>
                    </div>
                </div>
            @endcan

            <div class="{{Illuminate\Support\Facades\Auth::user()->can('currency-rate-create') ? 'col-md-8' : 'col-md-12' }}">
                <div class="card">
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

        <div class="modal fade" id="editModal" tabindex="-1" role="dialog" aria-labelledby="editModalLabel" aria-hidden="true">
            <div class="modal-dialog" role="document">
                <div class="modal-content">
                    <div class="modal-header">
                        <h5 class="modal-title" id="editModalLabel">{{ __('Edit Currency Rate') }}</h5>
                        <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                    </div>
                    <form action="" class="edit-form form-horizontal" method="POST" data-parsley-validate enctype="multipart/form-data">
                        @csrf
                        @method('PUT') {{-- أو PATCH حسب تعريف Route --}}
                        <div class="modal-body">
                            <input type="hidden" id="edit_id" name="edit_id">
                            <input type="hidden" name="remove_icon" id="edit_remove_icon" value="0">
                            <div class="row">
                                <div class="col-md-12 col-12 form-group mandatory">
                                    {{ Form::label('edit_currency_name', __('Currency Name'), ['class' => 'form-label']) }}
                                    {{ Form::text('currency_name', '', [
                                        'class' => 'form-control',
                                        'id' => 'edit_currency_name',
                                        'placeholder' => __('Enter Currency Name'),
                                        'data-parsley-required' => 'true',
                                    ]) }}
                                </div>



                                <div class="col-md-12 col-12 form-group">
                                    {{ Form::label('edit_icon', __('Icon (optional)'), ['class' => 'form-label']) }}
                                    <input type="file" name="icon" id="edit_icon" class="form-control icon-input"
                                           accept="image/png,image/jpeg,image/jpg,image/webp,image/svg+xml">
                                    <small class="text-muted">{{ __('Max 2MB. Allowed types: JPG, PNG, SVG, WEBP.') }}</small>

                                    <div class="currency-icon-preview mt-2 d-none" data-preview="edit">
                                        <img src="" alt="" class="img-thumbnail preview-image" style="max-height: 120px;">
                                        <div class="mt-2 d-flex gap-2">
                                            <button type="button" class="btn btn-outline-danger btn-sm clear-icon"
                                                    data-target="edit">{{ __('Remove icon') }}</button>
                                            <span class="text-muted current-icon-alt"></span>
                                        </div>
                                    </div>
                                </div>

                                <div class="col-md-12 col-12 form-group">
                                    {{ Form::label('edit_icon_alt', __('Icon alternative text'), ['class' => 'form-label']) }}
                                    {{ Form::text('icon_alt', '', [
                                        'class' => 'form-control icon-alt-input',
                                        'id' => 'edit_icon_alt',
                                        'placeholder' => __('Describe the icon for accessibility (optional)')
                                    ]) }}
                                </div>

                                <div class="col-12">
                                    <label class="form-label mb-1">{{ __('Governorate price sets') }}</label>
                                    <p class="text-muted small mb-2">
                                        {{ __('Update sell/buy values per governorate. Any empty row will be ignored; ensure one set remains marked as default.') }}
                                    </p>
                                    @include('currency.partials.quote-table', [
                                        'governorates' => $governorates,
                                        'context' => 'edit',
                                        'quotes' => [],
                                        'defaultGovernorateId' => null,
                                    ])
                                </div>


                            </div>
                        </div>
                        <div class="modal-footer">
                            <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">{{ __('Close') }}</button>
                            <button type="submit" class="btn btn-primary">{{ __('Save Changes') }}</button>
                        </div>
                    </form>
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




        function hydrateQuoteTable(context, quotes, defaultGovernorateId) {
            const table = $('.quotes-table[data-context="' + context + '"]');
            if (!table.length) {
                return;
            }

            table.find('tbody tr').each(function () {
                const row = $(this);
                row.find('.quote-sell-input').val('');
                row.find('.quote-buy-input').val('');
                row.find('.quote-source-input').val('');
                row.find('.quote-quoted-at-input').val('');
                row.find('.default-governorate-radio').prop('checked', false);
            });

            if (Array.isArray(quotes)) {
                quotes.forEach(function (quote) {
                    const row = table.find('tr[data-governorate-row="' + quote.governorate_id + '"]');
                    if (!row.length) {
                        return;
                    }

                    if (quote.sell_price !== undefined && quote.sell_price !== null) {
                        row.find('.quote-sell-input').val(quote.sell_price);
                    }

                    if (quote.buy_price !== undefined && quote.buy_price !== null) {
                        row.find('.quote-buy-input').val(quote.buy_price);
                    }

                    row.find('.quote-source-input').val(quote.source || '');

                    if (quote.quoted_at) {
                        const formatted = moment(quote.quoted_at).isValid()
                            ? moment(quote.quoted_at).format('YYYY-MM-DDTHH:mm')
                            : '';
                        row.find('.quote-quoted-at-input').val(formatted);
                    }

                    if (quote.is_default) {
                        row.find('.default-governorate-radio').prop('checked', true);
                    }
                });
            }

            if (defaultGovernorateId) {
                table.find('.default-governorate-radio[value="' + defaultGovernorateId + '"]').prop('checked', true);
            }

            if (!table.find('.default-governorate-radio:checked').length) {
                table.find('.default-governorate-radio').first().prop('checked', true);
            }
        }


        function operateFormatter(value, row, index) {
            var buttons = [
                '<a class="edit-currency btn btn-sm btn-primary me-1" href="javascript:void(0)" title="تعديل">',
                '<i class="bi bi-pencil-square"></i>',
                '</a>'
            ];
            
            @can('currency-rate-delete')
            buttons.push(
                '<a class="delete-currency btn btn-sm btn-danger" href="javascript:void(0)" title="حذف">',
                '<i class="bi bi-trash"></i>',
                '</a>'
            );
            @endcan
            
            return buttons.join('');
        }

        window.currencyEvents = {
            'click .edit-currency': function (e, value, row, index) {
                // e.preventDefault();

                const currencyId = row.id;
                $('#editModal #edit_id').val(row.id);
                $('#editModal #edit_currency_name').val(row.currency_name);


                const updateUrl = `/currency/${currencyId}`;
                $('.edit-form').attr('action', updateUrl);

                $('#edit_remove_icon').val('0');
                $('#edit_icon').val('');
                $('#edit_icon_alt').val(row.icon_alt || '');


                const quotes = Array.isArray(row.quotes) ? row.quotes : [];
                const defaultQuote = quotes.find ? quotes.find(q => q.is_default) : null;
                hydrateQuoteTable('edit', quotes, defaultQuote ? defaultQuote.governorate_id : null);


                $(document).trigger('currency:edit-open', [row]);



                $('#editModal').modal('show');
            },
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
            }
        };

        // $(function () {
        //     $('#table_list').bootstrapTable();
        // });
    </script>
@endsection