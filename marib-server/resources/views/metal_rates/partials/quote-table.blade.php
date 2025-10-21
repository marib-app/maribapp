@php
    $selectedDefault = $defaultGovernorateId
        ?? old('default_governorate_id')
        ?? optional($governorates->firstWhere('code', 'NATL'))?->id
        ?? optional($governorates->first())->id;

    $submittedQuotes = collect(old('quotes', []))
        ->filter(fn ($quote) => is_array($quote) && array_key_exists('governorate_id', $quote))
        ->keyBy(fn ($quote) => (int) $quote['governorate_id']);

    $initialQuotes = collect($quotes ?? [])
        ->map(function ($quote, $key) {
            if (!is_array($quote)) {
                $quote = (array) $quote;
            }

            if (!array_key_exists('governorate_id', $quote)) {
                if (is_numeric($key)) {
                    $quote['governorate_id'] = (int) $key;
                }
            }

            return $quote;
        })
        ->filter(fn ($quote) => array_key_exists('governorate_id', $quote))
        ->keyBy(fn ($quote) => (int) $quote['governorate_id']);

@endphp

<div class="table-responsive">
    <table class="table table-sm table-striped align-middle quotes-table"
           data-context="{{ $context }}"
           data-next-quote-index="{{ $governorates->count() }}">
        <thead>
        <tr>
            <th scope="col">{{ __('Governorate') }}</th>
            <th scope="col">{{ __('Sell Price') }}</th>
            <th scope="col">{{ __('Buy Price') }}</th>
            <th scope="col">{{ __('Source') }}</th>
            <th scope="col">{{ __('Quoted At') }}</th>
            <th scope="col" class="text-center">{{ __('Default') }}</th>
        </tr>
        </thead>
        <tbody>
        @foreach($governorates as $rowIndex => $governorate)

            @php
                $quote = $submittedQuotes->get($governorate->id)
                    ?? $initialQuotes->get($governorate->id)
                    ?? [];
                $sellValue = $quote['sell_price'] ?? '';
                $buyValue = $quote['buy_price'] ?? '';
                $sourceValue = $quote['source'] ?? '';
                $quotedAtValue = $quote['quoted_at'] ?? null;

                $quotedAtFormatted = $quotedAtValue
                    ? \Illuminate\Support\Carbon::parse($quotedAtValue)->format('Y-m-d\\TH:i')
                    : '';
                $fieldPrefix = "quotes[{$rowIndex}]";

            @endphp
            <tr data-governorate-row="{{ $governorate->id }}">
                <td>
                    <span class="fw-semibold" data-label="name">{{ $governorate->name }}</span>
                    <input type="hidden"
                           name="{{ $fieldPrefix }}[governorate_id]"
                           value="{{ $governorate->id }}"
                           data-field="governorate_id"
                           data-governorate="{{ $governorate->id }}">
                        
                        </td>
                <td>
                    <input type="number"
                           name="{{ $fieldPrefix }}[sell_price]"
                           value="{{ $sellValue }}"
                           class="form-control form-control-sm quote-input quote-sell-input"
                           min="0"
                           step="0.001"
                           data-field="sell_price"
                           data-governorate="{{ $governorate->id }}"
                           placeholder="0.000">
                </td>
                <td>
                    <input type="number"
                           name="{{ $fieldPrefix }}[buy_price]"
                           value="{{ $buyValue }}"
                           class="form-control form-control-sm quote-input quote-buy-input"
                           min="0"
                           step="0.001"
                           data-field="buy_price"
                           data-governorate="{{ $governorate->id }}"
                           placeholder="0.000">
                </td>
                <td>
                    <input type="text"
                           name="{{ $fieldPrefix }}[source]"
                           value="{{ $sourceValue }}"
                           class="form-control form-control-sm quote-input quote-source-input"
                           maxlength="255"
                           data-field="source"
                           data-governorate="{{ $governorate->id }}"
                           placeholder="{{ __('e.g. Central Bank, street vendor...') }}">
                </td>
                <td>
                    <input type="datetime-local"
                           name="{{ $fieldPrefix }}[quoted_at]"
                           value="{{ $quotedAtFormatted }}"
                           class="form-control form-control-sm quote-input quote-quoted-at-input"
                           data-field="quoted_at"
                           data-governorate="{{ $governorate->id }}">
                </td>
                <td class="text-center">
                    <div class="form-check form-check-inline">
                        <input class="form-check-input default-governorate-radio"
                               type="radio"
                               name="default_governorate_id"
                               value="{{ $governorate->id }}"
                               {{ (string) $selectedDefault === (string) $governorate->id ? 'checked' : '' }}>
                    </div>
                </td>
            </tr>
        @endforeach
        </tbody>
    </table>
</div>