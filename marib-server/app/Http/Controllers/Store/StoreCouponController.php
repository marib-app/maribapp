<?php

namespace App\Http\Controllers\Store;

use App\Http\Controllers\Controller;
use App\Models\Coupon;
use App\Models\Store;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Illuminate\View\View;

class StoreCouponController extends Controller
{
    public function index(Request $request): View
    {
        $store = $this->currentStore($request);

        $coupons = Coupon::query()
            ->where('store_id', $store->getKey())
            ->latest()
            ->paginate(15);

        return view('store.coupons.index', [
            'store' => $store,
            'coupons' => $coupons,
        ]);
    }

    public function create(Request $request): View
    {
        $store = $this->currentStore($request);

        return view('store.coupons.create', [
            'store' => $store,
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        $store = $this->currentStore($request);

        $data = $this->validateCoupon($request);
        $data['code'] = Str::upper($data['code']);
        $data['is_active'] = $request->boolean('is_active', true);
        $data['store_id'] = $store->getKey();

        Coupon::create($data);

        return redirect()
            ->route('merchant.coupons.index')
            ->with('success', __('merchant_coupons.create_success'));
    }

    public function edit(Request $request, Coupon $coupon): View
    {
        $store = $this->currentStore($request);
        abort_if($coupon->store_id !== $store->getKey(), 404);

        return view('store.coupons.edit', [
            'store' => $store,
            'coupon' => $coupon,
        ]);
    }

    public function update(Request $request, Coupon $coupon): RedirectResponse
    {
        $store = $this->currentStore($request);
        abort_if($coupon->store_id !== $store->getKey(), 404);

        $data = $this->validateCoupon($request, $coupon);
        $data['code'] = Str::upper($data['code']);
        $data['is_active'] = $request->boolean('is_active', true);

        $coupon->update($data);

        return redirect()
            ->route('merchant.coupons.index')
            ->with('success', __('merchant_coupons.update_success'));
    }

    public function destroy(Request $request, Coupon $coupon): RedirectResponse
    {
        $store = $this->currentStore($request);
        abort_if($coupon->store_id !== $store->getKey(), 404);

        $coupon->delete();

        return redirect()
            ->route('merchant.coupons.index')
            ->with('success', __('merchant_coupons.delete_success'));
    }

    public function toggle(Request $request, Coupon $coupon): RedirectResponse
    {
        $store = $this->currentStore($request);
        abort_if($coupon->store_id !== $store->getKey(), 404);

        $coupon->forceFill([
            'is_active' => ! $coupon->is_active,
        ])->save();

        $message = $coupon->is_active
            ? __('merchant_coupons.activated_success')
            : __('merchant_coupons.deactivated_success');

        return redirect()
            ->route('merchant.coupons.index')
            ->with('success', $message);
    }

    private function validateCoupon(Request $request, ?Coupon $coupon = null): array
    {
        $rules = [
            'code' => ['required', 'string', 'max:191', Rule::unique('coupons', 'code')->ignore($coupon?->getKey())],
            'name' => ['required', 'string', 'max:191'],
            'description' => ['nullable', 'string'],
            'discount_type' => ['required', Rule::in(['percentage', 'fixed'])],
            'discount_value' => ['required', 'numeric', 'min:0.01'],
            'minimum_order_amount' => ['nullable', 'numeric', 'min:0'],
            'max_uses' => ['nullable', 'integer', 'min:1'],
            'max_uses_per_user' => ['nullable', 'integer', 'min:1'],
            'starts_at' => ['nullable', 'date'],
            'ends_at' => ['nullable', 'date', 'after_or_equal:starts_at'],
            'is_active' => ['nullable', 'boolean'],
        ];

        $validator = Validator::make($request->all(), $rules);

        $validator->sometimes('discount_value', 'max:100', function ($input) {
            return $input->discount_type === 'percentage';
        });

        $validator->after(function ($validator) use ($request) {
            $maxUses = $request->input('max_uses');
            $perUser = $request->input('max_uses_per_user');

            if ($maxUses !== null && $perUser !== null && (int) $perUser > (int) $maxUses) {
                $validator->errors()->add('max_uses_per_user', __('merchant_coupons.max_per_user_error'));
            }
        });

        return $validator->validate();
    }

    private function currentStore(Request $request): Store
    {
        $store = $request->attributes->get('currentStore');

        abort_unless($store instanceof Store, 404);

        return $store;
    }
}
