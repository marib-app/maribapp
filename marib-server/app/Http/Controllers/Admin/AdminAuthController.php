<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Services\ResponseService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Validation\ValidationException;

class AdminAuthController extends Controller
{
    /**
     * Handle admin login and issue Sanctum token.
     */
    public function login(Request $request)
    {
        $credentials = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string', 'min:6'],
        ]);

        if (!Auth::attempt($credentials)) {
            ResponseService::errorResponse(
                __('بيانات تسجيل الدخول غير صحيحة'),
                null,
                config('constants.RESPONSE_CODE.INVALID_LOGIN')
            );
        }

        /** @var User $user */
        $user = Auth::user();

        if ($this->userLacksAdminAccess($user)) {
            Auth::logout();
            ResponseService::errorResponse(
                __('لا تملك صلاحية للوصول إلى لوحة الإدارة.'),
                null,
                config('constants.RESPONSE_CODE.UNAUTHORIZED_ACCESS')
            );
        }

        $token = $user->createToken('admin_app', ['admin:full'])->plainTextToken;

        // logout from the session guard to avoid mixing web/API contexts
        Auth::logout();

        ResponseService::successResponse('تم تسجيل الدخول بنجاح', [
            'token' => $token,
            'abilities' => ['admin:full'],
            'user' => $this->transformUser($user),
        ], config('constants.RESPONSE_CODE.LOGIN_SUCCESS'));
    }

    /**
     * Return the authenticated admin profile.
     */
    public function me(Request $request)
    {
        /** @var User $user */
        $user = $request->user();

        ResponseService::successResponse('success', [
            'user' => $this->transformUser($user),
        ]);
    }

    /**
     * Revoke the current token.
     */
    public function logout(Request $request)
    {
        $token = $request->user()->currentAccessToken();
        if ($token) {
            $token->delete();
        }

        ResponseService::successResponse('تم تسجيل الخروج بنجاح');
    }

    private function userLacksAdminAccess(User $user): bool
    {
        // Any staff/super roles may be allowed; plain "User" role should be blocked.
        if ($user->hasRole('User') && !$user->hasAnyRole(['Super Admin', 'Admin'])) {
            return true;
        }

        return false;
    }

    private function transformUser(User $user): array
    {
        return [
            'id' => $user->id,
            'name' => $user->name,
            'email' => $user->email,
            'mobile' => $user->mobile,
            'roles' => $user->getRoleNames(),
            'permissions' => $user->getPermissionNames(),
            'account_type' => $user->account_type,
            'avatar' => $user->profile,
        ];
    }
}
