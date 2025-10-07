@extends('layouts.main')

@section('title', 'إنشاء طلب جديد')

@section('content')
<div class="container-fluid">
    <div class="row">
        <div class="col-md-12 mb-3">
            <div class="d-flex justify-content-between align-items-center">
                <h2>إنشاء طلب جديد</h2>
                <div>
                    <a href="{{ route('orders.index') }}" class="btn btn-secondary">
                        <i class="fa fa-arrow-right"></i> العودة للقائمة
                    </a>
                </div>
            </div>
        </div>
    </div>

    <form action="{{ route('orders.store') }}" method="POST" id="orderForm">
        @csrf
        <div class="row">
            <!-- معلومات الطلب الأساسية -->
            <div class="col-md-6">
                <div class="card">
                    <div class="card-header">
                        <h4 class="card-title">معلومات الطلب الأساسية</h4>
                    </div>
                    <div class="card-body">
                        <div class="form-group">
                            <label for="user_id">العميل</label>
                            <select class="form-control select2" id="user_id" name="user_id" required>
                                <option value="">اختر العميل</option>
                                @foreach($users as $user)
                                    <option value="{{ $user->id }}" {{ old('user_id') == $user->id ? 'selected' : '' }}>
                                        {{ $user->name }} ({{ $user->mobile ?? 'بدون رقم' }})
                                    </option>
                                @endforeach
                            </select>
                            @error('user_id')
                                <span class="text-danger">{{ $message }}</span>
                            @enderror
                        </div>

                        <div class="form-group">
                            <label for="seller_id">التاجر</label>
                            <select class="form-control select2" id="seller_id" name="seller_id">
                                <option value="">اختر التاجر (اختياري)</option>
                                @foreach($sellers as $seller)
                                    <option value="{{ $seller->id }}" {{ old('seller_id') == $seller->id ? 'selected' : '' }}>
                                        {{ $seller->name }} ({{ $seller->mobile ?? 'بدون رقم' }})
                                    </option>
                                @endforeach
                            </select>
                            @error('seller_id')
                                <span class="text-danger">{{ $message }}</span>
                            @enderror
                        </div>

                        <div class="form-group">
                            <label for="payment_method">طريقة الدفع</label>
                            <select class="form-control" id="payment_method" name="payment_method">
                                <option value="">اختر طريقة الدفع</option>
                                @foreach($paymentMethods as $value => $label)
                                    <option value="{{ $value }}" {{ old('payment_method') == $value ? 'selected' : '' }}>{{ $label }}</option>
                                @endforeach
                            </select>
                            @error('payment_method')
                                <span class="text-danger">{{ $message }}</span>
                            @enderror
                        </div>

                        <div class="form-group">
                            <label for="shipping_address">عنوان الشحن</label>
                            <textarea class="form-control" id="shipping_address" name="shipping_address" rows="3">{{ old('shipping_address') }}</textarea>
                            @error('shipping_address')
                                <span class="text-danger">{{ $message }}</span>
                            @enderror
                        </div>

                        <div class="form-group">
                            <label for="billing_address">عنوان الفواتير</label>
                            <textarea class="form-control" id="billing_address" name="billing_address" rows="3">{{ old('billing_address') }}</textarea>
                            @error('billing_address')
                                <span class="text-danger">{{ $message }}</span>
                            @enderror
                        </div>

                        <div class="form-group">
                            <label for="notes">ملاحظات</label>
                            <textarea class="form-control" id="notes" name="notes" rows="3">{{ old('notes') }}</textarea>
                            @error('notes')
                                <span class="text-danger">{{ $message }}</span>
                            @enderror
                        </div>
                    </div>
                </div>
            </div>

            <!-- عناصر الطلب -->
            <div class="col-md-6">
                <div class="card">
                    <div class="card-header">
                        <h4 class="card-title">عناصر الطلب</h4>
                    </div>
                    <div class="card-body">
                        <div class="mb-3">
                            <button type="button" class="btn btn-success" id="addItemBtn">
                                <i class="fa fa-plus"></i> إضافة عنصر
                            </button>
                        </div>

                        <div id="itemsContainer">
                            <!-- سيتم إضافة العناصر هنا بواسطة JavaScript -->
                            @if(old('items'))
                                @foreach(old('items') as $index => $item)
                                    <div class="card mb-3 item-card">
                                        <div class="card-body">
                                            <div class="d-flex justify-content-between align-items-center mb-2">
                                                <h5 class="card-title">عنصر #<span class="item-number">{{ $index + 1 }}</span></h5>
                                                <button type="button" class="btn btn-sm btn-danger remove-item">
                                                    <i class="fa fa-times"></i>
                                                </button>
                                            </div>
                                            <div class="form-group">
                                                <label>المنتج</label>
                                                <select class="form-control item-select" name="items[{{ $index }}][item_id]" required>
                                                    <option value="">اختر المنتج</option>
                                                    <!-- سيتم تحميل المنتجات بواسطة Ajax -->
                                                </select>
                                                @error("items.{$index}.item_id")
                                                    <span class="text-danger">{{ $message }}</span>
                                                @enderror
                                            </div>
                                            <div class="row">
                                                <div class="col-md-4">
                                                    <div class="form-group">
                                                        <label>السعر</label>
                                                        <input type="number" class="form-control item-price" name="items[{{ $index }}][price]" step="0.01" min="0" value="{{ $item['price'] ?? '' }}" required>
                                                        @error("items.{$index}.price")
                                                            <span class="text-danger">{{ $message }}</span>
                                                        @enderror
                                                    </div>
                                                </div>
                                                <div class="col-md-4">
                                                    <div class="form-group">
                                                        <label>الكمية</label>
                                                        <input type="number" class="form-control item-quantity" name="items[{{ $index }}][quantity]" min="1" value="{{ $item['quantity'] ?? 1 }}" required>
                                                        @error("items.{$index}.quantity")
                                                            <span class="text-danger">{{ $message }}</span>
                                                        @enderror
                                                    </div>
                                                </div>
                                                <div class="col-md-4">
                                                    <div class="form-group">
                                                        <label>المجموع</label>
                                                        <input type="text" class="form-control item-subtotal" value="{{ ($item['price'] ?? 0) * ($item['quantity'] ?? 1) }}" readonly>
                                                    </div>
                                                </div>
                                            </div>
                                            <div class="form-group">
                                                <label>خيارات إضافية</label>
                                                <textarea class="form-control" name="items[{{ $index }}][options]" rows="2">{{ $item['options'] ?? '' }}</textarea>
                                            </div>
                                        </div>
                                    </div>
                                @endforeach
                            @endif
                        </div>

                        <div class="alert alert-warning {{ old('items') ? 'd-none' : '' }}" id="noItemsAlert">
                            لم تتم إضافة أي عناصر بعد. يرجى النقر على زر "إضافة عنصر" لإضافة عناصر للطلب.
                        </div>

                        <div class="card">
                            <div class="card-body">
                                <div class="row">
                                    <div class="col-md-6">
                                        <h5>ملخص الطلب</h5>
                                    </div>
                                    <div class="col-md-6">
                                        <table class="table table-sm">
                                            <tr>
                                                <th>المجموع:</th>
                                                <td><span id="totalAmount">0.00</span> ريال</td>
                                            </tr>
                                            <tr>
                                                <th>الضريبة (15%):</th>
                                                <td><span id="taxAmount">0.00</span> ريال</td>
                                            </tr>
                                            <tr>
                                                <th>المجموع النهائي:</th>
                                                <td><strong><span id="finalAmount">0.00</span> ريال</strong></td>
                                            </tr>
                                        </table>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <div class="row mt-4">
            <div class="col-md-12">
                <div class="card">
                    <div class="card-body">
                        <div class="d-flex justify-content-center">
                            <button type="submit" class="btn btn-primary btn-lg">
                                <i class="fa fa-save"></i> حفظ الطلب
                            </button>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </form>
