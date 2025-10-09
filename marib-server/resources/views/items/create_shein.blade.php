@extends('layouts.main')

@section('page-title')
    {{ __('Add New Shein Item') }}
@endsection

@section('content')
    <section class="section">
        <div class="card">
            <div class="card-body">
                <form id="createSheinForm" action="{{ route('item.shein.products.store') }}" method="POST" enctype="multipart/form-data" data-success-function="formSuccessFunction">
                    @csrf
                    
                    <div class="row">
                        <div class="col-md-6">
                            <div class="form-group mb-3">
                                <label for="name" class="form-label mandatory">{{ __('Name') }}</label>
                                <input type="text" id="name" name="name" class="form-control" required>
                            </div>
                        </div>
                        <div class="col-md-6">
                            <div class="form-group mb-3">
                                <label for="category_id" class="form-label mandatory">{{ __('Category') }}</label>
                                <select id="category_id" name="category_id" class="form-control select2" required>
                                    <option value="">{{ __('Select Category') }}</option>
                                    @foreach($categories as $category)
                                        <option value="{{ $category['id'] }}"
                                                data-icon="{{ $category['icon'] ?? '' }}"
                                                {{ old('category_id', $selectedCategoryId ?? request('category_id')) == $category['id'] ? 'selected' : '' }}>
                                            {{ $category['label'] ?? $category['name'] ?? '' }}
                                        </option>

                                    @endforeach
                                </select>
                            </div>
                        </div>
                    </div>

                    <div class="row">
                        <div class="col-md-6">
                            <div class="form-group mb-3">
                                <label for="price" class="form-label mandatory">{{ __('Price') }}</label>
                                <input type="number" id="price" name="price" class="form-control" step="0.01" min="0" required>
                            </div>
                        </div>
                        <div class="col-md-6">
                            <div class="form-group mb-3">
                                <label for="currency" class="form-label mandatory">{{ __('Currency') }}</label>
                                <select id="currency" name="currency" class="form-control" required>
                                    <option value="USD">USD</option>
                                    <option value="EUR">EUR</option>
                                    <option value="GBP">GBP</option>
                                    <option value="SAR">SAR</option>
                                </select>
                            </div>
                        </div>
                    </div>


                    <div class="row">
                        <div class="col-md-6">

                            <div class="form-group mb-3">
                                <label for="product_link" class="form-label mandatory">{{ __('Product Link') }}</label>
                                <input type="url" id="product_link" name="product_link" class="form-control @error('product_link') is-invalid @enderror" value="{{ old('product_link') }}" required maxlength="2048">
                                @error('product_link')
                                    <div class="invalid-feedback">{{ $message }}</div>
                                @enderror
                            </div>
                        </div>

                        <div class="col-md-6">
                            <div class="form-group mb-3">
                                <label for="review_link" class="form-label">{{ __('Review Link') }}</label>
                                <input type="url" id="review_link" name="review_link" class="form-control @error('review_link') is-invalid @enderror" value="{{ old('review_link') }}" maxlength="2048">
                                @error('review_link')
                                    <div class="invalid-feedback">{{ $message }}</div>
                                @enderror
                                <small class="form-text text-muted">{{ __('Provide a trusted external review URL (optional).') }}</small>
                            </div>
                        </div>

                    </div>



                    @if(isset($categoryIcons) && $categoryIcons->isNotEmpty())
                        <div class="row mb-3">
                            <div class="col-12">
                                <div class="d-flex flex-wrap gap-3">
                                    @foreach($categoryIcons as $categoryId => $icon)
                                        <div class="text-center">
                                            <img src="{{ $icon }}" alt="{{ $categories->firstWhere('id', $categoryId)['name'] ?? '' }}"
                                                 class="img-fluid rounded"
                                                 style="max-width: 70px; max-height: 70px; object-fit: contain;">
                                            <div class="small mt-2 text-muted">
                                                {{ $categories->firstWhere('id', $categoryId)['name'] ?? '' }}
                                            </div>
                                        </div>
                                    @endforeach
                                </div>
                            </div>
                        </div>
                    @endif


                    <div class="row">
                        <div class="col-md-12">
                            <div class="form-group mb-3">
                                <label for="description" class="form-label mandatory">{{ __('Description') }}</label>
                                <textarea id="description" name="description" class="form-control" rows="4" required></textarea>
                            </div>
                        </div>
                    </div>

                    <div class="row">
                        <div class="col-md-6">
                            <div class="form-group mb-3">
                                <label for="country" class="form-label">{{ __('Country') }}</label>
                                <input type="text" id="country" name="country" class="form-control">
                            </div>
                        </div>
                        <div class="col-md-6">
                            <div class="form-group mb-3">
                                <label for="state" class="form-label">{{ __('State') }}</label>
                                <input type="text" id="state" name="state" class="form-control">
                            </div>
                        </div>
                    </div>

                    <div class="row">
                        <div class="col-md-6">
                            <div class="form-group mb-3">
                                <label for="city" class="form-label">{{ __('City') }}</label>
                                <input type="text" id="city" name="city" class="form-control">
                            </div>
                        </div>
                        <div class="col-md-6">
                            <div class="form-group mb-3">
                                <label for="contact" class="form-label">{{ __('Contact') }}</label>
                                <input type="text" id="contact" name="contact" class="form-control">
                            </div>
                        </div>
                    </div>

                    <div class="row">
                        <div class="col-md-12">
                            <div class="form-group mb-3">
                                <label for="address" class="form-label">{{ __('Address') }}</label>
                                <textarea id="address" name="address" class="form-control" rows="2"></textarea>
                            </div>
                        </div>
                    </div>

                    <div class="row">
                        <div class="col-md-6">
                            <div class="form-group mb-3">
                                <label for="image" class="form-label mandatory">{{ __('Main Image') }}</label>
                                <input type="file" id="image" name="image" class="form-control" accept="image/*" required>
                                <div class="mt-2">
                                    <img id="image_preview" src="" alt="" style="max-width: 200px; display: none;">
                                </div>
                            </div>
                        </div>
                        <div class="col-md-6">
                            <div class="form-group mb-3">
                                <label for="gallery_images" class="form-label">{{ __('Gallery Images') }}</label>
                                <input type="file" id="gallery_images" name="gallery_images[]" class="form-control" accept="image/*" multiple>
                                <div id="gallery_preview" class="mt-2 d-flex flex-wrap"></div>
                            </div>
                        </div>
                    </div>

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
                                                    
                                                    @if($field->type == 'textbox')
                                                        <input type="text" 
                                                            id="custom_field_{{ $field->id }}" 
                                                            name="custom_fields[{{ $field->id }}]" 
                                                            class="form-control" 
                                                            {{ $field->required ? 'required' : '' }}
                                                            @if($field->min_length) minlength="{{ $field->min_length }}" @endif
                                                            @if($field->max_length) maxlength="{{ $field->max_length }}" @endif>
                                                    @elseif($field->type == 'number')
                                                        <input type="number" 
                                                            id="custom_field_{{ $field->id }}" 
                                                            name="custom_fields[{{ $field->id }}]" 
                                                            class="form-control" 
                                                            {{ $field->required ? 'required' : '' }}>
                                                    @elseif($field->type == 'textarea')
                                                        <textarea 
                                                            id="custom_field_{{ $field->id }}" 
                                                            name="custom_fields[{{ $field->id }}]" 
                                                            class="form-control" 
                                                            rows="3"
                                                            {{ $field->required ? 'required' : '' }}
                                                            @if($field->min_length) minlength="{{ $field->min_length }}" @endif
                                                            @if($field->max_length) maxlength="{{ $field->max_length }}" @endif></textarea>
                                                    @elseif($field->type == 'dropdown')
                                                        <select 
                                                            id="custom_field_{{ $field->id }}" 
                                                            name="custom_fields[{{ $field->id }}]" 
                                                            class="form-control select2" 
                                                            {{ $field->required ? 'required' : '' }}>
                                                            <option value="">{{ __('Select') }}</option>
                                                            @foreach($field->values as $value)
                                                                <option value="{{ $value }}">{{ $value }}</option>
                                                            @endforeach
                                                        </select>
                                                    @elseif($field->type == 'radio')
                                                        @foreach($field->values as $value)
                                                            <div class="form-check">
                                                                <input 
                                                                    type="radio" 
                                                                    id="custom_field_{{ $field->id }}_{{ $loop->index }}" 
                                                                    name="custom_fields[{{ $field->id }}]" 
                                                                    value="{{ $value }}" 
                                                                    class="form-check-input"
                                                                    {{ $loop->first && $field->required ? 'required' : '' }}>
                                                                <label class="form-check-label" for="custom_field_{{ $field->id }}_{{ $loop->index }}">{{ $value }}</label>
                                                            </div>
                                                        @endforeach
                                                    @elseif($field->type == 'checkbox')
                                                        @foreach($field->values as $value)
                                                            <div class="form-check">
                                                                <input 
                                                                    type="checkbox" 
                                                                    id="custom_field_{{ $field->id }}_{{ $loop->index }}" 
                                                                    name="custom_fields[{{ $field->id }}][]" 
                                                                    value="{{ $value }}" 
                                                                    class="form-check-input">
                                                                <label class="form-check-label" for="custom_field_{{ $field->id }}_{{ $loop->index }}">{{ $value }}</label>
                                                            </div>
                                                        @endforeach
                                                    @elseif($field->type == 'fileinput')
                                                        <input 
                                                            type="file" 
                                                            id="custom_field_{{ $field->id }}" 
                                                            name="custom_field_files[{{ $field->id }}]" 
                                                            class="form-control"
                                                            {{ $field->required ? 'required' : '' }}>
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
                            <button type="submit" class="btn btn-primary me-1 mb-1">{{ __('Submit') }}</button>
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
                const files = this.files;
                $('#gallery_preview').empty();
                
                for (let i = 0; i < files.length; i++) {
                    const file = files[i];
                    const reader = new FileReader();
                    
                    reader.onload = function(e) {
                        $('#gallery_preview').append(`
                            <div class="me-2 mb-2">
                                <img src="${e.target.result}" alt="Gallery Image" style="max-width: 100px; max-height: 100px;">
                            </div>
                        `);
                    }
                    
                    reader.readAsDataURL(file);
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