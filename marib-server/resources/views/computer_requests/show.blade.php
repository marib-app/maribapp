@extends('layouts.app')

@section('title', $titles['detail'])

@section('content')
<section class="section">
    <div class="dashboard_title mb-3">{{ $titles['detail'] }}</div>

    <div class="row">
        <div class="col-md-12 mb-3">
            <div class="d-flex justify-content-end">
                <a href="{{ route($routes['index']) }}" class="btn btn-primary">
                    <i class="fa fa-list"></i> العودة إلى القائمة
                </a>
            </div>
        </div>
    </div>

    <div class="row">
        <div class="col-md-8">
            <div class="card">
                <div class="card-header border-0 pb-0">
                    <h3 style="font-weight: 600">معلومات الطلب</h3>
                </div>
                <div class="card-body">
                    <div class="table-responsive">
                        <table class="table table-bordered">
                            <tbody>
                                <tr>
                                    <th style="width: 200px; background-color: #f8f9fa;">رقم الطلب</th>
                                    <td>{{ $request->id }}</td>
                                </tr>
                                <tr>
                                    <th style="background-color: #f8f9fa;">رقم الهاتف</th>
                                    <td>{{ $request->phone }}</td>
                                </tr>
                                <tr>
                                    <th style="background-color: #f8f9fa;">الموضوع</th>
                                    <td>{{ $request->subject }}</td>
                                </tr>
                                <tr>
                                    <th style="background-color: #f8f9fa;">الرسالة</th>
                                    <td>{{ $request->message }}</td>
                                </tr>
                                <tr>
                                    <th style="background-color: #f8f9fa;">تاريخ الإنشاء</th>
                                    <td>{{ $request->created_at->format('Y-m-d H:i') }}</td>
                                </tr>
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>
        </div>

        <div class="col-md-4">
            <div class="card">
                <div class="card-header border-0 pb-0">
                    <h3 style="font-weight: 600">الصورة المرفقة</h3>
                </div>
                <div class="card-body">
                    @if($request->image)
                        <div class="text-center">
                            <img src="{{ asset('storage/' . $request->image) }}" alt="صورة الطلب" class="img-fluid" style="max-height: 300px;">
                            <div class="mt-3">
                                <a href="{{ asset('storage/' . $request->image) }}" class="btn btn-info" target="_blank">
                                    <i class="fa fa-eye"></i> عرض الصورة
                                </a>
                                <a href="{{ asset('storage/' . $request->image) }}" class="btn btn-success" download>
                                    <i class="fa fa-download"></i> تحميل الصورة
                                </a>
                            </div>
                        </div>
                    @else
                        <div class="text-center text-muted">
                            <i class="fa fa-image fa-4x mb-3"></i>
                            <p>لا توجد صورة مرفقة مع هذا الطلب</p>
                        </div>
                    @endif
                </div>
            </div>

            <div class="card mt-3">
                <div class="card-header border-0 pb-0">
                    <h3 style="font-weight: 600">إجراءات</h3>
                </div>
                <div class="card-body">
                    <form action="{{ route($routes['destroy'], $request->id) }}" method="POST" onsubmit="return confirm('هل أنت متأكد من حذف هذا الطلب؟');">
                        @csrf
                        @method('DELETE')
                        <button type="submit" class="btn btn-danger btn-block w-100">
                            <i class="fa fa-trash"></i> حذف الطلب
                        </button>
                    </form>
                </div>
            </div>
        </div>
    </div>
</section>
@endsection 