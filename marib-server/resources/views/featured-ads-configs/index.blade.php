@extends('layouts.app')

@section('title', 'الإعلانات المميزة')

@section('content')
  <div class="container-fluid">
    <div class="d-flex align-items-center justify-content-between mb-3">
      <h5 class="mb-0">الإعلانات المميزة</h5>
      <a href="{{ route('featured-ads-configs.create') }}" class="btn btn-primary">
        <i class="bi bi-plus-circle me-1"></i> إضافة إعداد
      </a>
    </div>

    @if(session('success'))
      <div class="alert alert-success">{{ session('success') }}</div>
    @endif

    <div class="card">
      <div class="card-body table-responsive">
        <table class="table table-striped align-middle">
          <thead>
          <tr>
            <th>#</th>
            <th>الاسم</th>
            <th>القسم</th>
            <th>الواجهة</th>
            <th>ستايل</th>
            <th>نمط الترتيب</th>
            <th>مفعل</th>
            <th>شريط إعلاني</th>
            <th>ترتيب</th>
            <th></th>
          </tr>
          </thead>
          <tbody>
          @forelse($configs as $config)
            <tr>
              <td>{{ $config->id }}</td>
              <td>{{ $config->name ?? '-' }}</td>
              <td>{{ $config->root_category_id }}</td>
              <td>{{ $config->interface_type ?? '-' }}</td>
              <td>{{ $config->style_key ?? '-' }}</td>
              <td>{{ $config->order_mode ?? '-' }}</td>
              <td>
                <span class="badge bg-{{ $config->enabled ? 'success' : 'secondary' }}">
                  {{ $config->enabled ? 'مفعل' : 'معطل' }}
                </span>
              </td>
              <td>
                <span class="badge bg-{{ $config->enable_ad_slider ? 'info' : 'secondary' }}">
                  {{ $config->enable_ad_slider ? 'مفعل' : 'معطل' }}
                </span>
              </td>
              <td>{{ $config->position ?? 0 }}</td>
              <td class="text-end">
                <a href="{{ route('featured-ads-configs.edit', $config) }}" class="btn btn-sm btn-outline-primary">
                  تعديل
                </a>
                <form action="{{ route('featured-ads-configs.destroy', $config) }}" method="POST" class="d-inline"
                      onsubmit="return confirm('تأكيد الحذف؟');">
                  @csrf
                  @method('DELETE')
                  <button type="submit" class="btn btn-sm btn-outline-danger">حذف</button>
                </form>
              </td>
            </tr>
          @empty
            <tr>
              <td colspan="10" class="text-center text-muted">لا توجد إعدادات بعد</td>
            </tr>
          @endforelse
          </tbody>
        </table>
      </div>
    </div>
  </div>
@endsection
