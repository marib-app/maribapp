<?php

namespace App\Http\Controllers;

use App\Models\RequestDevice;
use App\Services\ResponseService;
use Carbon\Carbon;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\View\View;

abstract class SectionedRequestDeviceController extends Controller
{
    protected string $section;
    protected string $indexPermission;
    protected string $deletePermission;
    protected string $indexRouteName;
    protected string $showRouteName;
    protected string $destroyRouteName;
    protected string $viewNamespace;
    protected string $indexPageTitle;
    protected string $detailPageTitle;

    public function index(Request $request): View
    {
        ResponseService::noAnyPermissionThenRedirect([$this->indexPermission]);

        $requests = $this->buildFilteredQuery($request);

        $stats = $this->buildStats();

        return view($this->resolveView('index'), [
            'requests' => $requests,
            'stats' => $stats,
            'titles' => [
                'index' => $this->indexPageTitle,
                'detail' => $this->detailPageTitle,
            ],
            'routes' => [
                'index' => $this->indexRouteName,
                'show' => $this->showRouteName,
                'destroy' => $this->destroyRouteName,
            ],
        ]);
    }

    public function show(int $id): View
    {
        ResponseService::noAnyPermissionThenRedirect([$this->indexPermission]);

        $requestDevice = $this->findRequestOrFail($id);

        return view($this->resolveView('show'), [
            'request' => $requestDevice,
            'titles' => [
                'index' => $this->indexPageTitle,
                'detail' => $this->detailPageTitle,
            ],
            'routes' => [
                'index' => $this->indexRouteName,
                'destroy' => $this->destroyRouteName,
            ],
        ]);
    }

    public function destroy(int $id): RedirectResponse
    {
        ResponseService::noAnyPermissionThenRedirect([$this->deletePermission]);

        $requestDevice = $this->findRequestOrFail($id);
        $requestDevice->delete();

        return redirect()->route($this->indexRouteName)
            ->with('success', 'تم حذف الطلب بنجاح');
    }

    protected function resolveView(string $view): string
    {
        return $this->viewNamespace . '.' . $view;
    }

    protected function buildFilteredQuery(Request $request): LengthAwarePaginator
    {
        $query = $this->newSectionQuery()->orderByDesc('created_at');

        if ($request->filled('phone')) {
            $query->where('phone', 'like', '%' . $request->input('phone') . '%');
        }

        if ($request->filled('subject')) {
            $query->where('subject', 'like', '%' . $request->input('subject') . '%');
        }

        $requests = $query->paginate(10);
        $requests->appends($request->all());

        return $requests;
    }

    protected function buildStats(): array
    {
        $baseQuery = $this->newSectionQuery();

        return [
            'total' => (clone $baseQuery)->count(),
            'today' => (clone $baseQuery)->whereDate('created_at', Carbon::today())->count(),
            'week' => (clone $baseQuery)->whereBetween('created_at', [
                Carbon::now()->startOfWeek(),
                Carbon::now()->endOfWeek(),
            ])->count(),
        ];
    }

    protected function findRequestOrFail(int $id): RequestDevice
    {
        return $this->newSectionQuery()->findOrFail($id);
    }

    protected function newSectionQuery(): Builder
    {
        return RequestDevice::query()->where('section', $this->section);
    }
}