</div>

<!-- قالب العنصر -->
<template id="itemTemplate">
    <div class="card mb-3 item-card">
        <div class="card-body">
            <div class="d-flex justify-content-between align-items-center mb-2">
                <h5 class="card-title">عنصر #<span class="item-number">__INDEX__</span></h5>
                <button type="button" class="btn btn-sm btn-danger remove-item">
                    <i class="fa fa-times"></i>
                </button>
            </div>
            <div class="form-group">
                <label>المنتج</label>
                <select class="form-control item-select" name="items[__INDEX__][item_id]" required>
                    <option value="">اختر المنتج</option>
                    <!-- سيتم تحميل المنتجات بواسطة Ajax -->
                </select>
            </div>
            <div class="row">
                <div class="col-md-4">
                    <div class="form-group">
                        <label>السعر</label>
                        <input type="number" class="form-control item-price" name="items[__INDEX__][price]" step="0.01" min="0" required>
                    </div>
                </div>
                <div class="col-md-4">
                    <div class="form-group">
                        <label>الكمية</label>
                        <input type="number" class="form-control item-quantity" name="items[__INDEX__][quantity]" min="1" value="1" required>
                    </div>
                </div>
                <div class="col-md-4">
                    <div class="form-group">
                        <label>المجموع</label>
                        <input type="text" class="form-control item-subtotal" readonly>
                    </div>
                </div>
            </div>
            <div class="form-group">
                <label>خيارات إضافية</label>
                <textarea class="form-control" name="items[__INDEX__][options]" rows="2"></textarea>
            </div>
        </div>
    </div>
