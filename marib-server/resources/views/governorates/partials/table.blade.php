@php
    $showActions = $showActions ?? false;
@endphp

<div class="table-responsive">
    <table class="table table-striped table-hover align-middle mb-0">
        <thead>
        <tr>
            <th scope="col" style="width: 60px;">#</th>
            <th scope="col">{{ __('Name') }}</th>
            <th scope="col">{{ __('Code') }}</th>
            <th scope="col">{{ __('Status') }}</th>
            <th scope="col">{{ __('Updated at') }}</th>
            @if($showActions)
                <th scope="col" class="text-end">{{ __('Actions') }}</th>
            @endif
        </tr>
        </thead>
        <tbody>
        @forelse($governorates as $index => $governorate)
            <tr>
                <td>{{ is_numeric($index) ? $index + 1 : $loop->iteration }}</td>
                <td>
                    <span class="fw-semibold" data-governorate-name="{{ $governorate->id }}">{{ $governorate->name }}</span>
                </td>
                <td>
                    <code>{{ $governorate->code }}</code>
                </td>
                <td>
                    @if($governorate->is_active)
                        <span class="badge bg-success">{{ __('Active') }}</span>
                    @else
                        <span class="badge bg-secondary">{{ __('Inactive') }}</span>
                    @endif
                </td>
                <td>{{ optional($governorate->updated_at)->format('Y-m-d H:i') }}</td>
                @if($showActions)
                    <td class="text-end">
                        <div class="btn-group" role="group" aria-label="{{ __('Governorate actions') }}">
                            @can('governorate-edit')
                                <a href="{{ route('governorates.edit', $governorate) }}"
                                   class="btn btn-sm btn-outline-primary">
                                    {{ __('Edit') }}
                                </a>
                            @endcan

                            @can('governorate-delete')
                                <form action="{{ route('governorates.destroy', $governorate) }}" method="POST"
                                      onsubmit="return confirm('{{ __('Are you sure you want to delete this governorate?') }}');"
                                      class="ms-2">
                                    @csrf
                                    @method('DELETE')
                                    <button type="submit" class="btn btn-sm btn-outline-danger">
                                        {{ __('Delete') }}
                                    </button>
                                </form>
                            @endcan
                        </div>
                    </td>
                @endif
            </tr>
        @empty
            <tr>
                <td colspan="{{ $showActions ? 6 : 5 }}" class="text-center text-muted py-4">
                    {{ __('No governorates found yet.') }}
                </td>
            </tr>
        @endforelse
        </tbody>
    </table>
</div>