<?php

namespace App\Http\Controllers;

use App\Models\DepartmentNumberSetting;
use App\Services\DepartmentReportService;
use App\Services\LegalNumberingService;
use App\Services\ResponseService;
use Illuminate\Contracts\View\View;
use Illuminate\Http\Request;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\Validator;

class LegalNumberingSettingController extends Controller
{
    public function __construct(
        private readonly DepartmentReportService $departments,
        private readonly LegalNumberingService $legalNumbering,
    ) {
    }

    public function index(): View
    {
        ResponseService::noPermissionThenRedirect('settings-update');

        $departmentLabels = [
            DepartmentNumberSetting::DEFAULT_DEPARTMENT => __('Default Department'),
        ] + $this->departments->availableDepartments();

        $existingSettings = DepartmentNumberSetting::query()
            ->whereIn('department', array_keys($departmentLabels))
            ->get()
            ->keyBy('department');

        $departments = collect($departmentLabels)->map(function (string $label, string $key) use ($existingSettings) {
            $setting = $existingSettings->get($key) ?? new DepartmentNumberSetting([
                'department' => $key,
                'legal_numbering_enabled' => false,
                'order_prefix' => null,
                'invoice_prefix' => null,
                'next_order_number' => 1,
                'next_invoice_number' => 1,
            ]);

            return [
                'key' => $key,
                'label' => $label,
                'setting' => $setting,
            ];
        });

        return view('settings.legal-numbering', [
            'departments' => $departments,
        ]);
    }

    public function update(Request $request): void
    {
        ResponseService::noPermissionThenSendJson('settings-update');

        $validator = Validator::make($request->all(), [
            'departments' => ['required', 'array'],
            'departments.*.legal_numbering_enabled' => ['nullable', 'boolean'],
            'departments.*.order_prefix' => ['nullable', 'string', 'max:50'],
            'departments.*.invoice_prefix' => ['nullable', 'string', 'max:50'],
            'departments.*.next_order_number' => ['required', 'integer', 'min:1'],
            'departments.*.next_invoice_number' => ['required', 'integer', 'min:1'],
        ]);

        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }

        $payload = $validator->validated()['departments'] ?? [];

        $allowedDepartments = array_keys([
            DepartmentNumberSetting::DEFAULT_DEPARTMENT => true,
        ] + $this->departments->availableDepartments());

        foreach (Arr::only($payload, $allowedDepartments) as $department => $attributes) {
            $attributes['legal_numbering_enabled'] = (bool) ($attributes['legal_numbering_enabled'] ?? false);
            $this->legalNumbering->updateSettings($department, $attributes);
        }

        ResponseService::successResponse('Settings Updated Successfully');
    }
}