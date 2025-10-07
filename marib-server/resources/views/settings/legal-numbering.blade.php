@extends('layouts.main')

@section('title')
    {{ __('Legal Numbering') }}
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
        <form class="create-form-without-reset" action="{{ route('settings.legal-numbering.update') }}" method="post" data-success-function="successFunction">
            @csrf
            <div class="card">
                <div class="card-body">
                    <div class="divider pt-3">
                        <h6 class="divider-text">{{ __('Legal Numbering Settings') }}</h6>
                    </div>

                    <div class="table-responsive mt-3">
                        <table class="table table-bordered align-middle mb-0">
                            <thead>
                                <tr>
                                    <th>{{ __('Department') }}</th>
                                    <th class="text-center">{{ __('Legal Numbering Enabled') }}</th>
                                    <th>{{ __('Order Prefix') }}</th>
                                    <th>{{ __('Next Order Number') }}</th>
                                    <th>{{ __('Invoice Prefix') }}</th>
                                    <th>{{ __('Next Invoice Number') }}</th>
                                </tr>
                            </thead>
                            <tbody>
                                @foreach ($departments as $department)
                                    @php($key = $department['key'])
                                    @php($setting = $department['setting'])
                                    <tr>
                                        <td>
                                            <div class="fw-bold">{{ $department['label'] }}</div>
                                            @if ($key === \App\Models\DepartmentNumberSetting::DEFAULT_DEPARTMENT)
                                                <div class="small text-muted">{{ __('Applies when no department is selected.') }}</div>
                                            @endif
                                        </td>
                                        <td class="text-center">
                                            <div class="form-check form-switch d-flex justify-content-center">
                                                <input type="hidden" name="departments[{{ $key }}][legal_numbering_enabled]" value="0">
                                                <input class="form-check-input" type="checkbox" role="switch" value="1"
                                                    name="departments[{{ $key }}][legal_numbering_enabled]"
                                                    id="legal-numbering-{{ $key }}"
                                                    {{ $setting->legal_numbering_enabled ? 'checked' : '' }}>
                                            </div>
                                        </td>
                                        <td>
                                            <input type="text" name="departments[{{ $key }}][order_prefix]" class="form-control"
                                                value="{{ $setting->order_prefix ?? '' }}" placeholder="{{ __('Order Prefix') }}">
                                        </td>
                                        <td>
                                            <input type="number" min="1" name="departments[{{ $key }}][next_order_number]" class="form-control"
                                                value="{{ $setting->next_order_number ?? 1 }}">
                                        </td>
                                        <td>
                                            <input type="text" name="departments[{{ $key }}][invoice_prefix]" class="form-control"
                                                value="{{ $setting->invoice_prefix ?? '' }}" placeholder="{{ __('Invoice Prefix') }}">
                                        </td>
                                        <td>
                                            <input type="number" min="1" name="departments[{{ $key }}][next_invoice_number]" class="form-control"
                                                value="{{ $setting->next_invoice_number ?? 1 }}">
                                        </td>
                                    </tr>
                                @endforeach
                            </tbody>
                        </table>
                    </div>
                </div>
                <div class="card-footer d-flex justify-content-end">
                    <button type="submit" class="btn btn-primary">{{ __('Save Changes') }}</button>
                </div>
            </div>
        </form>
    </section>
@endsection