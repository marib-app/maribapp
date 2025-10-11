<?php

namespace App\Http\Controllers;


use App\Models\User;
use App\Events\DelegateAssignmentsUpdated;
use App\Models\DepartmentDelegateAudit;
use App\Services\DelegateAuthorizationService;
use App\Services\ResponseService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Validator;
use Throwable;
use Illuminate\Pagination\LengthAwarePaginator;
use Illuminate\Support\Str;

class DelegateController extends Controller
{

        protected const PER_PAGE = 25;
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

        $state = $this->delegateAuthorizationService->getSectionState($section);

        $users = $this->buildUsersPaginator($request, $search);
        $visibleIds = collect($users->items())
            ->map(static fn ($user) => $user instanceof User ? $user->getKey() : null)
            ->filter()
            ->values()
            ->all();

        $canUpdate = Auth::user()?->can($permissionPrefix . '-update') ?? false;

        return view($view, [
            'users'                => $users,
            'delegateIds'          => $state['ids'],
            'preservedDelegateIds' => array_values(array_diff($state['ids'], $visibleIds)),
            'delegateVersion'      => $state['version'],
            'search'               => $search,
            'searchPerformed'      => $search !== '',
            'canUpdate'            => $canUpdate,
            'pageTitle'            => $pageTitle,
            'section'              => $section,
            'permissionPrefix'     => $permissionPrefix,
        ]);
    }

    protected function buildUsersPaginator(Request $request, string $search): LengthAwarePaginator
    {
        if ($search === '') {
            return new LengthAwarePaginator(
                collect(),
                0,
                self::PER_PAGE,
                max((int) $request->integer('page', 1), 1),
                [
                    'path'  => $request->url(),
                    'query' => $request->query(),
                ]
            );
        }

        $usersQuery = User::role('User')
            ->select(['id', 'name', 'mobile'])
            ->whereNull('deleted_at')
            ->where(function ($query) use ($search) {


                $query->where('name', 'like', '%' . $search . '%')
                    ->orWhere('mobile', 'like', '%' . $search . '%');

                if (ctype_digit($search)) {
                    $query->orWhere('id', (int) $search);
                }
            })
            ->orderBy('name');

        return $usersQuery
            ->paginate(self::PER_PAGE)
            ->appends(['search' => $search]);
    }

    protected function handleDelegatesUpdate(Request $request, string $redirectRoute, string $section)
    {
        $validator = Validator::make($request->all(), [
            'delegates'   => ['nullable', 'array'],
            'delegates.*' => ['integer', 'exists:users,id'],
            'reason'      => ['nullable', 'string', 'max:255'],
            'version'     => ['required', 'string'],
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

        $state = $this->delegateAuthorizationService->getSectionState($section);
        $expectedVersion = (string) $request->input('version');

        if ($expectedVersion !== $state['version']) {
            $message = __('تم تعديل قائمة المندوبين بواسطة مستخدم آخر. يرجى إعادة تحميل الصفحة قبل الحفظ.');

            if ($request->expectsJson()) {
                return response()->json([
                    'success'          => false,
                    'message'          => $message,
                    'code'             => 'conflict',
                    'current_version'  => $state['version'],
                    'current_delegates' => $state['ids'],
                ], 409);
            }

            return redirect()->back()
                ->withErrors(['version' => $message])
                ->withInput($request->all())
                ->with('delegate_version', $state['version']);
        }

        $selectedIds = collect($request->input('delegates', []))
            ->filter()
            ->map(static fn ($id) => (int) $id)
            ->unique()
            ->values();

        $currentIds = collect($state['ids']);

        $addedIds = $selectedIds->diff($currentIds)->values();
        $removedIds = $currentIds->diff($selectedIds)->values();

        $reason = Str::of((string) $request->input('reason'))->trim()->toString();

        $differenceIds = [
            'added'   => $addedIds->all(),
            'removed' => $removedIds->all(),
        ];

        $differenceDetails = [
            'added'   => [],
            'removed' => [],
        ];

        if (! empty($differenceIds['added']) || ! empty($differenceIds['removed'])) {
            $affectedUsers = User::query()
                ->select(['id', 'name', 'mobile'])
                ->with(['fcm_tokens:id,user_id,fcm_token'])
                ->whereIn('id', array_unique(array_merge($differenceIds['added'], $differenceIds['removed'])))
                ->get()
                ->keyBy('id');

            $assignedUsers = collect($differenceIds['added'])
                ->map(static fn ($id) => $affectedUsers->get($id))
                ->filter()
                ->values();

            $removedUsers = collect($differenceIds['removed'])
                ->map(static fn ($id) => $affectedUsers->get($id))
                
                
                ->filter()
                ->values();

            $differenceDetails = [
                'added'   => $assignedUsers->map(fn (User $user) => $this->transformDifferenceUser($user))->all(),
                'removed' => $removedUsers->map(fn (User $user) => $this->transformDifferenceUser($user))->all(),
            ];
        } else {
            $assignedUsers = collect();
            $removedUsers = collect();
        }

        if ($assignedUsers->isEmpty() && $removedUsers->isEmpty()) {
            $message = __('لم يتم العثور على تغييرات لحفظها.');

            if ($request->expectsJson()) {
                return response()->json([
                    'success'     => true,
                    'message'     => $message,
                    'delegates'   => $selectedIds->all(),
                    'difference'  => $differenceDetails,
                    'reason'      => $reason,
                    'version'     => $state['version'],
                ]);
            }

            return redirect()->route($redirectRoute)
                ->with('success', $message)
                ->with('difference', $differenceDetails)
                ->with('delegate_version', $state['version'])
                ->with('delegate_reason', $reason);
        }

        try {
            $this->storeDelegatesForSection($section, $selectedIds->all());

            $this->recordDelegateAudit($request->user(), $section, $differenceDetails, $reason);

            DelegateAssignmentsUpdated::dispatch(
                $request->user(),
                $section,
                $assignedUsers,
                $removedUsers,
                $differenceDetails,
                $reason
            );


        } catch (Throwable $throwable) {
            report($throwable);


            if ($request->expectsJson()) {
                return response()->json([
                    'success' => false,
                    'message' => __('تعذر تحديث قائمة المندوبين.'),
                ], 500);
            }



            return redirect()->back()->withErrors([
                'message' => __('تعذر تحديث قائمة المندوبين.'),
            ]);
        }
        $newState = $this->delegateAuthorizationService->getSectionState($section);

        $message = __('تم تحديث قائمة المندوبين بنجاح.');

        if ($request->expectsJson()) {
            return response()->json([
                'success'    => true,
                'message'    => $message,
                'delegates'  => $selectedIds->all(),
                'difference' => $differenceDetails,
                'reason'     => $reason,
                'version'    => $newState['version'],
            
            
            ]);
        }
        return redirect()->route($redirectRoute)
            ->with('success', $message)
            ->with('difference', $differenceDetails)
            ->with('delegate_version', $newState['version'])
            ->with('delegate_reason', $reason);
    }


    protected function transformDifferenceUser(User $user): array
    {
        return [
            'id'     => $user->getKey(),
            'name'   => $user->name,
            'mobile' => $user->mobile,
        ];
    }

    protected function recordDelegateAudit(?User $actor, string $section, array $difference, string $reason): void
    {
        $actorId = $actor?->getKey();
        $reasonValue = $reason !== '' ? $reason : null;

        if (! empty($difference['added'])) {
            DepartmentDelegateAudit::create([
                'department' => $section,
                'actor_id'   => $actorId,
                'event'      => DepartmentDelegateAudit::EVENT_ASSIGNED,
                'reason'     => $reasonValue,
                'difference' => [
                    'users' => $difference['added'],
                ],
            ]);
        }

        if (! empty($difference['removed'])) {
            DepartmentDelegateAudit::create([
                'department' => $section,
                'actor_id'   => $actorId,
                'event'      => DepartmentDelegateAudit::EVENT_REMOVED,
                'reason'     => $reasonValue,
                'difference' => [
                    'users' => $difference['removed'],
                ],
            ]);
        }
    }


    protected function storeDelegatesForSection(string $section, array $delegateIds): void
    {
        $this->delegateAuthorizationService->storeDelegatesForSection($section, $delegateIds);

    }
}