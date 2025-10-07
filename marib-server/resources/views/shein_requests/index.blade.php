@extends('layouts.app')

@section('title', $titles['index'])

@section('content')
<section class="section">
    <div class="dashboard_title mb-3">{{ $titles['index'] }}</div>

    <div class="row mt-4">
        <div class="col-md-12">
            <div class="card">
                <div class="card-header border-0 pb-0">
                    <h3 style="font-weight: 600">إحصائيات طلبات شي إن الخاصة</h3>
                </div>
                <div class="card-body">
                    <div class="row">
                        <div class="col-md-4 col-sm-6 mb-3">
                            <div class="card h-100">
                                <div class="total_customer d-flex">
                                    <div class="curtain"></div>
                                    <div class="row">
                                        <div class="col-4 col-md-12">
                                            <div class="svg_icon align-items-center d-flex justify-content-center me-3">
                                                <span class="fas fa-store text-white fa-2x"></span>
                                            </div>
                                        </div>
                                        <div class="col-8 col-md-12">
                                            <div class="total_number">{{ $stats['total'] }}</div>
                                            <div class="card_title">إجمالي الطلبات</div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>

                        <div class="col-md-4 col-sm-6 mb-3">
                            <div class="card h-100">
                                <div class="total_items d-flex">
                                    <div class="curtain"></div>
                                    <div class="row">
                                        <div class="col-4 col-md-12">
                                            <div class="svg_icon align-items-center d-flex justify-content-center me-3">
                                                <span class="fas fa-calendar-day text-white fa-2x"></span>
                                            </div>
                                        </div>
                                        <div class="col-8 col-md-12">
                                            <div class="total_number">{{ $stats['today'] }}</div>
                                            <div class="card_title">طلبات اليوم</div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>

                        <div class="col-md-4 col-sm-6 mb-3">
                            <div class="card h-100">
                                <div class="item_for_sale d-flex">
                                    <div class="curtain"></div>
                                    <div class="row">
                                        <div class="col-4 col-md-12">
                                            <div class="svg_icon align-items-center d-flex justify-content-center me-3">
                                                <span class="fas fa-calendar-week text-white fa-2x"></span>
                                            </div>
                                        </div>
                                        <div class="col-8 col-md-12">
                                            <div class="total_number">{{ $stats['week'] }}</div>
                                            <div class="card_title">طلبات هذا الأسبوع</div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <div class="row mb-4">
        <div class="col-md-12">
            <div class="card">
                <div class="card-header border-0 pb-0">
                    <h3 style="font-weight: 600">بحث في طلبات شي إن الخاصة</h3>
                </div>
                <div class="card-body">
                    <form action="{{ route($routes['index']) }}" method="GET">
                        <div class="row">
                            <div class="col-md-5">
                                <div class="form-group">
                                    <label for="phone">رقم الهاتف</label>
                                    <input type="text" class="form-control" id="phone" name="phone" value="{{ request('phone') }}" placeholder="ابحث برقم الهاتف">
                                </div>
                            </div>
                            <div class="col-md-5">
                                <div class="form-group">
                                    <label for="subject">الموضوع</label>
                                    <input type="text" class="form-control" id="subject" name="subject" value="{{ request('subject') }}" placeholder="ابحث بالموضوع">
                                </div>
                            </div>
                            <div class="col-md-2 d-flex align-items-end">
                                <div class="form-group w-100">
                                    <button type="submit" class="btn btn-primary w-100">
                                        <i class="fa fa-search"></i> بحث
                                    </button>
                                </div>
                            </div>
                        </div>

                    </form>
                </div>
            </div>
        </div>
    </div>

    <div class="row">
        <div class="col-md-12">
            <div class="card">
                <div class="card-header border-0 pb-0">
                    <h3 style="font-weight: 600">قائمة طلبات شي إن الخاصة</h3>
                </div>
                <div class="card-body">
                    <div class="table-responsive">
                        <table class="table table-bordered table-hover table-striped" aria-describedby="mydesc">
                            <thead class="table-dark">
                                <tr>
                                    <th style="width: 5%;">#</th>
                                    <th style="width: 20%;">رقم الهاتف</th>
                                    <th style="width: 40%;">الموضوع</th>
                                    <th style="width: 15%;">تاريخ الإنشاء</th>
                                    <th style="width: 20%;">الإجراءات</th>
                                </tr>
                            </thead>
                            <tbody>
                                @forelse($requests as $index => $request)
                                    <tr>
                                        <td>{{ $requests->firstItem() + $index }}</td>
                                        <td>{{ $request->phone }}</td>
                                        <td>{{ $request->subject }}</td>
                                        <td>{{ $request->created_at->format('Y-m-d H:i') }}</td>
                                        <td>
                                            <div class="d-flex justify-content-center">
                                                <a href="{{ route($routes['show'], $request->id) }}" class="btn btn-sm btn-info me-2">
                                                    <i class="fa fa-eye"></i> عرض
                                                </a>
                                                <form action="{{ route($routes['destroy'], $request->id) }}" method="POST" onsubmit="return confirm('هل أنت متأكد من حذف هذا الطلب؟');">
                                                    @csrf
                                                    @method('DELETE')
                                                    <button type="submit" class="btn btn-sm btn-danger">
                                                        <i class="fa fa-trash"></i> حذف
                                                    </button>
                                                </form>
                                            </div>
                                        </td>
                                    </tr>
                                @empty
                                    <tr>
                                        <td colspan="5" class="text-center">لا توجد طلبات للعرض</td>
                                    </tr>
                                @endforelse
                            </tbody>
                        </table>
                    </div>
                </div>
                <div class="card-footer">
                    <div class="d-flex justify-content-center">
                        {{ $requests->links() }}
                    </div>
                </div>
            </div>
        </div>
    </div>

</section>
@endsection
