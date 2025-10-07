@php
    $advertiserData = $advertiser ?? [];
@endphp

<div class="row">
    <div class="col-12">
        <div class="card mb-4">
            <div class="card-header">
                <h5 class="card-title mb-0">{{ $title }}</h5>
            </div>
            <div class="card-body">
                <form action="{{ $action }}" method="POST" class="create-form-without-reset" enctype="multipart/form-data">
                    @csrf

                    <div class="row g-3">
                        <div class="col-md-6">
                            <label for="department-advertiser-name" class="form-label">{{ __('Name') }}</label>
                            <input
                                type="text"
                                id="department-advertiser-name"
                                name="name"
                                class="form-control"
                                value="{{ old('name', data_get($advertiserData, 'name')) }}"
                                required
                                maxlength="255"
                            >
                        </div>
                        <div class="col-md-6">
                            <label for="department-advertiser-contact" class="form-label">{{ __('Contact Number') }}</label>
                            <input
                                type="text"
                                id="department-advertiser-contact"
                                name="contact_number"
                                class="form-control"
                                value="{{ old('contact_number', data_get($advertiserData, 'contact_number')) }}"
                                maxlength="255"
                            >
                        </div>
                        <div class="col-md-6">
                            <label for="department-advertiser-message" class="form-label">{{ __('Message Number') }}</label>
                            <input
                                type="text"
                                id="department-advertiser-message"
                                name="message_number"
                                class="form-control"
                                value="{{ old('message_number', data_get($advertiserData, 'message_number')) }}"
                                maxlength="255"
                            >
                        </div>
                        <div class="col-md-6">
                            <label for="department-advertiser-location" class="form-label">{{ __('Location') }}</label>
                            <input
                                type="text"
                                id="department-advertiser-location"
                                name="location"
                                class="form-control"
                                value="{{ old('location', data_get($advertiserData, 'location')) }}"
                                maxlength="255"
                            >
                        </div>
                        <div class="col-12">
                            <label for="department-advertiser-image" class="form-label">{{ __('Image') }}</label>
                            <input
                                type="file"
                                id="department-advertiser-image"
                                name="image"
                                class="form-control"
                                accept="image/*"
                            >
                            @if (data_get($advertiserData, 'image'))
                                <div class="mt-2">
                                    <img src="{{ data_get($advertiserData, 'image') }}" alt="{{ __('Image') }}" class="img-thumbnail" style="max-height: 160px;">
                                </div>
                            @endif
                        </div>
                    </div>

                    <div class="mt-4">
                        <button type="submit" class="btn btn-primary">{{ __('Save') }}</button>
                    </div>
                </form>
            </div>
        </div>
    </div>
</div>