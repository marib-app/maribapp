<?php

namespace App\Http\Controllers;


use App\Models\User;
use App\Services\DelegateAuthorizationService;
use App\Services\ResponseService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Validator;
use Throwable;

class DelegateController extends Controller
{

    
    public function __construct(protected DelegateAuthorizationService $delegateAuthorizationService)
    {
    }




    public function sheinIndex(Request $request)
    {
        ResponseService::noAnyPermissionThenRedirect(['shein-products-list', 'shein-products-update']);

        return $this->renderDelegatesPage(
            $request,
            'items.shein.delegates',
            'shein-products',
            __('إدارة مندوبي شي إن'),
            'shein'
        );
    }

    public function sheinUpdate(Request $request)
    {
        ResponseService::noAnyPermissionThenRedirect(['shein-products-update']);

        return $this->handleDelegatesUpdate($request, 'item.shein.delegates', 'shein');
    }

    public function computerIndex(Request $request)
    {
        ResponseService::noAnyPermissionThenRedirect(['computer-ads-list', 'computer-ads-update']);

        return $this->renderDelegatesPage(
            $request,
            'items.computer.delegates',
            'computer-ads',
            __('إدارة مندوبي قسم الكمبيوتر'),
            'computer'
        );
    }

    public function computerUpdate(Request $request)
    {
        ResponseService::noAnyPermissionThenRedirect(['computer-ads-update']);

        return $this->handleDelegatesUpdate($request, 'item.computer.delegates', 'computer');
    }

    protected function renderDelegatesPage(Request $request, string $view, string $permissionPrefix, string $pageTitle, string $section)
    {
        $search = trim((string) $request->get('search'));


        $usersQuery = User::role('User')
            ->select(['id', 'name', 'mobile'])


            ->whereNull('deleted_at')

            ->orderBy('name');

        if ($search !== '') {
            $usersQuery->where(function ($query) use ($search) {
                $query->where('name', 'like', '%' . $search . '%')
                    ->orWhere('mobile', 'like', '%' . $search . '%');

                if (ctype_digit($search)) {
                    $query->orWhere('id', (int) $search);
                }
            });
        }

        $users = $usersQuery->get();

        $delegateIds = $this->delegateAuthorizationService->getDelegatesForSection($section);

        $delegateIds = array_values(array_intersect($delegateIds, $users->pluck('id')->all()));

        $canUpdate = Auth::user()?->can($permissionPrefix . '-update') ?? false;

        return view($view, [
            'users'            => $users,
            'delegateIds'      => $delegateIds,
            'search'           => $search,
            'canUpdate'        => $canUpdate,
            'pageTitle'        => $pageTitle,
            'section'          => $section,
            'permissionPrefix' => $permissionPrefix,
        ]);
    }

    protected function handleDelegatesUpdate(Request $request, string $redirectRoute, string $section)
    {
        $validator = Validator::make($request->all(), [
            'delegates'   => ['nullable', 'array'],
            'delegates.*' => ['integer', 'exists:users,id'],
        ]);

        if ($validator->fails()) {
            if ($request->expectsJson()) {
                return response()->json([
                    'success' => false,
                    'message' => $validator->errors()->first(),
                    'errors'  => $validator->errors(),
                ], 422);
            }

            return redirect()->back()->withErrors($validator)->withInput();

        }

        try {

            $selectedIds = collect($request->input('delegates', []))
                ->filter()
                ->map(static fn($id) => (int) $id)
                ->unique();

            $this->storeDelegatesForSection($section, $selectedIds->values()->toArray());

        } catch (Throwable $throwable) {
            report($throwable);


            if ($request->expectsJson()) {
                return response()->json([
                    'success' => false,
                    'message' => __('تعذر تحديث قائمة المندوبين.'),
                ], 500);
            }



            return redirect()->back()->withErrors([
                'message' => __('تعذر تحديث قائمة المندوبين.')
            ]);
        }

        $message = __('تم تحديث قائمة المندوبين بنجاح.');

        if ($request->expectsJson()) {
            return response()->json([
                'success'   => true,
                'message'   => $message,
                'delegates' => $selectedIds->values()->toArray(),
            
            
            ]);
        }

        return redirect()->route($redirectRoute)->with('success', $message);
    }


    protected function storeDelegatesForSection(string $section, array $delegateIds): void
    {
        $this->delegateAuthorizationService->storeDelegatesForSection($section, $delegateIds);

    }
}