<?php

namespace App\Http\Controllers;

use App\Models\Governorate;
use App\Services\ResponseService;
use Illuminate\Contracts\View\View;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Str;
use Symfony\Component\HttpFoundation\Response;
use Throwable;

class GovernorateController extends Controller
{
    public function index(): View
    {
        ResponseService::noAnyPermissionThenRedirect([
            'governorate-list',
            'governorate-create',
            'governorate-edit',
            'governorate-delete',
        ]);

        $governorates = Governorate::query()
            ->orderBy('name')
            ->paginate(20);

        return view('governorates.index', compact('governorates'));
    }

    public function create(): View
    {
        ResponseService::noPermissionThenRedirect('governorate-create');

        $governorates = Governorate::query()
            ->orderBy('name')
            ->get();

        return view('governorates.create', compact('governorates'));
    }

    public function store(Request $request)
    {
        $this->ensurePermission($request, 'governorate-create');

        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'code' => ['required', 'string', 'max:20', 'unique:governorates,code'],
            'is_active' => ['nullable', 'boolean'],
        ]);

        $payload = [
            'name' => $validated['name'],
            'code' => Str::upper($validated['code']),
            'is_active' => $request->boolean('is_active', true),
        ];

        $governorate = Governorate::create($payload);

        if ($request->expectsJson()) {
            return $this->jsonGovernorateResponse($governorate, Response::HTTP_CREATED);
        }

        return ResponseService::successRedirectResponse(__('Governorate created successfully.'), route('governorates.index'));
    }

    public function edit(Governorate $governorate): View
    {
        ResponseService::noPermissionThenRedirect('governorate-edit');

        $governorates = Governorate::query()
            ->orderBy('name')
            ->get();

        return view('governorates.edit', compact('governorate', 'governorates'));
    }

    public function update(Request $request, Governorate $governorate)
    {
        $this->ensurePermission($request, 'governorate-edit');

        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'code' => ['required', 'string', 'max:20', 'unique:governorates,code,' . $governorate->id],
            'is_active' => ['nullable', 'boolean'],
        ]);

        $payload = [
            'name' => $validated['name'],
            'code' => Str::upper($validated['code']),
            'is_active' => $request->boolean('is_active', true),
        ];

        $governorate->update($payload);

        if ($request->expectsJson()) {
            return $this->jsonGovernorateResponse($governorate);
        }

        return ResponseService::successRedirectResponse(__('Governorate updated successfully.'), route('governorates.index'));
    }

    public function destroy(Request $request, Governorate $governorate)
    {
        $this->ensurePermission($request, 'governorate-delete');

        try {
            $governorate->delete();
        } catch (Throwable $exception) {
            if ($request->expectsJson()) {
                return response()->json([
                    'success' => false,
                    'message' => __('Unable to delete governorate at this time.'),
                ], Response::HTTP_INTERNAL_SERVER_ERROR);
            }

            ResponseService::logErrorRedirect($exception, 'GovernorateController::destroy');

            return ResponseService::errorRedirectResponse(__('Unable to delete governorate at this time.'), route('governorates.index'));
        }

        if ($request->expectsJson()) {
            return response()->json([
                'success' => true,
                'message' => __('Governorate deleted successfully.'),
                'governorates' => $this->governorateCollection(),
            ]);
        }

        return ResponseService::successRedirectResponse(__('Governorate deleted successfully.'), route('governorates.index'));
    }

    private function ensurePermission(Request $request, string $permission): void
    {
        if ($request->expectsJson()) {
            ResponseService::noPermissionThenSendJson($permission);

            return;
        }

        ResponseService::noPermissionThenRedirect($permission);
    }

    private function jsonGovernorateResponse(Governorate $governorate, int $status = Response::HTTP_OK): JsonResponse
    {
        $governorate->refresh();

        return response()->json([
            'success' => true,
            'message' => $status === Response::HTTP_CREATED
                ? __('Governorate created successfully.')
                : __('Governorate updated successfully.'),
            'governorate' => [
                'id' => $governorate->id,
                'name' => $governorate->name,
                'code' => $governorate->code,
                'is_active' => $governorate->is_active,
            ],
            'governorates' => $this->governorateCollection(),
        ], $status);
    }

    private function governorateCollection(): array
    {
        return Governorate::query()
            ->orderBy('name')
            ->get(['id', 'name', 'code', 'is_active'])
            ->map(fn (Governorate $governorate) => [
                'id' => $governorate->id,
                'name' => $governorate->name,
                'code' => $governorate->code,
                'is_active' => $governorate->is_active,
            ])
            ->all();
    }
}