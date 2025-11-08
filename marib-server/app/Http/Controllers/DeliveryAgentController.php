<?php

namespace App\Http\Controllers;

use App\Models\DeliveryAgent;
use App\Models\User;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\View\View;

class DeliveryAgentController extends Controller
{
    public function index(): View
    {
        $agents = DeliveryAgent::query()
            ->with('user')
            ->orderByDesc('is_active')
            ->orderBy('name')
            ->paginate(20);

        return view('delivery.agents.index', [
            'agents' => $agents,
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        $validated = $request->validate([
            'identifier' => ['required', 'string', 'max:191'],
            'vehicle_type' => ['nullable', 'string', 'max:191'],
        ]);

        $user = User::query()
            ->where('email', $validated['identifier'])
            ->orWhere('mobile', $validated['identifier'])
            ->orWhere('id', $validated['identifier'])
            ->first();

        if (! $user) {
            return back()->withErrors(['identifier' => __('لم يتم العثور على مستخدم بهذا المعرف.')]);
        }

        DeliveryAgent::query()->updateOrCreate(
            ['user_id' => $user->getKey()],
            [
                'name' => $user->name ?? $user->email,
                'phone' => $user->mobile,
                'vehicle_type' => $validated['vehicle_type'] ?? null,
                'is_active' => true,
            ]
        );

        return back()->with('success', __('تم إضافة المندوب بنجاح.'));
    }

    public function destroy(DeliveryAgent $deliveryAgent): RedirectResponse
    {
        $deliveryAgent->delete();

        return back()->with('success', __('تم إزالة المندوب.'));
    }

    public function toggle(DeliveryAgent $deliveryAgent): RedirectResponse
    {
        $deliveryAgent->is_active = ! $deliveryAgent->is_active;
        $deliveryAgent->save();

        return back()->with('success', __('تم تحديث حالة المندوب.'));
    }
}
