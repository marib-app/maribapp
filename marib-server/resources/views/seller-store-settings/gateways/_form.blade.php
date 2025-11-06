<div class="row g-4">
    <div class="col-12">
        <div class="mb-3">
            <label class="form-label" for="gateway_name">{{ __('Gateway Name') }}</label>
            <input
                type="text"
                id="gateway_name"
                name="name"
                class="form-control @error('name') is-invalid @enderror"
                value="{{ old('name', $storeGateway->name ?? '') }}"
                maxlength="255"
                required
            >
            @error('name')
                <div class="invalid-feedback">{{ $message }}</div>
            @enderror
        </div>
    </div>

    <div class="col-12">
        <div class="mb-3">
            <label class="form-label" for="gateway_logo">{{ __('Gateway Logo') }}</label>
            <input
                type="file"
                id="gateway_logo"
                name="logo"
                class="form-control @error('logo') is-invalid @enderror"
                accept="image/*"
                {{ isset($storeGateway) ? '' : 'required' }}
            >
            @error('logo')
                <div class="invalid-feedback">{{ $message }}</div>
            @enderror

            @isset($storeGateway)
                <div class="mt-3">
                    <span class="text-muted small d-block">{{ __('Current Logo') }}</span>
                    <img
                        src="{{ \Illuminate\Support\Facades\Storage::disk(config('filesystems.default'))->url($storeGateway->logo_path) }}"
                        alt="{{ $storeGateway->name }}"
                        class="border rounded"
                        style="max-height: 80px; max-width: 160px; object-fit: contain;"
                    >
                </div>
            @endisset
        </div>
    </div>

    <div class="col-12">
        <div class="form-check form-switch">
            <input
                class="form-check-input"
                type="checkbox"
                role="switch"
                id="gateway_is_active"
                name="is_active"
                value="1"
                {{ old('is_active', isset($storeGateway) ? $storeGateway->is_active : true) ? 'checked' : '' }}
            >
            <label class="form-check-label" for="gateway_is_active">{{ __('Active') }}</label>
        </div>
    </div>

    <div class="col-12 d-flex justify-content-end gap-2">
        <a href="{{ route('seller-store-settings.gateways.index') }}" class="btn btn-outline-secondary">
            {{ __('Cancel') }}
        </a>
        <button type="submit" class="btn btn-primary">
            {{ $submitLabel ?? __('Save Gateway') }}
        </button>
    </div>
</div>