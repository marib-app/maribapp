<?php

namespace App\Http\Controllers;

use App\Models\Category;
use App\Models\User;
use App\Services\ResponseService;
use App\Services\ServiceAuthorizationService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class CategoryManagerController extends Controller
{
    public function __construct(private ServiceAuthorizationService $serviceAuthorizationService)
    {
    }

    public function edit(Category $category)
    {
        ResponseService::noPermissionThenRedirect('service-managers-manage');

        $user = Auth::user();

        if ($user) {
            $this->serviceAuthorizationService->ensureUserCanManageCategory($user, $category);
        }

        $category->load('managers:id,name,email');

        $customers = User::customers()
            ->orderBy('name')
            ->get(['id', 'name', 'email']);

        $assignedManagerIds = $category->managers
            ->pluck('id')
            ->map(static fn ($id) => (int) $id)
            ->all();

        return view('category.managers', [
            'category' => $category,
            'customers' => $customers,
            'assignedManagerIds' => $assignedManagerIds,
        ]);
    }

    public function update(Request $request, Category $category)
    {
        ResponseService::noPermissionThenRedirect('service-managers-manage');

        $user = Auth::user();

        if ($user) {
            $this->serviceAuthorizationService->ensureUserCanManageCategory($user, $category);
        }

        $validated = $request->validate([
            'managers' => ['array'],
            'managers.*' => ['integer', 'exists:users,id'],
        ]);

        $selectedIds = $validated['managers'] ?? [];

        $managerIds = empty($selectedIds)
            ? []
            : User::customers()
                ->whereIn('id', $selectedIds)
                ->pluck('id')
                ->map(static fn ($id) => (int) $id)
                ->unique()
                ->values()
                ->all();

        $category->managers()->sync($managerIds);

        return ResponseService::successRedirectResponse(
            __('تم تحديث مسؤولي الفئة بنجاح'),
            route('category.managers.edit', $category)
        );
    }
}