</template>
@endsection

@section('scripts')
<script>
    $(function () {
        // تفعيل Select2 للقوائم المنسدلة
        $('.select2').select2();

        // متغير لتخزين عدد العناصر
        let itemCount = $('.item-card').length;

        // إضافة عنصر جديد
        $('#addItemBtn').on('click', function() {
            // الحصول على قالب العنصر
            const template = $('#itemTemplate').html();
            
            // استبدال __INDEX__ بالعدد الحالي
            const newItem = template.replace(/__INDEX__/g, itemCount);
            
            // إضافة العنصر إلى الحاوية
            $('#itemsContainer').append(newItem);
            
            // تفعيل Select2 للعنصر الجديد
            $(`select[name="items[${itemCount}][item_id]"]`).select2({
                ajax: {
                    url: '/api/items/search',
                    dataType: 'json',
                    delay: 250,
                    data: function(params) {
                        return {
                            q: params.term
                        };
                    },
                    processResults: function(data) {
                        return {
                            results: data.map(function(item) {
                                return {
                                    id: item.id,
                                    text: item.name,
                                    price: item.price
                                };
                            })
                        };
                    },
                    cache: true
                },
                minimumInputLength: 2
            }).on('select2:select', function(e) {
                // تعيين السعر عند اختيار المنتج
                const price = e.params.data.price;
                const $row = $(this).closest('.item-card');
                $row.find('.item-price').val(price).trigger('change');
            });
            
            // زيادة العداد
            itemCount++;
            
            // إخفاء تنبيه عدم وجود عناصر
            $('#noItemsAlert').addClass('d-none');
            
            // إعادة ترقيم العناصر
            updateItemNumbers();
            
            // تحديث المجموع
            calculateTotals();
        });

        // حذف عنصر
        $(document).on('click', '.remove-item', function() {
            $(this).closest('.item-card').remove();
            
            // تحديث العداد
            itemCount = $('.item-card').length;
            
            // إظهار تنبيه عدم وجود عناصر إذا لم يكن هناك عناصر
            if (itemCount === 0) {
                $('#noItemsAlert').removeClass('d-none');
            }
            
            // إعادة ترقيم العناصر
            updateItemNumbers();
            
            // تحديث المجموع
            calculateTotals();
        });

        // حساب المجموع الفرعي عند تغيير السعر أو الكمية
        $(document).on('change keyup', '.item-price, .item-quantity', function() {
            const $row = $(this).closest('.item-card');
            const price = parseFloat($row.find('.item-price').val()) || 0;
            const quantity = parseInt($row.find('.item-quantity').val()) || 0;
            const subtotal = price * quantity;
            
            $row.find('.item-subtotal').val(subtotal.toFixed(2));
            
            // تحديث المجموع
            calculateTotals();
        });

        // إعادة ترقيم العناصر
        function updateItemNumbers() {
            $('.item-card').each(function(index) {
                $(this).find('.item-number').text(index + 1);
                
                // تحديث أسماء الحقول
                $(this).find('select.item-select').attr('name', `items[${index}][item_id]`);
                $(this).find('input.item-price').attr('name', `items[${index}][price]`);
                $(this).find('input.item-quantity').attr('name', `items[${index}][quantity]`);
                $(this).find('textarea').attr('name', `items[${index}][options]`);
            });
        }

        // حساب المجاميع
        function calculateTotals() {
            let total = 0;
            
            $('.item-subtotal').each(function() {
                total += parseFloat($(this).val()) || 0;
            });
            
            const tax = total * 0.15;
            const final = total + tax;
            
            $('#totalAmount').text(total.toFixed(2));
            $('#taxAmount').text(tax.toFixed(2));
            $('#finalAmount').text(final.toFixed(2));
        }

        // تفعيل Select2 للعناصر الموجودة
        $('.item-select').each(function(index) {
            $(this).select2({
                ajax: {
                    url: '/api/items/search',
                    dataType: 'json',
                    delay: 250,
                    data: function(params) {
                        return {
                            q: params.term
                        };
                    },
                    processResults: function(data) {
                        return {
                            results: data.map(function(item) {
                                return {
                                    id: item.id,
                                    text: item.name,
                                    price: item.price
                                };
                            })
                        };
                    },
                    cache: true
                },
                minimumInputLength: 2
            }).on('select2:select', function(e) {
                // تعيين السعر عند اختيار المنتج
                const price = e.params.data.price;
                const $row = $(this).closest('.item-card');
                $row.find('.item-price').val(price).trigger('change');
            });
        });

        // حساب المجاميع عند تحميل الصفحة
        calculateTotals();
    });
</script>
@endsection 