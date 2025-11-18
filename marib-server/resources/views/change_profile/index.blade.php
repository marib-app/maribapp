@extends('layouts.main')

@section('title')
    {{ __('Change Profile') }}
@endsection

@section('content')
    <section class="section">
        <div class="card">
            <div class="card-header">
                <div class="divider">
                    <h4>{{ __('Change Profile') }}</h4>
                </div>
            </div>

            @php
                $authUser = Auth::user();
                $isSeller = $authUser?->account_type === \App\Models\User::ACCOUNT_TYPE_SELLER;
                $store = $authUser?->store;
                $storeName = $store->name ?? null;
                $displayName = $isSeller ? ($storeName ?: $authUser->name) : $authUser->name;
                $profileImage = $isSeller
                    ? ($store->logo_path ?? $store->logo ?? $authUser->profile)
                    : $authUser->profile;
                $profileImage = $profileImage ?: asset('assets/images/faces/2.jpg');
            @endphp
            {{ Form::open(['url' => route('change-profile.update'), 'class' => 'create-form-without-reset', 'files' => true]) }}
            <div class="row mt-1">
                <div class="card-body">
                    <div class="form-group row">
                        <label class="col-sm-4 col-form-label text-alert text-center">{{ __('Profile') }}</label>
                        <div class="col-sm-4 cs_field_img ">
                            <input type="file" name="profile" class="image" style="display: none" accept=" .jpg, .jpeg, .png, .svg">
                            <img src="{{ $profileImage }}" alt="" class="img preview-image">
                            <div class='img_input'>{{__("Browse File")}}</div>
                        </div>
                        <div class="img_error" style="color:#DC3545;"></div>
                    </div>

                    <div class="form-group row">
                        <label for="name" class="col-sm-4 col-form-label text-alert text-center">
                            {{ $isSeller ? __('Store Name') : __('Name') }}
                        </label>
                        <div class="col-sm-4">
                            <input
                                type="text"
                                name="name"
                                id="name"
                                class="form-control form-control-lg form-control-solid mb-2"
                                placeholder="{{ $isSeller ? __('Store Name') : __('Name') }}"
                                value="{{ old('name', $displayName) }}"
                                required
                            />
                        </div>
                    </div>

                    <div class="form-group row">
                        <label for="{{ __('email') }}" class="col-sm-4 col-form-label text-alert text-center">{{ __('Email') }}</label>
                        <div class="col-sm-4">
                            <input type="email" name="{{ __('email') }}" id="{{ __('email') }}" class="form-control form-control-lg form-control-solid mb-2" placeholder="{{__("Email")}}" value="{{ Auth::user()->email }}" required/>
                        </div>
                    </div>

                    <div class="form-group row">
                        <label class="col-sm-4 col-form-label text-alert">&nbsp;</label>
                        <div class="col-sm-12 text-end">
                            <button type="submit" name="btnadd" value="btnadd" class="btn btn-primary float-right">{{ __('Change') }}</button>
                        </div>
                    </div>
                </div>
            </div>
            {!! Form::close() !!}
        </div>
    </section>
@endsection
