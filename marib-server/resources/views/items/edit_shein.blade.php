@extends('layouts.main')

@section('page-title')
    {{ __('Edit Shein Item') }}
@endsection

@section('content')
    <section class="section">
        <div class="card">
            <div class="card-body">
                <form id="editSheinForm" action="{{ route('item.shein.products.update', $item->id) }}" method="POST" enctype="multipart/form-data" data-success-function="formSuccessFunction">
                    @csrf
                    <div class="row">
                        <div class="col-md-6">
                            <div class="form-group mb-3">
                                <label for="name" class="form-label mandatory">{{ __('Name') }}</label>
                                <input type="text" id="name" name="name" class="form-control" value="{{ $item->name }}" required>
                            </div>
                        </div>
                        <div class="col-md-6">
                            <div class="form-group mb-3">
                                <label for="category_id" class="form-label mandatory">{{ __('Category') }}</label>
                                <select id="category_id" name="category_id" class="form-control select2" required>
                                    <option value="">{{ __('Select Category') }}</option>
                                    @foreach($categories as $category)
                                        <option value="{{ $category['id'] }}" {{ $item->category_id == $category['id'] ? 'selected' : '' }}>{{ $category['label'] ?? $category['name'] ?? '' }}</option>
                                    @endforeach
                                </select>
                            </div>
                        </div>
                    </div>


                    <div class="row">
                        <div class="col-md-6">
                            <div class="form-group mb-3">
                                <label for="product_link" class="form-label mandatory">{{ __('Product Link') }}</label>
                                <input type="url" id="product_link" name="product_link" class="form-control @error('product_link') is-invalid @enderror" value="{{ old('product_link', $item->product_link) }}" required maxlength="2048">
                                @error('product_link')
                                    <div class="invalid-feedback">{{ $message }}</div>
                                @enderror
                            </div>
                        </div>

                        <div class="col-md-6">
                            <div class="form-group mb-3">
                                <label for="review_link" class="form-label">{{ __('Review Link') }}</label>
                                <input type="url" id="review_link" name="review_link" class="form-control @error('review_link') is-invalid @enderror" value="{{ old('review_link', $item->review_link) }}" maxlength="2048">
                                @error('review_link')
                                    <div class="invalid-feedback">{{ $message }}</div>
                                @enderror
                                <small class="form-text text-muted">{{ __('Provide a trusted external review URL (optional).') }}</small>
                            </div>
                        </div>

                    </div>


                    <div class="row">
                        <div class="col-md-6">
                            <div class="form-group mb-3">
                                <label for="price" class="form-label mandatory">{{ __('Price') }}</label>
                                <input type="number" id="price" name="price" class="form-control" step="0.01" min="0" value="{{ $item->price }}" required>
                            </div>
                        </div>
                        <div class="col-md-6">
                            <div class="form-group mb-3">
                                <label for="currency" class="form-label mandatory">{{ __('Currency') }}</label>
                                <select id="currency" name="currency" class="form-control" required>
                                    <option value="USD" {{ $item->currency == 'USD' ? 'selected' : '' }}>USD</option>
                                    <option value="EUR" {{ $item->currency == 'EUR' ? 'selected' : '' }}>EUR</option>
                                    <option value="GBP" {{ $item->currency == 'GBP' ? 'selected' : '' }}>GBP</option>
                                    <option value="SAR" {{ $item->currency == 'SAR' ? 'selected' : '' }}>SAR</option>
                                </select>
                            </div>
                        </div>
                    </div>

                    <div class="row">
                        <div class="col-md-6">
                            <div class="form-group mb-3">
                                <label for="status" class="form-label mandatory">{{ __('Status') }}</label>
                                <select id="status" name="status" class="form-control" required>
                                    <option value="review" {{ $item->status == 'review' ? 'selected' : '' }}>{{ __('Under Review') }}</option>
                                    <option value="Approve" {{ $item->status == 'approved' ? 'selected' : '' }}>{{ __('Approved') }}</option>
                                    <option value="Reject" {{ $item->status == 'rejected' ? 'selected' : '' }}>{{ __('Rejected') }}</option>
                                </select>
                            </div>
                        </div>
                        <div class="col-md-6" id="rejected_reason_container" style="{{ $item->status == 'rejected' ? '' : 'display: none;' }}">
                            <div class="form-group mb-3">
                                <label for="rejected_reason" class="form-label">{{ __('Rejection Reason') }}</label>
                                <textarea id="rejected_reason" name="rejected_reason" class="form-control" rows="2">{{ $item->rejected_reason }}</textarea>
                            </div>
                        </div>
                    </div>

                    <div class="row">
                        <div class="col-md-12">
                            <div class="form-group mb-3">
                                <label for="description" class="form-label mandatory">{{ __('Description') }}</label>
                                <textarea id="description" name="description" class="form-control" rows="4" required>{{ $item->description }}</textarea>
                            </div>
                        </div>
                    </div>

                    <div class="row">
                        <div class="col-md-6">
                            <div class="form-group mb-3">
                                <label for="country" class="form-label">{{ __('Country') }}</label>
                                <input type="text" id="country" name="country" class="form-control" value="{{ $item->country }}">
                            </div>
                        </div>
                        <div class="col-md-6">
                            <div class="form-group mb-3">
                                <label for="state" class="form-label">{{ __('State') }}</label>
                                <input type="text" id="state" name="state" class="form-control" value="{{ $item->state }}">
                            </div>
                        </div>
                    </div>

                    <div class="row">
                        <div class="col-md-6">
                            <div class="form-group mb-3">
                                <label for="city" class="form-label">{{ __('City') }}</label>
                                <input type="text" id="city" name="city" class="form-control" value="{{ $item->city }}">
                            </div>
                        </div>
                        <div class="col-md-6">
                            <div class="form-group mb-3">
                                <label for="contact" class="form-label">{{ __('Contact') }}</label>
                                <input type="text" id="contact" name="contact" class="form-control" value="{{ $item->contact }}">
                            </div>
                        </div>
                    </div>

                    <div class="row">
                        <div class="col-md-12">
                            <div class="form-group mb-3">
                                <label for="address" class="form-label">{{ __('Address') }}</label>
                                <textarea id="address" name="address" class="form-control" rows="2">{{ $item->address }}</textarea>
                            </div>
                        </div>
                    </div>

                    <div class="row">
                        <div class="col-md-6">
                            <div class="form-group mb-3">
                                <label for="image" class="form-label">{{ __('Main Image') }}</label>
                                <input type="file" id="image" name="image" class="form-control" accept="image/*">
                                <div class="mt-2">
                                    @if($item->image)
                                        <img id="image_preview" src="{{ $item->getRawOriginal('image') ? asset('storage/' . $item->getRawOriginal('image')) : $item->image }}" alt="" style="max-width: 200px;">
                                    @else
                                        <img id="image_preview" src="" alt="" style="max-width: 200px; display: none;">
                                    @endif
                                </div>
                            </div>
                        </div>
                        <div class="col-md-6">
                            <div class="form-group mb-3">
                                <label for="gallery_images" class="form-label">{{ __('Add Gallery Images') }}</label>
                                <input type="file" id="gallery_images" name="gallery_images[]" class="form-control" accept="image/*" multiple>
                                <div id="gallery_preview" class="mt-2 d-flex flex-wrap"></div>
                            </div>
                        </div>
                    </div>

                    @if($item->gallery_images->count() > 0)
                        <div class="row mt-4">
                            <div class="col-md-12">
                                <h5>{{ __('Current Gallery Images') }}</h5>
                                <div class="d-flex flex-wrap">
                                    @foreach($item->gallery_images as $gallery)
                                        <div class="position-relative me-3 mb-3 gallery-item" data-id="{{ $gallery->id }}">
                                            <img src="{{ $gallery->getRawOriginal('image') ? asset('storage/' . $gallery->getRawOriginal('image')) : $gallery->image }}" alt="" style="max-width: 150px; max-height: 150px;">
                                            <button type="button" class="btn btn-sm btn-danger position-absolute top-0 end-0 remove-gallery-image" data-id="{{ $gallery->id }}">
                                                <i class="bi bi-x"></i>
                                            </button>
                                        </div>
                                    @endforeach
                                </div>
                                <input type="hidden" name="delete_gallery_images" id="delete_gallery_images" value="">
                            </div>
                        </div>
                    @endif

                    @if(count($customFields) > 0)
                    <div class="row mt-4">
                        <div class="col-12">
                            <div class="card">
                                <div class="card-header">
                                    <h5>{{ __('Custom Fields') }}</h5>
                                </div>
                                <div class="card-body">
                                    <div class="row">
                                        @foreach($customFields as $field)
                                            <div class="col-md-6 mb-3">
                                                <div class="form-group">
                                                    <label for="custom_field_{{ $field->id }}" class="form-label {{ $field->required ? 'mandatory' : '' }}">
                                                        {{ $field->name }}
                                                    </label>
                                                    
                                                    @php
                                                        $fieldValue = $item->item_custom_field_values->firstWhere('custom_field_id', $field->id);
                                                        $value = $fieldValue ? $fieldValue->value : null;
                                                    @endphp
                                                    
                                                    @if($field->type == 'textbox')
                                                        <input type="text" 
                                                            id="custom_field_{{ $field->id }}" 
                                                            name="custom_fields[{{ $field->id }}]" 
                                                            class="form-control" 
                                                            value="{{ $value ?? '' }}"
                                                            {{ $field->required ? 'required' : '' }}
                                                            @if($field->min_length) minlength="{{ $field->min_length }}" @endif
                                                            @if($field->max_length) maxlength="{{ $field->max_length }}" @endif>
                                                    @elseif($field->type == 'number')
                                                        <input type="number" 
                                                            id="custom_field_{{ $field->id }}" 
                                                            name="custom_fields[{{ $field->id }}]" 
                                                            class="form-control" 
                                                            value="{{ $value ?? '' }}"
                                                            {{ $field->required ? 'required' : '' }}>
                                                    @elseif($field->type == 'textarea')
                                                        <textarea 
                                                            id="custom_field_{{ $field->id }}" 
                                                            name="custom_fields[{{ $field->id }}]" 
                                                            class="form-control" 
                                                            rows="3"
                                                            {{ $field->required ? 'required' : '' }}
                                                            @if($field->min_length) minlength="{{ $field->min_length }}" @endif
                                                            @if($field->max_length) maxlength="{{ $field->max_length }}" @endif>{{ $value ?? '' }}</textarea>
                                                    @elseif($field->type == 'dropdown')
                                                        <select 
                                                            id="custom_field_{{ $field->id }}" 
                                                            name="custom_fields[{{ $field->id }}]" 
                                                            class="form-control select2" 
                                                            {{ $field->required ? 'required' : '' }}>
                                                            <option value="">{{ __('Select') }}</option>
                                                            @foreach($field->values as $optionValue)
                                                                <option value="{{ $optionValue }}" {{ $value == $optionValue ? 'selected' : '' }}>{{ $optionValue }}</option>
                                                            @endforeach
                                                        </select>
                                                    @elseif($field->type == 'radio')
                                                        @foreach($field->values as $optionValue)
                                                            <div class="form-check">
                                                                <input 
                                                                    type="radio" 
                                                                    id="custom_field_{{ $field->id }}_{{ $loop->index }}" 
                                                                    name="custom_fields[{{ $field->id }}]" 
                                                                    value="{{ $optionValue }}" 
                                                                    class="form-check-input"
                                                                    {{ $value == $optionValue ? 'checked' : '' }}
                                                                    {{ $loop->first && $field->required ? 'required' : '' }}>
                                                                <label class="form-check-label" for="custom_field_{{ $field->id }}_{{ $loop->index }}">{{ $optionValue }}</label>
                                                            </div>
                                                        @endforeach
                                                    @elseif($field->type == 'checkbox')
                                                        @foreach($field->values as $optionValue)
                                                            <div class="form-check">
                                                                <input 
                                                                    type="checkbox" 
                                                                    id="custom_field_{{ $field->id }}_{{ $loop->index }}" 
                                                                    name="custom_fields[{{ $field->id }}][]" 
                                                                    value="{{ $optionValue }}" 
                                                                    class="form-check-input"
                                                                    {{ is_array($value) && in_array($optionValue, $value) ? 'checked' : '' }}>
                                                                <label class="form-check-label" for="custom_field_{{ $field->id }}_{{ $loop->index }}">{{ $optionValue }}</label>
                                                            </div>
                                                        @endforeach
                                                    @elseif($field->type == 'fileinput')
                                                        <input 
                                                            type="file" 
                                                            id="custom_field_{{ $field->id }}" 
                                                            name="custom_field_files[{{ $field->id }}]" 
                                                            class="form-control"
                                                            {{ $field->required && !$value ? 'required' : '' }}>
                                                        @if($value)
                                                            <div class="mt-2">
                                                                <img src="{{ asset('storage/' . $value) }}" alt="" style="max-width: 100px;">
                                                            </div>
                                                        @endif
                                                    @endif
                                                    
                                                    @if($field->notes)
                                                        <div class="form-text text-muted">{{ $field->notes }}</div>
                                                    @endif
                                                </div>
                                            </div>
                                        @endforeach
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                    @endif

                    <div class="row mt-4">
                        <div class="col-12">
                            <button type="submit" class="btn btn-primary me-1 mb-1">{{ __('Update') }}</button>
                            <a href="{{ route('item.shein.products') }}" class="btn btn-light-secondary me-1 mb-1">{{ __('Cancel') }}</a>
                        </div>
                    </div>
                </form>
            </div>
        </div>
    </section>
