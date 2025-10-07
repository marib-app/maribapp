<?php

namespace App\Http\Controllers;

use App\Models\Setting;
use App\Services\CachingService;
use App\Services\DepartmentAdvertiserService;
use App\Services\DepartmentReportService;
use ArrayAccess;
use Illuminate\Contracts\View\View;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Arr;
use Illuminate\Support\Collection;
use InvalidArgumentException;

class DepartmentSettingsController extends Controller
{
    public function __construct(private readonly DepartmentAdvertiserService $departmentAdvertiserService)
    {
    }

    public function editShein(): View
    {
        return $this->renderSettings(DepartmentReportService::DEPARTMENT_SHEIN);
    }

    public function editComputer(): View
    {
        return $this->renderSettings(DepartmentReportService::DEPARTMENT_COMPUTER);
    }

    public function updateShein(Request $request): RedirectResponse
    {
        return $this->handleUpdate($request, DepartmentReportService::DEPARTMENT_SHEIN);
    }

    public function updateComputer(Request $request): RedirectResponse
    {
        return $this->handleUpdate($request, DepartmentReportService::DEPARTMENT_COMPUTER);
    }

    private function renderSettings(string $department): View
    {
        $keys = $this->keysForDepartment($department);
        $settings = $this->settingsArray();
        $advertiser = $this->departmentAdvertiserService->getAdvertiser($department);

        $defaults = (array) config("orders.deposit.departments.$department", []);

        $ratioRaw = Arr::get($settings, $keys['deposit_ratio']);
        $ratioDefault = Arr::get($defaults, 'ratio');
        $ratioValue = $this->toFloat($ratioRaw);
        if ($ratioValue === null) {
            $ratioValue = $this->toFloat($ratioDefault);
        }
        $ratioDisplay = $ratioValue === null ? null : $this->ratioToPercentage($ratioValue);

        $minimumRaw = Arr::get($settings, $keys['deposit_minimum']);
        $minimumDefault = Arr::get($defaults, 'minimum_amount');
        $minimumValue = $this->toFloat($minimumRaw);
        if ($minimumValue === null) {
            $minimumValue = $this->toFloat($minimumDefault);
        }



        $whatsappEnabled = $this->booleanWithDefault(Arr::get($settings, $keys['whatsapp_enabled']), false);
        $whatsappNumber = (string) Arr::get($settings, $keys['whatsapp_number'], '');

        $returnPolicy = (string) Arr::get($settings, $keys['return_policy'], '');

        return view('items.department-settings', [
            'department' => $department,
            'departmentLabel' => $this->departmentLabel($department),
            'advertiser' => $advertiser,
            'settingsKeys' => $keys,
            'formValues' => [
                $keys['deposit_ratio'] => $ratioDisplay,
                $keys['deposit_minimum'] => $minimumValue,
                $keys['whatsapp_enabled'] => $whatsappEnabled,
                $keys['whatsapp_number'] => $whatsappNumber,
                $keys['return_policy'] => $returnPolicy,
            ],
            'updateRoute' => $this->settingsUpdateRouteName($department, true),
            'advertiserRoute' => $this->advertiserRouteName($department, true),
            'permission' => $this->permissionForDepartment($department),
        ]);
    }

    private function handleUpdate(Request $request, string $department): RedirectResponse
    {
        $keys = $this->keysForDepartment($department);

        $rules = [
            $keys['deposit_ratio'] => ['nullable', 'numeric', 'min:0'],
            $keys['deposit_minimum'] => ['nullable', 'numeric', 'min:0'],
            $keys['whatsapp_enabled'] => ['required', 'boolean'],
            $keys['whatsapp_number'] => ['nullable', 'string', 'max:255'],
            $keys['return_policy'] => ['nullable', 'string'],
        ];

        $validated = $request->validate($rules);

        $ratioInput = $validated[$keys['deposit_ratio']] ?? null;
        $ratioValue = null;
        if ($ratioInput !== null && $ratioInput !== '') {
            $ratioValue = (float) $ratioInput;
            if ($ratioValue > 1) {
                $ratioValue = $ratioValue / 100;
            }
        }

        $minimumInput = $validated[$keys['deposit_minimum']] ?? null;
        $minimumValue = null;
        if ($minimumInput !== null && $minimumInput !== '') {
            $minimumValue = (float) $minimumInput;
        }

        $whatsappEnabled = filter_var($validated[$keys['whatsapp_enabled']] ?? false, FILTER_VALIDATE_BOOLEAN);
        $whatsappNumber = Arr::get($validated, $keys['whatsapp_number']);
        $returnPolicy = Arr::get($validated, $keys['return_policy']);

        $this->persistSetting($keys['deposit_ratio'], $ratioValue);
        $this->persistSetting($keys['deposit_minimum'], $minimumValue);
        $this->persistSetting($keys['whatsapp_enabled'], $whatsappEnabled);
        $this->persistSetting($keys['whatsapp_number'], $whatsappNumber);
        $this->persistSetting($keys['return_policy'], $returnPolicy);

        CachingService::removeCache(config('constants.CACHE.SETTINGS'));

        return redirect()
            ->route($this->settingsRouteName($department))
            ->with('success', __('تم تحديث إعدادات القسم بنجاح.'));
    }

