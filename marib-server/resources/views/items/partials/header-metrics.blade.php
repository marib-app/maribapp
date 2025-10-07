@php
    $metricDefinitions = [
        'total' => [
            'label' => __('Total Ads'),
            'variant' => 'primary',
            'icon' => 'fa-layer-group',
        ],
        'approved' => [
            'label' => __('Approved'),
            'variant' => 'success',
            'icon' => 'fa-check-circle',
        ],
        'review' => [
            'label' => __('Under Review'),
            'variant' => 'warning',
            'icon' => 'fa-search',
        ],
        'rejected' => [
            'label' => __('Rejected'),
            'variant' => 'danger',
            'icon' => 'fa-times-circle',
        ],
        'sold_out' => [
            'label' => __('Sold Out'),
            'variant' => 'info',
            'icon' => 'fa-shopping-bag',
        ],
        'expired' => [
            'label' => __('Expired'),
            'variant' => 'secondary',
            'icon' => 'fa-hourglass-half',
        ],
        'inactive' => [
            'label' => __('Inactive'),
            'variant' => 'teal',
            'icon' => 'fa-power-off',
        ],
    ];

    $resolvedMetrics = collect($metricDefinitions)
        ->map(function ($definition, $key) use ($statistics) {
            $value = data_get($statistics ?? [], $key, 0);

            return [
                ...$definition,
                'value' => number_format((int) $value),
            ];
        });
@endphp

<div class="items-metrics card border-0 shadow-sm mb-4">
    <div class="card-body">
        <div class="items-metrics__grid">
            @foreach($resolvedMetrics as $metric)
                <div class="items-metrics__card items-metrics__card--{{ $metric['variant'] }}">
                    <div class="items-metrics__icon">
                        <i class="fa {{ $metric['icon'] }}"></i>
                    </div>
                    <div class="items-metrics__content">
                        <p class="items-metrics__label mb-1">{{ $metric['label'] }}</p>
                        <p class="items-metrics__value mb-0">{{ $metric['value'] }}</p>
                    </div>
                </div>
            @endforeach
        </div>
    </div>
</div>