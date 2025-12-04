@extends('layouts.app')

@section('title', $config->exists ? 'تعديل إعداد الإعلانات المميزة' : 'إضافة إعداد إعلانات مميزة')

@section('content')
  <div class="container-fluid">
    <h5 class="mb-3">{{ $config->exists ? 'تعديل الإعداد' : 'إضافة إعداد جديد' }}</h5>

    @if($errors->any())
      <div class="alert alert-danger">
        <ul class="mb-0">
          @foreach($errors->all() as $error)
            <li>{{ $error }}</li>
          @endforeach
        </ul>
      </div>
    @endif

    <div class="card">
      <div class="card-body">
        <form method="POST"
              action="{{ $config->exists ? route('featured-ads-configs.update', $config) : route('featured-ads-configs.store') }}">
          @csrf
          @if($config->exists)
            @method('PUT')
          @endif

          <div class="row g-3">
            <div class="col-md-4">
              <label class="form-label">الاسم</label>
              <input type="text" name="name" class="form-control" value="{{ old('name', $config->name) }}">
            </div>
            <div class="col-md-4">
              <label class="form-label">العنوان الظاهر (اختياري)</label>
              <input type="text" name="title" class="form-control" value="{{ old('title', $config->title) }}">
            </div>
            <div class="col-md-4">
              <label class="form-label">الترتيب في الواجهة</label>
              <input type="number" name="position" class="form-control" value="{{ old('position', $config->position ?? 0) }}">
            </div>

            <div class="col-md-4">
              <label class="form-label">القسم (نوع الواجهة)</label>
              <select name="interface_type" class="form-select" required>
                <option value="">-- اختر القسم --</option>
                @foreach($sectionTypes as $section)
                  <option value="{{ $section }}" @selected(old('interface_type', $config->interface_type) === $section)>{{ $section }}</option>
                @endforeach
              </select>
            </div>

            <div class="col-md-4">
              <label class="form-label">فئة الجذر (اختياري لتقييد العرض)</label>
              <input type="number" name="root_category_id" class="form-control"
                     value="{{ old('root_category_id', $config->root_category_id) }}">
            </div>

            <div class="col-md-4">
              <label class="form-label">الستايل</label>
              <select name="style_key" class="form-select">
                @php $styles = ['style_1','style_2','style_3','style_4']; @endphp
                <option value="">-- اختر --</option>
                @foreach($styles as $style)
                  <option value="{{ $style }}" @selected(old('style_key', $config->style_key) === $style)>{{ $style }}</option>
                @endforeach
              </select>
            </div>
            <div class="col-md-4">
              <label class="form-label">ترتيب الإعلانات</label>
              <select name="order_mode" class="form-select" required>
                <option value="">-- اختر --</option>
                @php $orders = [
                    'latest' => 'الأحدث إضافة',
                    'most_viewed' => 'الأكثر مشاهدة',
                    'lowest_price' => 'الأقل سعراً',
                    'highest_price' => 'الأعلى سعراً',
                    'premium' => 'الإعلانات المميزة (مدفوعة)',
                ]; @endphp
                @foreach($orders as $key => $label)
                  <option value="{{ $key }}" @selected(old('order_mode', $config->order_mode) === $key)>{{ $label }}</option>
                @endforeach
              </select>
            </div>
            <div class="col-md-4 d-flex align-items-center">
              <div class="form-check mt-4">
                <input class="form-check-input" type="checkbox" name="enabled" value="1"
                       id="enabledCheck" {{ old('enabled', $config->enabled ?? true) ? 'checked' : '' }}>
                <label class="form-check-label" for="enabledCheck">مفعّل</label>
              </div>
            </div>
            <div class="col-md-4 d-flex align-items-center">
              <div class="form-check mt-4">
                <input class="form-check-input" type="checkbox" name="enable_ad_slider" value="1"
                       id="sliderCheck" {{ old('enable_ad_slider', $config->enable_ad_slider ?? true) ? 'checked' : '' }}>
                <label class="form-check-label" for="sliderCheck">تفعيل شريط الإعلانات</label>
              </div>
            </div>
          </div>

          <div class="d-flex gap-2 mt-4">
            <button type="submit" class="btn btn-primary">حفظ</button>
            <a href="{{ route('featured-ads-configs.index') }}" class="btn btn-outline-secondary">إلغاء</a>
          </div>
        </form>
      </div>
    </div>
  </div>
@endsection
