@php
    $selectedDefault = $defaultGovernorateId
        ?? old('default_governorate_id')
        ?? optional($governorates->firstWhere('code', 'NATL'))?->id
        ?? optional($governorates->first())->id;
@endphp

<div class="table-responsive">
    <table class="table table-sm table-striped align-middle quotes-table" data-context="{{ $context }}">
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
        @foreach($governorates as $governorate)
            @php
                $quote = $quotes[$governorate->id] ?? [];
                $sellValue = old("quotes.{$governorate->id}.sell_price", $quote['sell_price'] ?? '');
                $buyValue = old("quotes.{$governorate->id}.buy_price", $quote['buy_price'] ?? '');
                $sourceValue = old("quotes.{$governorate->id}.source", $quote['source'] ?? '');
                $quotedAtValue = old("quotes.{$governorate->id}.quoted_at", $quote['quoted_at'] ?? '');
                $quotedAtFormatted = $quotedAtValue
                    ? \Illuminate\Support\Carbon::parse($quotedAtValue)->format('Y-m-d\\TH:i')
                    : '';
            @endphp
            <tr data-governorate-row="{{ $governorate->id }}">
                <td>
                    <span class="fw-semibold" data-label="name">{{ $governorate->name }}</span>
                    <input type="hidden" name="quotes[{{ $governorate->id }}][governorate_id]" value="{{ $governorate->id }}">
                </td>
                <td>
                    <input type="number"
                           name="quotes[{{ $governorate->id }}][sell_price]"
                           value="{{ $sellValue }}"
                           class="form-control form-control-sm quote-input quote-sell-input"
                           min="0"
                           step="0.0001"
                           data-field="sell_price"
                           data-governorate="{{ $governorate->id }}"
                           placeholder="0.0000">
                </td>
                <td>
                    <input type="number"
                           name="quotes[{{ $governorate->id }}][buy_price]"
                           value="{{ $buyValue }}"
                           class="form-control form-control-sm quote-input quote-buy-input"
                           min="0"
                           step="0.0001"
                           data-field="buy_price"
                           data-governorate="{{ $governorate->id }}"
                           placeholder="0.0000">
                </td>
                <td>
                    <input type="text"
                           name="quotes[{{ $governorate->id }}][source]"
                           value="{{ $sourceValue }}"
                           class="form-control form-control-sm quote-input quote-source-input"
                           maxlength="255"
                           data-field="source"
                           data-governorate="{{ $governorate->id }}"
                           placeholder="{{ __('e.g. Central Bank, street vendor...') }}">
                </td>
                <td>
                    <input type="datetime-local"
                           name="quotes[{{ $governorate->id }}][quoted_at]"
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