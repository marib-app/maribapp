<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
    <meta charset="utf-8">
    <title>فاتورة {{ $order->invoice_no ?? $order->order_number ?? '' }}</title>
    <style>
        @page {
            margin: 35px 30px 70px 30px;
        }

        @font-face {
            font-family: 'InvoiceArabic';
            src: url("file://{{ storage_path('fonts/DejaVuSans.ttf') }}") format('truetype');
            font-weight: normal;
            font-style: normal;
        }

        @font-face {
            font-family: 'InvoiceArabic';
            src: url("file://{{ storage_path('fonts/DejaVuSans-Bold.ttf') }}") format('truetype');
            font-weight: bold;
            font-style: normal;
        }

        * {
            box-sizing: border-box;
        }

        body {
            font-family: 'InvoiceArabic', 'DejaVu Sans', sans-serif;
            direction: rtl;
            text-align: right;
            color: #1f2933;
            font-size: 13px;
            line-height: 1.6;
            margin: 0;
            padding: 0;
            background-color: #ffffff;
        }

        h1,
        h2,
        h3,
        h4,
        h5 {
            font-weight: bold;
            margin: 0;
        }

        .container {
            width: 100%;
            padding: 10px 0 0;
        }

        .header,
        .details,
        .items,
        .summary,
        .footer {
            width: 100%;
            margin-bottom: 18px;
        }

        .header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            gap: 20px;
        }

        .logo img {
            max-height: 80px;
            max-width: 220px;
            object-fit: contain;
        }

        .company-info {
            text-align: right;
        }

        .company-info h2 {
            margin-bottom: 6px;
            font-size: 20px;
            color: #0f172a;
        }

        .company-info p {
            margin: 0;
            color: #4b5563;
        }

        .invoice-badge {
            display: inline-block;
            padding: 6px 16px;
            border-radius: 9999px;
            font-size: 13px;
            background-color: #1d4ed8;
            color: #ffffff;
            margin-bottom: 8px;
        }

        .meta-grid {
            display: flex;
            flex-wrap: wrap;
            gap: 16px;
        }

        .meta-card {
            flex: 1 1 45%;
            background-color: #f8fafc;
            padding: 14px 16px;
            border-radius: 10px;
            border: 1px solid #e2e8f0;
        }

        .meta-card h3 {
            font-size: 15px;
            margin-bottom: 8px;
            color: #0f172a;
        }

        .meta-card p {
            margin: 2px 0;
            color: #475569;
        }

        table {
            width: 100%;
            border-collapse: collapse;
        }

        th,
        td {
            border: 1px solid #d1d5db;
            padding: 10px 12px;
            vertical-align: middle;
        }

        th {
            background-color: #e2e8f0;
            font-weight: bold;
            color: #0f172a;
        }

        .totals-table {
            width: 50%;
            margin-left: auto;
            border: none;
        }

        .totals-table td {
            border: none;
            padding: 6px 0;
        }

        .totals-table tr td:first-child {
            color: #4b5563;
        }

        .totals-table tr.total td {
            font-size: 18px;
            font-weight: bold;
            color: #0f172a;
            padding-top: 10px;
        }

        .badge {
            display: inline-block;
            padding: 4px 10px;
            border-radius: 9999px;
            background-color: #fef3c7;
            color: #92400e;
            font-size: 12px;
            margin-right: 6px;
        }

        .notes {
            background-color: #f8fafc;
            border: 1px solid #e2e8f0;
            border-radius: 10px;
            padding: 12px 16px;
            margin-top: 12px;
        }

        .footer {
            text-align: center;
            border-top: 1px solid #e2e8f0;
            padding-top: 12px;
            font-size: 11px;
            color: #6b7280;
        }
    </style>
