<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
    <meta charset="utf-8">
    <title>فاتورة {{ $order->invoice_no ?? $order->order_number ?? '' }}</title>
    @php
        $isPreview = !empty($preview);
        $fontRegularSource = $isPreview
            ? ($preview_assets['font_regular'] ?? 'file://' . storage_path('fonts/Almarai-Regular.ttf'))
            : 'file://' . storage_path('fonts/Almarai-Regular.ttf');
        $fontBoldSource = $isPreview
            ? ($preview_assets['font_bold'] ?? 'file://' . storage_path('fonts/Almarai-Bold.ttf'))
            : 'file://' . storage_path('fonts/Almarai-Bold.ttf');
    @endphp

    <style>
        @page {
            margin: 110px 36px 120px 36px;
        }

        @font-face {
            font-family: 'InvoiceArabic';
            src:
                url("{{ $fontRegularSource }}") format('truetype'),
                local('Tahoma');
                
                font-weight: normal;
            font-style: normal;
        }

        @font-face {
            font-family: 'InvoiceArabic';
            src:
                url("{{ $fontBoldSource }}") format('truetype'),
                local('Tahoma');
                
                font-weight: bold;
            font-style: normal;
        }

        :root {
            color-scheme: light;
            --primary: #1e3a8a;
            --primary-contrast: #ffffff;
            --slate-900: #0f172a;
            --slate-700: #334155;
            --slate-500: #64748b;
            --slate-200: #e2e8f0;
            --slate-100: #f1f5f9;
            --accent: #f97316;
        }

        * {
            box-sizing: border-box;
        }

        body {
            margin: 0;
            font-family: 'InvoiceArabic', 'Almarai', 'Tahoma', 'Segoe UI', sans-serif;
            direction: rtl;
            text-align: right;
            background-color: #ffffff;
            color: var(--slate-900);
            font-size: 13px;
            line-height: 1.7;
        }

        body.invoice-preview {
            background-color: #f1f5f9;
            padding: 56px 0 96px;
        }

        .preview-container {
            max-width: 960px;
            margin: 0 auto;
            padding: 0 20px;
        }

        .preview-toolbar {
            display: flex;
            align-items: center;
            justify-content: space-between;
            gap: 16px;
            background: #ffffff;
            border-radius: 18px;
            padding: 18px 24px;
            box-shadow: 0 18px 45px rgba(15, 23, 42, 0.12);
            margin-bottom: 28px;
        }

        .preview-toolbar h1 {
            font-size: 18px;
            color: var(--slate-900);
        }

        .preview-toolbar span {
            display: block;
            color: var(--slate-500);
            font-size: 12px;
            margin-top: 4px;
        }

        .preview-actions {
            display: flex;
            align-items: center;
            gap: 12px;
        }

        .preview-actions a,
        .preview-actions button {
            border: none;
            border-radius: 12px;
            padding: 10px 18px;
            cursor: pointer;
            font-family: inherit;
            font-size: 13px;
            font-weight: 600;
            transition: transform 0.15s ease, box-shadow 0.15s ease;
        }

        .preview-actions button {
            background: linear-gradient(120deg, var(--primary), #2563eb);
            color: var(--primary-contrast);
            box-shadow: 0 12px 24px rgba(37, 99, 235, 0.2);
        }

        .preview-actions a {
            background: rgba(30, 58, 138, 0.08);
            color: var(--primary);
        }

        .preview-actions a:hover,
        .preview-actions button:hover {
            transform: translateY(-1px);
            box-shadow: 0 14px 30px rgba(15, 23, 42, 0.18);
        }

        .preview-page {
            position: relative;
            background: #ffffff;
            border-radius: 26px;
            box-shadow: 0 28px 70px rgba(15, 23, 42, 0.18);
            padding: 120px 36px 140px 36px;
        }




        h1,
        h2,
        h3,
        h4,
        h5,
        h6 {
            margin: 0;
            font-weight: bold;
        }

        header.invoice-header,
        footer.invoice-footer {
            position: fixed;
            left: 36px;
            right: 36px;
        }

        header.invoice-header {
            top: -80px;
        }

        footer.invoice-footer {
            bottom: -90px;
        }


        body.invoice-preview header.invoice-header,
        body.invoice-preview footer.invoice-footer {
            position: static;
            left: auto;
            right: auto;
        }

        body.invoice-preview header.invoice-header {
            margin-bottom: 28px;
        }

        body.invoice-preview footer.invoice-footer {
            margin-top: 32px;
        }

        body.invoice-preview main {
            margin: 0;
        }


        .header-shell,
        .footer-shell {
            border-radius: 20px;
            border: 1px solid rgba(148, 163, 184, 0.35);
            background-color: #ffffff;
            padding: 20px 28px;
            box-shadow: 0 12px 24px rgba(15, 23, 42, 0.06);
        }

        .header-shell {
            display: flex;
            align-items: stretch;
            justify-content: space-between;
            gap: 24px;
        }

        .brand-column {
            display: flex;
            align-items: center;
            gap: 18px;
        }

        .logo-wrapper {
            width: 82px;
            height: 82px;
            border-radius: 24px;
            display: flex;
            align-items: center;
            justify-content: center;
            overflow: hidden;
            background: linear-gradient(135deg, var(--primary), #3b82f6);
            padding: 10px;
        }

        .logo-wrapper img {
            max-width: 100%;
            max-height: 100%;
            object-fit: contain;
        }

        .logo-placeholder {
            color: var(--primary-contrast);
            font-size: 20px;
            letter-spacing: 0.6px;
        }

        .brand-details h2 {
            font-size: 24px;
            color: var(--slate-900);
            margin-bottom: 6px;
        }

        .brand-details p {
            margin: 3px 0;
            color: var(--slate-500);
            font-size: 12px;
        }

        .brand-tags {
            display: flex;
            flex-wrap: wrap;
            gap: 6px;
            margin-top: 12px;
        }

        .brand-tags span {
            display: inline-flex;
            align-items: center;
            padding: 5px 12px;
            border-radius: 999px;
            background-color: rgba(30, 58, 138, 0.1);
            color: var(--primary);
            font-size: 11px;
        }

        .invoice-column {
            display: flex;
            flex-direction: column;
            justify-content: space-between;
            text-align: left;
        }

        .invoice-title {
            display: inline-flex;
            align-items: center;
            align-self: flex-end;
            gap: 10px;
            padding: 7px 18px;
            border-radius: 999px;
            background: linear-gradient(120deg, var(--primary), #2563eb);
            color: var(--primary-contrast);
            font-size: 13px;
            margin-bottom: 18px;
        }

        .invoice-meta {
            width: 100%;
            border-radius: 16px;
            background-color: var(--slate-100);
            border: 1px solid rgba(148, 163, 184, 0.35);
            padding: 14px 18px;
        }

        .invoice-meta table {
            width: 100%;
            border-collapse: collapse;
        }

        .invoice-meta td {
            padding: 6px 0;
            font-size: 12px;
            color: var(--slate-700);
        }

        .invoice-meta td.label {
            font-weight: bold;
            color: var(--slate-900);
            min-width: 110px;
        }

        main {
            margin: 0;
        }

        .section {
            background-color: #ffffff;
            border-radius: 20px;
            border: 1px solid rgba(148, 163, 184, 0.28);
            padding: 24px 26px;
            margin-bottom: 20px;
        }

        .section-title {
            font-size: 17px;
            margin-bottom: 18px;
            position: relative;
            padding-right: 14px;
        }

        .section-title::before {
            content: '';
            position: absolute;
            right: 0;
            top: 3px;
            width: 5px;
            height: 18px;
            border-radius: 999px;
            background: linear-gradient(180deg, var(--primary), rgba(30, 58, 138, 0));
        }

        .two-col-grid {
            display: flex;
            flex-wrap: wrap;
            gap: 18px;
        }

        .info-card {
            flex: 1 1 48%;
            border-radius: 16px;
            border: 1px solid rgba(148, 163, 184, 0.26);
            padding: 18px 20px;
            background: linear-gradient(180deg, rgba(241, 245, 249, 0.8), rgba(255, 255, 255, 0.8));
        }

        .info-card h3 {
            font-size: 15px;
            color: var(--slate-900);
            margin-bottom: 12px;
        }

        .info-card p {
            margin: 5px 0;
            color: var(--slate-700);
            font-size: 12px;
        }

        .info-card p strong {
            color: var(--slate-900);
        }

        .status-chips {
            display: flex;
            flex-wrap: wrap;
            gap: 10px;
            margin-top: 16px;
        }

        .chip {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            padding: 6px 14px;
            border-radius: 999px;
            font-size: 11px;
            border: 1px solid transparent;
        }

        .chip.payment {
            background-color: rgba(16, 185, 129, 0.16);
            color: #047857;
            border-color: rgba(16, 185, 129, 0.36);
        }

        .chip.order {
            background-color: rgba(250, 204, 21, 0.22);
            color: #92400e;
            border-color: rgba(250, 204, 21, 0.45);
        }

        .chip.delivery {
            background-color: rgba(59, 130, 246, 0.15);
            color: #1d4ed8;
            border-color: rgba(59, 130, 246, 0.32);
        }

        .items-table {
            width: 100%;
            border-collapse: collapse;
            border-radius: 18px;
            overflow: hidden;
            font-size: 12px;
        }

        .items-table thead {
            background: linear-gradient(120deg, var(--primary), #1d4ed8);
            color: var(--primary-contrast);
        }

        .items-table thead th {
            padding: 14px 10px;
            font-weight: normal;
            text-align: center;
        }

        .items-table tbody tr:nth-child(even) {
            background-color: rgba(226, 232, 240, 0.35);
        }

        .items-table td {
            padding: 11px 10px;
            border: 1px solid rgba(148, 163, 184, 0.35);
            color: var(--slate-700);
        }

        .items-table td:first-child {
            text-align: right;
            font-weight: bold;
            color: var(--slate-900);
        }

        .items-table td:last-child,
        .items-table td:nth-child(3) {
            text-align: center;
            white-space: nowrap;
        }

        .empty-row {
            text-align: center;
            padding: 28px 0;
            color: var(--slate-500);
        }

        .totals-wrapper {
            display: flex;
            justify-content: flex-end;
            margin-top: 22px;
        }

        .totals-table {
            width: 52%;
            min-width: 280px;
            border-radius: 18px;
            overflow: hidden;
            border: 1px solid rgba(148, 163, 184, 0.35);
            background-color: #ffffff;
        }

        .totals-table tr td {
            padding: 11px 16px;
            font-size: 13px;
            color: var(--slate-700);
        }

        .totals-table tr td.label {
            font-weight: bold;
            color: var(--slate-900);
        }

        .totals-table tr + tr td {
            border-top: 1px solid rgba(148, 163, 184, 0.25);
        }

        .totals-table tr.grand-total td {
            background: linear-gradient(120deg, rgba(30, 58, 138, 0.1), rgba(37, 99, 235, 0.08));
            color: var(--primary);
            font-size: 15px;
            font-weight: bold;
        }

        .notes-box {
            border-radius: 18px;
            border: 1px dashed rgba(148, 163, 184, 0.55);
            background: rgba(241, 245, 249, 0.6);
            padding: 20px 22px;
            color: var(--slate-700);
            font-size: 12px;
        }

        .signatures {
            display: flex;
            gap: 18px;
            flex-wrap: wrap;
        }

        .signature-card {
            flex: 1 1 48%;
            border-radius: 16px;
            border: 1px dashed rgba(148, 163, 184, 0.5);
            padding: 18px 20px 26px;
            text-align: center;
            color: var(--slate-700);
            background: linear-gradient(180deg, rgba(255, 255, 255, 0.92), rgba(241, 245, 249, 0.6));
        }

        .signature-card strong {
            display: block;
            font-size: 13px;
            color: var(--slate-900);
            margin-bottom: 20px;
        }

        .signature-line {
            margin-top: 24px;
            border-top: 1px solid rgba(148, 163, 184, 0.6);
            padding-top: 12px;
        }

        .footer-shell {
            text-align: center;
            font-size: 11px;
            color: var(--slate-500);
        }

        .footer-divider {
            height: 1px;
            width: 100%;
            margin: 0 auto 10px;
            background: linear-gradient(90deg, rgba(15, 23, 42, 0), rgba(148, 163, 184, 0.8), rgba(15, 23, 42, 0));
        }

        .footer-brand {
            color: var(--primary);
            font-weight: bold;
            letter-spacing: 0.5px;
        }



        @media print {
            body.invoice-preview {
                background: #ffffff;
                padding: 0;
            }

            .preview-container {
                max-width: none;
                padding: 0;
            }

            .preview-toolbar {
                display: none;
            }

            .preview-page {
                box-shadow: none;
                border-radius: 0;
                padding: 110px 36px 120px 36px;
            }
        }

    </style>
</head>
<body class="{{ $isPreview ? 'invoice-preview' : '' }}">
    @php
        $formatCurrency = static fn (float $amount): string => trim(sprintf('%s %s', $currency, number_format($amount, 2)));

        $deliveryDate = null;
        if (! empty($order->delivery_date)) {
            try {
                $deliveryDate = \Illuminate\Support\Carbon::parse($order->delivery_date);
            } catch (\Throwable $exception) {
                $deliveryDate = null;
            }
        }

        $orderStatusLabel = $order->status ? __($order->status) : null;
        $deliveryMethodLabel = $order->delivery_method ? __($order->delivery_method) : null;
        $companyName = $company['name'] ?? 'فاتورة مبيعات';
        $companyLogo = $company['logo'] ?? null;

        $summaryValues = [
            'items_total' => data_get($summary, 'items_total', 0),
            'tax' => data_get($summary, 'tax', 0),
            'discount' => data_get($summary, 'discount', 0),
            'delivery' => data_get($summary, 'delivery', 0),
            'final' => data_get($summary, 'final', 0),
        ];
    @endphp

    @if ($isPreview)
        <div class="preview-container">
            <div class="preview-toolbar">
                <div>
                    <h1>فاتورة رقم {{ $invoice_number ?? $order->order_number ?? $order->getKey() }}</h1>
                    <span>
                        @if ($issued_at)
                            صادرة في {{ $issued_at->translatedFormat('d F Y') }}
                        @else
                            تم التوليد في {{ $generated_at->translatedFormat('d F Y') }}
                        @endif
                    </span>
                    <span>آخر تحديث: {{ $generated_at->translatedFormat('d F Y \، H:i') }}</span>
                </div>
                <div class="preview-actions">
                    <button type="button" data-action="print">طباعة</button>
                    @if (! empty($preview_download_url))
                        <a href="{{ $preview_download_url }}" target="_blank" rel="noopener">تحميل PDF</a>
                    @endif
                </div>
            </div>
            <div class="preview-page">
    @endif


    <header class="invoice-header">
        <div class="header-shell">
            <div class="brand-column">
                <div class="logo-wrapper">
                    @if (! empty($companyLogo))
                        <img src="{{ $companyLogo }}" alt="{{ $companyName }}">
                    @else
                        <span class="logo-placeholder">{{ mb_substr($companyName, 0, 2) }}</span>
                    @endif
                </div>
                <div class="brand-details">
                    <h2>{{ $companyName }}</h2>
                    @if (! empty($company['address']))
                        <p>{!! nl2br(e($company['address'])) !!}</p>
                    @endif
                    <div class="brand-tags">
                        @if (! empty($company['phone']))
                            <span>هاتف: {{ $company['phone'] }}</span>
                        @endif
                        @if (! empty($company['email']))
                            <span>البريد: {{ $company['email'] }}</span>
                        @endif
                        @if (! empty($company['tax_id']))
                            <span>الرقم الضريبي: {{ $company['tax_id'] }}</span>
                        @endif
                        @if (! empty($company['commercial_id']))
                            <span>السجل التجاري: {{ $company['commercial_id'] }}</span>
                        @endif
                    </div>
                </div>
            </div>
            <div class="invoice-column">
                <span class="invoice-title">فاتورة مبيعات</span>
                <div class="invoice-meta">
                    <table>
                        <tr>
                            <td class="label">رقم الفاتورة</td>
                            <td>{{ $invoice_number }}</td>
                        </tr>
                        <tr>
                            <td class="label">رقم الطلب</td>
                            <td>{{ $order->order_number }}</td>
                        </tr>
                        <tr>
                            <td class="label">تاريخ الإصدار</td>
                            <td>{{ optional($issued_at)->translatedFormat('d F Y') }}</td>
                        </tr>
                        <tr>
                            <td class="label">تاريخ الطباعة</td>
                            <td>{{ $generated_at->translatedFormat('d F Y') }}</td>
                        </tr>
                        <tr>
                            <td class="label">طريقة الدفع</td>
                            <td>{{ $payment['method'] ?? 'غير محدد' }}</td>
                        </tr>
                        <tr>
                            <td class="label">حالة الدفع</td>
                            <td>{{ $payment['status'] ?? 'غير محدد' }}</td>
                        </tr>
                    </table>
                </div>
            </div>
        </div>
    </header>

    <footer class="invoice-footer">
        <div class="footer-shell">
            <div class="footer-divider"></div>
            @if (! empty($company['footer_note']))
                <div>{!! nl2br(e($company['footer_note'])) !!}</div>
            @else
                <div class="footer-brand">{{ $companyName }}</div>
            @endif
        </div>
    </footer>

    <main>
        <section class="section">
            <h2 class="section-title">الملخص العام</h2>
            <div class="two-col-grid">
                <div class="info-card">
                    <h3>بيانات العميل</h3>
                    <p><strong>الاسم:</strong> {{ optional($customer)->name ?? 'عميل' }}</p>
                    @if (optional($customer)->mobile)
                        <p><strong>الجوال:</strong> {{ $customer->mobile }}</p>
                    @endif
                    @if (optional($customer)->email)
                        <p><strong>البريد الإلكتروني:</strong> {{ $customer->email }}</p>
                    @endif
                    @if (! empty($billing_address))
                        <p><strong>عنوان الفوترة:</strong> {!! nl2br(e($billing_address)) !!}</p>
                    @endif
                    @if (! empty($shipping_address))
                        <p><strong>عنوان التوصيل:</strong> {!! nl2br(e($shipping_address)) !!}</p>
                    @endif
                </div>
                <div class="info-card">
                    <h3>تفاصيل الطلب</h3>
                    <p><strong>معرف العميل:</strong> {{ optional($customer)->id ?? 'غير متوفر' }}</p>
                    <p><strong>مصدر الطلب:</strong> {{ __($order->source ?? 'غير محدد') }}</p>
                    <p><strong>طريقة التوصيل:</strong> {{ $deliveryMethodLabel ?? 'غير محدد' }}</p>
                    @if ($deliveryDate)
                        <p><strong>تاريخ التوصيل المتوقع:</strong> {{ $deliveryDate->translatedFormat('d F Y') }}</p>
                    @endif
                    <div class="status-chips">
                        <span class="chip payment">حالة الدفع: {{ $payment['status'] ?? 'غير محدد' }}</span>
                        @if ($orderStatusLabel)
                            <span class="chip order">حالة الطلب: {{ $orderStatusLabel }}</span>
                        @endif
                        @if ($deliveryMethodLabel)
                            <span class="chip delivery">طريقة التوصيل: {{ $deliveryMethodLabel }}</span>
                        @endif
                    </div>
                </div>
            </div>
        </section>

        <section class="section">
            <h2 class="section-title">تفاصيل الأصناف</h2>
            <table class="items-table">
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
                            <td>{{ $formatCurrency((float) $item['unit_price']) }}</td>
                            <td>{{ $formatCurrency((float) $item['subtotal']) }}</td>
                        </tr>
                    @empty
                        <tr>
                            <td class="empty-row" colspan="4">لا توجد أصناف مسجلة في هذا الطلب</td>
                        </tr>
                    @endforelse
                </tbody>
            </table>

            <div class="totals-wrapper">
                <table class="totals-table">
                    <tr>
                        <td class="label">الإجمالي الفرعي</td>
                        <td>{{ $formatCurrency((float) $summaryValues['items_total']) }}</td>
                    </tr>
                    <tr>
                        <td class="label">الضرائب</td>
                        <td>{{ $formatCurrency((float) $summaryValues['tax']) }}</td>
                    </tr>
                    <tr>
                        <td class="label">الخصومات</td>
                        <td>{{ $formatCurrency((float) $summaryValues['discount']) }}</td>
                    </tr>
                    <tr>
                        <td class="label">رسوم التوصيل</td>
                        <td>{{ $formatCurrency((float) $summaryValues['delivery']) }}</td>
                    </tr>
                    <tr class="grand-total">
                        <td class="label">المجموع النهائي</td>
                        <td>{{ $formatCurrency((float) $summaryValues['final']) }}</td>
                    </tr>
                </table>
            </div>
        </section>

        @if (! empty($order->notes))
            <section class="section">
                <h2 class="section-title">ملاحظات الطلب</h2>
                <div class="notes-box">
                    {!! nl2br(e($order->notes)) !!}
                </div>
            </section>
        @endif

        <section class="section">
            <h2 class="section-title">التوقيع والاعتماد</h2>
            <div class="signatures">
                <div class="signature-card">
                    <strong>توقيع المفوض</strong>
                    <div class="signature-line">الاسم: _____________________</div>
                </div>
                <div class="signature-card">
                    <strong>توقيع المستلم</strong>
                    <div class="signature-line">الاسم: _____________________</div>
                </div>
            </div>
        </section>
    </main>

    @if ($isPreview)
            </div>
        </div>
        <script>
            document.addEventListener('DOMContentLoaded', function () {
                document.querySelectorAll('[data-action="print"]').forEach(function (button) {
                    button.addEventListener('click', function () {
                        window.print();
                    });
                });
            });
        </script>
    @endif

</body>
</html>
