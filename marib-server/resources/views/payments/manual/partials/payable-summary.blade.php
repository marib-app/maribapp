@php
    use App\Models\Item;
    use App\Models\Order;
    use App\Models\Package;
    use Illuminate\Support\Facades\Route;
    use Illuminate\Support\Str;

    $payable = $request->payable;
    $typeLabel = $request->payable_type
        ? Str::title(class_basename($request->payable_type))
        : __('Unassigned');
    $identifier = $request->payable_id ? '#' . $request->payable_id : __('N/A');
    $description = __('No additional details available.');
    $detailsUrl = null;

    if ($payable instanceof Order) {
        $typeLabel = __('Order');
        $identifier = $payable->order_number
            ? __('Order #:number', ['number' => $payable->order_number])
            : __('Order ID: :id', ['id' => $payable->id]);
        $description = __('Customer: :name', ['name' => $payable->user?->name ?? __('Unknown')]);
        $detailsUrl = Route::has('orders.show') ? route('orders.show', $payable) : null;
    } elseif ($payable instanceof Package) {
        $typeLabel = __('Package');
        $identifier = __('Package ID: :id', ['id' => $payable->id]);
        $description = $payable->name ?? __('Package without a title');
        $detailsUrl = Route::has('package.show') ? route('package.show', $payable) : null;
    } elseif ($payable instanceof Item) {
        $typeLabel = __('Advertisement');
        $identifier = $payable->slug
            ? __('Ad Slug: :slug', ['slug' => $payable->slug])
            : __('Ad ID: :id', ['id' => $payable->id]);
        $description = $payable->name ?? __('Advertisement without a title');
        $detailsUrl = Route::has('item.show') ? route('item.show', $payable) : null;
    } elseif (filled($request->payable_type)) {
        $description = __('The associated :type record could not be found.', ['type' => $typeLabel]);
    }
@endphp

<div class="card shadow-sm mt-4">
    <div class="card-header bg-light d-flex justify-content-between align-items-center">
        <h6 class="mb-0"><i class="fa fa-link me-2"></i>{{ __('Linked Record') }}</h6>
        <span class="badge bg-info text-dark">{{ $typeLabel }}</span>
    </div>
    <div class="card-body">
        @if($payable)
            <dl class="row mb-0">
                <dt class="col-sm-4 text-muted">{{ __('Identifier') }}</dt>
                <dd class="col-sm-8">{{ $identifier }}</dd>

                <dt class="col-sm-4 text-muted">{{ __('Summary') }}</dt>
                <dd class="col-sm-8">{{ $description }}</dd>

                @if($detailsUrl)
                    <dt class="col-sm-4 text-muted">{{ __('Details') }}</dt>
                    <dd class="col-sm-8">
                        <a href="{{ $detailsUrl }}" target="_blank" rel="noopener" class="text-decoration-none">
                            {{ __('Open in a new tab') }}
                            <i class="fa fa-external-link-alt ms-1"></i>
                        </a>
                    </dd>
                @endif
            </dl>
        @else
            <p class="mb-0 text-muted">
                {{ __('No linked record is available for this manual payment request.') }}
            </p>
        @endif
    </div>
</div>