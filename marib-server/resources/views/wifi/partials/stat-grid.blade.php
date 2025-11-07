@php
    $statCards = [
        [
            'icon' => 'bi bi-wifi',
            'icon_classes' => 'text-primary bg-primary-subtle',
            'badge' => ['class' => 'badge bg-primary text-white', 'label' => __('الشبكات')],
            'value' => number_format(data_get($stats, 'networks.total', 0)),
            'subtitle' => __('نشط: :active | متوقف: :inactive | معلّق: :suspended', [
                'active' => number_format(data_get($stats, 'networks.active', 0)),
                'inactive' => number_format(data_get($stats, 'networks.inactive', 0)),
                'suspended' => number_format(data_get($stats, 'networks.suspended', 0)),
            ]),
        ],
        [
            'icon' => 'bi bi-list-check',
            'icon_classes' => 'text-success bg-success-subtle',
            'badge' => ['class' => 'badge bg-success text-white', 'label' => __('الخطط')],
            'value' => number_format(data_get($stats, 'plans.total', 0)),
            'subtitle' => __('نشطة: :active | مرفوعة: :uploaded | مؤرشفة: :archived', [
                'active' => number_format(data_get($stats, 'plans.active', 0)),
                'uploaded' => number_format(data_get($stats, 'plans.uploaded', 0)),
                'archived' => number_format(data_get($stats, 'plans.archived', 0)),
            ]),
        ],
        [
            'icon' => 'bi bi-box-seam',
            'icon_classes' => 'text-warning bg-warning-subtle',
            'badge' => ['class' => 'badge bg-warning text-dark', 'label' => __('دفعات الأكواد')],
            'value' => number_format(data_get($stats, 'batches.total', 0)),
            'subtitle' => __('قيد المراجعة: :pending | مفعّلة: :active', [
                'pending' => number_format(data_get($stats, 'batches.pending', 0)),
                'active' => number_format(data_get($stats, 'batches.active', 0)),
            ]),
        ],
        [
            'icon' => 'bi bi-key',
            'icon_classes' => 'text-info bg-info-subtle',
            'badge' => ['class' => 'badge bg-info text-dark', 'label' => __('الأكواد')],
            'value' => number_format(data_get($stats, 'codes.total', 0)),
            'subtitle' => __('متاحة: :available | مباعة: :sold', [
                'available' => number_format(data_get($stats, 'codes.available', 0)),
                'sold' => number_format(data_get($stats, 'codes.sold', 0)),
            ]),
        ],
    ];
@endphp

<div class="row g-3 mb-3">
    @foreach($statCards as $card)
        <div class="col-xl-3 col-lg-6 col-md-6">
            <div class="wifi-stat-card h-100">
                <div class="wifi-stat-card__header">
                    <div class="wifi-stat-card__icon {{ $card['icon_classes'] }}">
                        <i class="{{ $card['icon'] }}"></i>
                    </div>
                    <span class="{{ $card['badge']['class'] }}">{{ $card['badge']['label'] }}</span>
                </div>
                <div class="wifi-stat-card__content">
                    <span class="wifi-stat-card__value">{{ $card['value'] }}</span>
                    <p class="wifi-stat-card__subtitle">{{ $card['subtitle'] }}</p>
                </div>
            </div>
        </div>
    @endforeach
</div>
