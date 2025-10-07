<?php

namespace App\Http\Controllers;

use App\Services\DepartmentAdvertiserService;
use App\Services\DepartmentReportService;
use App\Services\ResponseService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;

class DepartmentAdvertiserController extends Controller
{
    public function __construct(private readonly DepartmentAdvertiserService $departmentAdvertiserService)
    {
    }

    public function updateComputer(Request $request): RedirectResponse
    {
        ResponseService::noPermissionThenRedirect('computer-ads-update');

        return $this->handleUpdate(
            $request,
            DepartmentReportService::DEPARTMENT_COMPUTER,
            'item.computer.settings'
        );
    }

    public function updateShein(Request $request): RedirectResponse
    {
        ResponseService::noPermissionThenRedirect('shein-products-update');

        return $this->handleUpdate(
            $request,
            DepartmentReportService::DEPARTMENT_SHEIN,
            'item.shein.settings'
        );
    }

    private function handleUpdate(Request $request, string $department, string $redirectRoute): RedirectResponse
    {
        $validated = $this->validateRequest($request);
        $image = $request->file('image');

        $this->departmentAdvertiserService->updateAdvertiser($department, $validated, $image);

        return redirect()
            ->route($redirectRoute)
            ->with('success', __('Department advertiser data updated successfully.'));
    }

    /**
     * @return array<string, mixed>
     */
    private function validateRequest(Request $request): array
    {
        return $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'image' => ['nullable', 'image', 'max:2048'],
            'contact_number' => ['nullable', 'string', 'max:255'],
            'message_number' => ['nullable', 'string', 'max:255'],
            'location' => ['nullable', 'string', 'max:255'],
        ]);
    }
}