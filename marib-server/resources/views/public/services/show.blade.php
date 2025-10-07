<!DOCTYPE html>
<html lang="{{ str_replace('_', '-', app()->getLocale()) }}" dir="{{ app()->getLocale() === 'ar' ? 'rtl' : 'ltr' }}">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{{ $service->title }} | {{ config('app.name') }}</title>
    <style>
        :root {
            color-scheme: light;
            font-family: "Cairo", -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
            background-color: #f4f5f7;
        }

        body {
            margin: 0;
            padding: 0;
            background-color: #f4f5f7;
            color: #1f2933;
        }

        .page-wrapper {
            max-width: 960px;
            margin: 0 auto;
            padding: 2rem 1.25rem 3rem;
        }

        .card {
            background: #fff;
            border-radius: 18px;
            box-shadow: 0 18px 40px rgba(15, 23, 42, 0.08);
            overflow: hidden;
        }

        .hero {
            position: relative;
            background: linear-gradient(135deg, #2152ff, #21d4fd);
            color: #fff;
            padding: 2.5rem 2rem 6rem;
        }

        .hero h1 {
            margin: 0 0 0.75rem;
            font-size: clamp(1.75rem, 3vw, 2.5rem);
            letter-spacing: 0.5px;
        }

        .hero p {
            margin: 0;
            opacity: 0.85;
            font-size: 1rem;
            line-height: 1.6;
            max-width: 52ch;
        }

        .hero-badge {
            display: inline-flex;
            align-items: center;
            gap: 0.5rem;
            background: rgba(255, 255, 255, 0.18);
            border-radius: 999px;
            padding: 0.35rem 1rem;
            margin-bottom: 1rem;
            font-size: 0.9rem;
        }

        .content {
            padding: 2.5rem 2rem;
            margin-top: -4rem;
            background: #fff;
            border-radius: 24px 24px 18px 18px;
        }

        .media-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
            gap: 1.5rem;
            margin-bottom: 2rem;
        }

        .media-card {
            background: #f8fafc;
            border-radius: 16px;
            padding: 1rem;
            text-align: center;
            border: 1px solid rgba(148, 163, 184, 0.25);
        }

        .media-card img {
            max-width: 100%;
            height: auto;
            border-radius: 12px;
            object-fit: cover;
        }

        .section-title {
            font-size: 1.25rem;
            font-weight: 700;
            margin-bottom: 1rem;
        }

        .details-grid {
            display: grid;
            gap: 1.5rem;
            grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
        }

        .stat {
            display: flex;
            flex-direction: column;
            gap: 0.35rem;
            padding: 1rem 1.25rem;
            border-radius: 14px;
            background: #f8fafc;
            border: 1px solid rgba(148, 163, 184, 0.18);
        }

        .stat span:first-child {
            font-size: 0.85rem;
            font-weight: 600;
            text-transform: uppercase;
            color: #64748b;
            letter-spacing: 0.08em;
        }

        .stat strong {
            font-size: 1.1rem;
        }

        .description {
            margin-top: 2rem;
            line-height: 1.8;
            color: #334155;
            background: #f9fbfd;
            padding: 1.5rem;
            border-radius: 16px;
            border: 1px solid rgba(148, 163, 184, 0.14);
        }

        .footer-note {
            margin-top: 2.5rem;
            font-size: 0.85rem;
            color: #7b8794;
            text-align: center;
        }

        .cta {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            gap: 0.5rem;
            padding: 0.85rem 1.5rem;
            border-radius: 999px;
            background: #2152ff;
            color: #fff;
            font-weight: 600;
            text-decoration: none;
            transition: transform 0.2s ease, box-shadow 0.2s ease;
        }

        .cta:hover {
            transform: translateY(-2px);
            box-shadow: 0 12px 24px rgba(33, 82, 255, 0.25);
        }

        @media (max-width: 600px) {
            .content {
                padding: 1.5rem 1.25rem;
            }
        }
    </style>
</head>
<body>
<div class="page-wrapper">
    <div class="card">
        <div class="hero">
            <div class="hero-badge">
                <span>🔍</span>
                <span>{{ __('تفاصيل الخدمة') }}</span>
            </div>
            <h1>{{ $service->title }}</h1>
            @if($service->category)
                <p>{{ __('الفئة') }}: {{ $service->category->name }}</p>
            @endif
        </div>

        <div class="content">
            <div class="media-grid">
                @if($imageUrl)
                    <div class="media-card">
                        <strong>{{ __('صورة الخدمة') }}</strong>
                        <img src="{{ $imageUrl }}" alt="{{ $service->title }}">
                    </div>
                @endif

                @if($iconUrl)
                    <div class="media-card">
                        <strong>{{ __('الأيقونة') }}</strong>
                        <img src="{{ $iconUrl }}" alt="{{ $service->title }} icon" style="max-width: 120px;">
                    </div>
                @endif
            </div>

            <div class="details-grid">
                <div class="stat">
                    <span>{{ __('الحالة') }}</span>
                    <strong>{{ $service->status ? __('نشطة') : __('غير فعالة') }}</strong>
                </div>

                <div class="stat">
                    <span>{{ __('نوع الخدمة') }}</span>
                    <strong>{{ $service->service_type ?? __('غير محدد') }}</strong>
                </div>

                <div class="stat">
                    <span>{{ __('سعر الخدمة') }}</span>
                    @if($service->is_paid && $service->price !== null)
                        <strong>{{ number_format((float)$service->price, 2) }} {{ $service->currency ?? '' }}</strong>
                    @else
                        <strong>{{ __('مجانية') }}</strong>
                    @endif
                </div>

                @if($service->expiry_date)
                    <div class="stat">
                        <span>{{ __('تاريخ الانتهاء') }}</span>
                        <strong>{{ \Illuminate\Support\Carbon::parse($service->expiry_date)->format('Y-m-d') }}</strong>
                    </div>
                @endif

                @if($service->owner)
                    <div class="stat">
                        <span>{{ __('مقدم الخدمة') }}</span>
                        <strong>{{ $service->owner->name }}</strong>
                        @if($service->owner->email)
                            <small>{{ $service->owner->email }}</small>
                        @endif
                    </div>
                @endif

                @if($service->service_uid)
                    <div class="stat">
                        <span>{{ __('معرّف الخدمة') }}</span>
                        <strong>{{ $service->service_uid }}</strong>
                    </div>
                @endif

                <div class="stat">
                    <span>{{ __('عدد الزيارات') }}</span>
                    <strong>{{ number_format((int) ($service->views ?? 0)) }}</strong>
                </div>
            </div>

            @if($service->description)
                <div class="section-title">{{ __('الوصف') }}</div>
                <div class="description">{!! nl2br(e($service->description)) !!}</div>
            @endif

            @if($service->is_paid && $service->price_note)
                <div class="section-title">{{ __('ملاحظات التسعير') }}</div>
                <div class="description">{!! nl2br(e($service->price_note)) !!}</div>
            @endif

            <div style="margin-top: 2.5rem; text-align: center;">
                <a href="{{ url('/') }}" class="cta">{{ __('العودة إلى الرئيسية') }}</a>
            </div>

            <p class="footer-note">{{ __('هذه الصفحة عامة لعرض تفاصيل الخدمة ويمكن مشاركتها مع العملاء مباشرة.') }}</p>
        </div>
    </div>
</div>
</body>
</html> 