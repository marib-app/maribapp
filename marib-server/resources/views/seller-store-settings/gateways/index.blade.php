@extends('layouts.main')

@section('title')
    {{ __('Store Payment Gateways') }}
@endsection

@section('page-title')
    <div class="page-title">
        <div class="row">
            <div class="col-12 col-md-6 order-md-1 order-last">
                <h4>@yield('title')</h4>
            </div>
            <div class="col-12 col-md-6 order-md-2 order-first d-flex justify-content-md-end align-items-center gap-2">
                <a href="{{ route('seller-store-settings.index') }}" class="btn btn-outline-secondary">
                    {{ __('Back to Store Settings') }}
                </a>
                <a href="{{ route('seller-store-settings.gateways.create') }}" class="btn btn-primary">
                    {{ __('Add Gateway') }}
                </a>
            </div>
        </div>
    </div>
@endsection

@section('content')
    <section class="section">
        <div class="card">
            <div class="card-body">
                @if (session('success'))
                    <div class="alert alert-success" role="alert">
                        {{ session('success') }}
                    </div>
                @endif

                @if ($errors->has('message'))
                    <div class="alert alert-danger" role="alert">
                        {{ $errors->first('message') }}
                    </div>
                @endif

                <div class="table-responsive">
                    <table class="table table-striped align-middle">
                        <thead>
                            <tr>
                                <th>{{ __('Gateway') }}</th>
                                <th>{{ __('Status') }}</th>
                                <th>{{ __('Merchant Accounts') }}</th>
                                <th class="text-nowrap">{{ __('Updated At') }}</th>
                                <th class="text-end">{{ __('Actions') }}</th>
                            </tr>
                        </thead>
                        <tbody>
                            @forelse ($storeGateways as $gateway)
                                <tr>
                                    <td>
                                        <div class="d-flex align-items-center gap-3">
                                            <img
                                                src="{{ \Illuminate\Support\Facades\Storage::disk(config('filesystems.default'))->url($gateway->logo_path) }}"
                                                alt="{{ $gateway->name }}"
                                                class="rounded border"
                                                style="width: 60px; height: 60px; object-fit: contain;"
                                            >
                                            <div>
                                                <div class="fw-semibold">{{ $gateway->name }}</div>
                                                <div class="text-muted small">{{ __('ID: :id', ['id' => $gateway->id]) }}</div>
                                            </div>
                                        </div>
                                    </td>
                                    <td>
                                        <div class="d-flex align-items-center gap-2">
                                            @if ($gateway->is_active)
                                                <span class="badge bg-success">{{ __('Enabled') }}</span>
                                            @else
                                                <span class="badge bg-secondary">{{ __('Disabled') }}</span>
                                            @endif
                                            <form
                                                action="{{ route('seller-store-settings.gateways.toggle', $gateway) }}"
                                                method="post"
                                            >
                                                @csrf
                                                @method('patch')
                                                <input type="hidden" name="is_active" value="{{ $gateway->is_active ? 0 : 1 }}">
                                                <button type="submit" class="btn btn-sm btn-outline-primary">
                                                    {{ $gateway->is_active ? __('Disable') : __('Enable') }}
                                                </button>
                                            </form>
                                        </div>
                                    </td>
                                    <td>
                                        @if ($gateway->accounts->isEmpty())
                                            <span class="text-muted">{{ __('No merchant accounts added yet.') }}</span>
                                        @else
                                            <ul class="list-unstyled mb-0 d-flex flex-column gap-2">
                                                @foreach ($gateway->accounts as $account)
                                                    <li class="border rounded p-2">
                                                        <div class="d-flex justify-content-between align-items-start">
                                                            <div>
                                                                <div class="fw-semibold">{{ $account->beneficiary_name }}</div>
                                                                <div class="text-muted small text-break">{{ $account->account_number }}</div>
                                                                @if ($account->user)
                                                                    <div class="small text-muted">{{ __('Merchant: :name', ['name' => $account->user->name]) }}</div>
                                                                @endif
                                                            </div>
                                                            <div class="text-end">
                                                                <span class="badge {{ $account->is_active ? 'bg-success' : 'bg-secondary' }}">
                                                                    {{ $account->is_active ? __('Active') : __('Inactive') }}
                                                                </span>
                                                                <form
                                                                    action="{{ route('seller-store-settings.gateway-accounts.toggle', $account) }}"
                                                                    method="post"
                                                                    class="mt-2"
                                                                >
                                                                    @csrf
                                                                    @method('patch')
                                                                    <input type="hidden" name="is_active" value="{{ $account->is_active ? 0 : 1 }}">
                                                                    <button type="submit" class="btn btn-sm btn-outline-primary">
                                                                        {{ $account->is_active ? __('Disable') : __('Enable') }}
                                                                    </button>
                                                                </form>
                                                            </div>
                                                        </div>
                                                    </li>
                                                @endforeach
                                            </ul>
                                        @endif
                                    </td>
                                    <td class="text-nowrap">
                                        {{ $gateway->updated_at ? $gateway->updated_at->timezone(config('app.timezone', 'UTC'))->format('M j, Y H:i') : __('Never') }}
                                    </td>
                                    <td class="text-end">
                                        <div class="d-flex justify-content-end gap-2">
                                            <a
                                                href="{{ route('seller-store-settings.gateways.edit', $gateway) }}"
                                                class="btn btn-sm btn-outline-secondary"
                                            >
                                                {{ __('Edit') }}
                                            </a>
                                            <form
                                                action="{{ route('seller-store-settings.gateways.destroy', $gateway) }}"
                                                method="post"
                                                onsubmit="return confirm('{{ __('Are you sure you want to delete this gateway? This cannot be undone.') }}');"
                                            >
                                                @csrf
                                                @method('delete')
                                                <button type="submit" class="btn btn-sm btn-outline-danger">
                                                    {{ __('Delete') }}
                                                </button>
                                            </form>
                                        </div>
                                    </td>
                                </tr>
                            @empty
                                <tr>
                                    <td colspan="5" class="text-center text-muted py-5">
                                        {{ __('No store payment gateways have been created yet.') }}
                                    </td>
                                </tr>
                            @endforelse
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    </section>
@endsection