</head>
<body>
    @php
        $formatCurrency = fn (float $amount): string => trim(sprintf('%s %s', $currency, number_format($amount, 2)));
    @endphp

    <div class="container">
        <header class="header">
            <div class="logo">
                @if (! empty($company['logo']))
                    <img src="{{ $company['logo'] }}" alt="{{ $company['name'] }}">
                @endif
            </div>
            <div class="company-info">
                <span class="invoice-badge">فاتورة مبيعات</span>
                <h2>{{ $company['name'] }}</h2>
                @if (! empty($company['address']))
                    <p>{!! nl2br(e($company['address'])) !!}</p>
                @endif
                <p>
                    @if (! empty($company['phone']))
                        <span class="badge">الهاتف: {{ $company['phone'] }}</span>
                    @endif
                    @if (! empty($company['email']))
                        <span class="badge">البريد: {{ $company['email'] }}</span>
                    @endif
                    @if (! empty($company['tax_id']))
                        <span class="badge">الرقم الضريبي: {{ $company['tax_id'] }}</span>
                    @endif
                </p>
            </div>
        </header>

        <section class="details">
            <div class="meta-grid">
                <div class="meta-card">
                    <h3>معلومات الفاتورة</h3>
                    <p>رقم الفاتورة: {{ $invoice_number }}</p>
                    <p>رقم الطلب: {{ $order->order_number }}</p>
                    <p>تاريخ الإصدار: {{ optional($issued_at)->translatedFormat('d F Y') }}</p>
                    <p>تاريخ الطباعة: {{ $generated_at->translatedFormat('d F Y') }}</p>
                    <p>طريقة الدفع: {{ $payment['method'] ?? 'غير محدد' }}</p>
                    <p>حالة الدفع: {{ $payment['status'] ?? 'غير محدد' }}</p>
                </div>
                <div class="meta-card">
                    <h3>بيانات العميل</h3>
                    <p>الاسم: {{ optional($customer)->name ?? 'عميل' }}</p>
                    @if (optional($customer)->mobile)
                        <p>الجوال: {{ $customer->mobile }}</p>
                    @endif
                    @if (optional($customer)->email)
                        <p>البريد الإلكتروني: {{ $customer->email }}</p>
                    @endif
                    @if (! empty($billing_address))
                        <p>عنوان الفوترة: {!! nl2br(e($billing_address)) !!}</p>
                    @endif
                    @if (! empty($shipping_address))
                        <p>عنوان التوصيل: {!! nl2br(e($shipping_address)) !!}</p>
                    @endif
                </div>
            </div>
        </section>

        <section class="items">
            <table>
                <thead>
                    <tr>
                        <th>الصنف</th>
                        <th>الكمية</th>
                        <th>سعر الوحدة</th>
                        <th>الإجمالي</th>
                    </tr>
                </thead>
                <tbody>
                    @forelse ($items as $item)
                        <tr>
                            <td>{{ $item['name'] }}</td>
                            <td>{{ $item['quantity'] }}</td>
                            <td>{{ $formatCurrency($item['unit_price']) }}</td>
                            <td>{{ $formatCurrency($item['subtotal']) }}</td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="4" style="text-align: center;">لا توجد أصناف مسجلة في هذا الطلب</td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </section>

        <section class="summary">
            <table class="totals-table">
                <tbody>
                    <tr>
                        <td>الإجمالي الفرعي</td>
                        <td>{{ $formatCurrency($summary['items_total']) }}</td>
                    </tr>
                    <tr>
                        <td>الضرائب</td>
                        <td>{{ $formatCurrency($summary['tax']) }}</td>
                    </tr>
                    <tr>
                        <td>الخصومات</td>
                        <td>{{ $formatCurrency($summary['discount']) }}</td>
                    </tr>
                    <tr>
                        <td>التوصيل</td>
                        <td>{{ $formatCurrency($summary['delivery']) }}</td>
                    </tr>
                    <tr class="total">
                        <td>المجموع النهائي</td>
                        <td>{{ $formatCurrency($summary['final']) }}</td>
                    </tr>
                </tbody>
            </table>

            @if (! empty($order->notes))
                <div class="notes">
                    <strong>ملاحظات الطلب:</strong>
                    <p>{!! nl2br(e($order->notes)) !!}</p>
                </div>
            @endif
        </section>

        @if (! empty($company['footer_note']))
            <div class="footer">
                {!! nl2br(e($company['footer_note'])) !!}
            </div>
        @endif
    </div>
</body>
</html>