@endsection

@section('script')
    <script>
        $(document).ready(function() {
            // Initialize Select2
            $('.select2').select2({
                width: '100%'
            });

            // Image preview
            $('#image').change(function() {
                const file = this.files[0];
                if (file) {
                    const reader = new FileReader();
                    reader.onload = function(e) {
                        $('#image_preview').attr('src', e.target.result).show();
                    }
                    reader.readAsDataURL(file);
                }
            });

            // Gallery images preview
            $('#gallery_images').change(function() {
                $('#gallery_preview').html('');
                const files = this.files;
                for (let i = 0; i < files.length; i++) {
                    const file = files[i];
                    const reader = new FileReader();
                    reader.onload = function(e) {
                        $('#gallery_preview').append(`
                            <div class="position-relative me-2 mb-2">
                                <img src="${e.target.result}" alt="" style="max-width: 100px; max-height: 100px;">
                            </div>
                        `);
                    }
                    reader.readAsDataURL(file);
                }
            });

            // Handle gallery image removal
            let deleteGalleryImages = [];
            $('.remove-gallery-image').click(function() {
                const id = $(this).data('id');
                deleteGalleryImages.push(id);
                $('#delete_gallery_images').val(deleteGalleryImages.join(','));
                $(this).closest('.gallery-item').remove();
            });
            
            // Handle status change
            $('#status').change(function() {
                if ($(this).val() == 'rejected') {
                    $('#rejected_reason_container').show();
                    $('#rejected_reason').attr('required', true);
                } else {
                    $('#rejected_reason_container').hide();
                    $('#rejected_reason').attr('required', false);
                }
            });
        });

        function formSuccessFunction(response) {
            if (!response.error) {
                window.location.href = response.redirect;
            }
        }
    </script>
@endsection 