<?php

namespace App\Http\Controllers;

use App\Models\Coupon;
use App\Services\ResponseService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Illuminate\View\View;

class CouponController extends Controller
{
    public function __construct()
    {
        $this->middleware('permission:coupon-list|coupon-create|coupon-edit', ['only' => ['index']]);
        $this->middleware('permission:coupon-create', ['only' => ['create', 'store']]);
        $this->middleware('permission:coupon-edit', ['only' => ['edit', 'update']]);
    }

    public function index(): View
    {
        ResponseService::noAnyPermissionThenRedirect(['coupon-list', 'coupon-create', 'coupon-edit']);

        $coupons = Coupon::query()->latest()->paginate(15);

        return view('coupons.index', compact('coupons'));
    }

    public function create(): View
    {
        ResponseService::noPermissionThenRedirect('coupon-create');

        return view('coupons.create');
    }

    public function store(Request $request): RedirectResponse
    {
        ResponseService::noPermissionThenRedirect('coupon-create');

        $data = $this->validateCoupon($request);

        $data['code'] = Str::upper($data['code']);
        $data['is_active'] = $request->boolean('is_active');

        Coupon::create($data);

        return redirect()->route('coupons.index')->with('success', __('تم إنشاء القسيمة بنجاح.'));
    }

    public function edit(Coupon $coupon): View
    {
        ResponseService::noPermissionThenRedirect('coupon-edit');

        return view('coupons.edit', compact('coupon'));
    }

    public function update(Request $request, Coupon $coupon): RedirectResponse
    {
        ResponseService::noPermissionThenRedirect('coupon-edit');

        $data = $this->validateCoupon($request, $coupon);

        $data['code'] = Str::upper($data['code']);
        $data['is_active'] = $request->boolean('is_active');

        $coupon->update($data);

        return redirect()->route('coupons.index')->with('success', __('تم تحديث القسيمة بنجاح.'));
    }

    /**
     * @return array<string, mixed>
     */
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
                $validator->errors()->add('max_uses_per_user', __('لا يمكن أن يتجاوز حد الاستخدام لكل مستخدم إجمالي الحد المتاح.'));
            }
        });

        return $validator->validate();
    }
}