    private function persistSetting(string $key, mixed $value): void
    {
        if ($value === null || $value === '') {
            Setting::query()->updateOrCreate(
                ['name' => $key],
                ['value' => '', 'type' => 'string']
            );
            return;
        }

        if (is_string($value)) {
            $value = trim($value);
            if ($value === '') {
                Setting::query()->updateOrCreate(
                    ['name' => $key],
                    ['value' => '', 'type' => 'string']
                );
                return;
            }
        }

        if (is_bool($value)) {
            $value = $value ? '1' : '0';
        } elseif (is_numeric($value)) {
            $value = (string) $value;
        }

        Setting::query()->updateOrCreate(
            ['name' => $key],
            ['value' => $value, 'type' => 'string']
        );
    }

    private function booleanWithDefault(mixed $value, bool $default): bool
    {
        if ($value === null || $value === '') {
            return $default;
        }

        return $this->toBoolean($value);
    }

    /**
     * @return array<string, string>
     */
    private function keysForDepartment(string $department): array
    {
        return match ($department) {
            DepartmentReportService::DEPARTMENT_SHEIN => [
                'deposit_ratio' => 'orders_deposit_shein_ratio',
                'deposit_minimum' => 'orders_deposit_shein_minimum',
                'whatsapp_enabled' => 'whatsapp_enabled_shein',
                'whatsapp_number' => 'whatsapp_number_shein',
                'return_policy' => 'return_policy_shein',
            ],
            DepartmentReportService::DEPARTMENT_COMPUTER => [
                'deposit_ratio' => 'orders_deposit_computer_ratio',
                'deposit_minimum' => 'orders_deposit_computer_minimum',
                'whatsapp_enabled' => 'whatsapp_enabled_computer',
                'whatsapp_number' => 'whatsapp_number_computer',
                'return_policy' => 'return_policy_computer',
            ],
            default => throw new InvalidArgumentException('Unsupported department supplied.'),
        };
    }

    private function departmentLabel(string $department): string
    {
        return __('departments.' . $department);
    }

    private function settingsRouteName(string $department, bool $generateUrl = false): string
    {
        $route = match ($department) {
            DepartmentReportService::DEPARTMENT_SHEIN => 'item.shein.settings',
            DepartmentReportService::DEPARTMENT_COMPUTER => 'item.computer.settings',
            default => throw new InvalidArgumentException('Unsupported department supplied.'),
        };

        return $generateUrl ? route($route) : $route;
    }

    private function settingsUpdateRouteName(string $department, bool $generateUrl = false): string
    {
        $route = match ($department) {
            DepartmentReportService::DEPARTMENT_SHEIN => 'item.shein.settings.update',
            DepartmentReportService::DEPARTMENT_COMPUTER => 'item.computer.settings.update',
            default => throw new InvalidArgumentException('Unsupported department supplied.'),
        };

        return $generateUrl ? route($route) : $route;
    }

    private function permissionForDepartment(string $department): string
    {
        return match ($department) {
            DepartmentReportService::DEPARTMENT_SHEIN => 'shein-products-update',
            DepartmentReportService::DEPARTMENT_COMPUTER => 'computer-ads-update',
            default => throw new InvalidArgumentException('Unsupported department supplied.'),
        };
    }

    private function advertiserRouteName(string $department, bool $generateUrl = false): string
    {
        $route = match ($department) {
            DepartmentReportService::DEPARTMENT_SHEIN => 'item.shein.advertiser.update',
            DepartmentReportService::DEPARTMENT_COMPUTER => 'item.computer.advertiser.update',
            default => throw new InvalidArgumentException('Unsupported department supplied.'),
        };

        return $generateUrl ? route($route) : $route;
    }

    private function settingsArray(): array
    {
        $settings = CachingService::getSystemSettings();

        if ($settings instanceof Collection) {
            return $settings->toArray();
        }

        if ($settings instanceof ArrayAccess) {
            return (array) $settings;
        }

        if (is_array($settings)) {
            return $settings;
        }

        return [];
    }

    private function toFloat(mixed $value): ?float
    {
        if ($value === null || $value === '') {
            return null;
        }

        if (is_numeric($value)) {
            return (float) $value;
        }

        if (is_string($value)) {
            $filtered = trim($value);
            if ($filtered === '') {
                return null;
            }
            if (is_numeric($filtered)) {
                return (float) $filtered;
            }
        }

        return null;
    }

    private function ratioToPercentage(float $ratio): float
    {
        if ($ratio <= 1.0) {
            return round($ratio * 100, 2);
        }

        return round($ratio, 2);
    }

    private function toBoolean(mixed $value): bool
    {
        return filter_var($value, FILTER_VALIDATE_BOOLEAN);
    }
}