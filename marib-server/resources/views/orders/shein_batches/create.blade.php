@extends('layouts.main')

@section('title', __('إنشاء دفعة شي إن'))

@section('content')
<div class="container-fluid">
    <div class="row justify-content-center">
        <div class="col-lg-8 col-md-10">
            <div class="card">
                <div class="card-header">
                    <h4 class="card-title mb-0">{{ __('إنشاء دفعة جديدة لطلبات شي إن') }}</h4>
                </div>
                <form action="{{ route('item.shein.batches.store') }}" method="POST">
                    @csrf
                    <div class="card-body">
                        <div class="form-group">
                            <label for="reference">{{ __('المرجع') }}</label>
                            <input type="text" id="reference" name="reference" class="form-control" value="{{ old('reference') }}" required>
                        </div>
                        <div class="form-group">
                            <label for="batch_date">{{ __('تاريخ الدفعة') }}</label>
                            <input type="date" id="batch_date" name="batch_date" class="form-control" value="{{ old('batch_date') }}">
                        </div>
                        <div class="form-group">
                            <label for="status">{{ __('الحالة') }}</label>
                            <select id="status" name="status" class="form-control">
                                @foreach($statuses as $status)
                                    <option value="{{ $status }}" {{ old('status') === $status ? 'selected' : '' }}>{{ __($status) }}</option>
                                @endforeach
                            </select>
                        </div>
                        <div class="form-group">
                            <label for="deposit_amount">{{ __('قيمة الوديعة') }}</label>
                            <input type="number" step="0.01" min="0" id="deposit_amount" name="deposit_amount" class="form-control" value="{{ old('deposit_amount', 0) }}">
                        </div>
                        <div class="form-group">
                            <label for="outstanding_amount">{{ __('البواقي المتوقعة') }}</label>
                            <input type="number" step="0.01" id="outstanding_amount" name="outstanding_amount" class="form-control" value="{{ old('outstanding_amount', 0) }}">
                        </div>
                        <div class="form-group">
                            <label for="notes">{{ __('ملاحظات') }}</label>
                            <textarea id="notes" name="notes" rows="3" class="form-control">{{ old('notes') }}</textarea>
                        </div>
                        <div class="form-group">
                            <label for="closed_at">{{ __('تاريخ الإغلاق (اختياري)') }}</label>
                            <input type="datetime-local" id="closed_at" name="closed_at" class="form-control" value="{{ old('closed_at') }}">
                        </div>
                    </div>
                    <div class="card-footer d-flex justify-content-between align-items-center">
                        <a href="{{ route('item.shein.batches.index') }}" class="btn btn-outline-secondary">{{ __('إلغاء') }}</a>
                        <button type="submit" class="btn btn-primary">{{ __('حفظ الدفعة') }}</button>
                    </div>
                </form>
            </div>
        </div>
    </div>
</div>
@endsection