<?php

namespace App\Http\Controllers;

use App\Models\Referral;
use App\Models\User;
use App\Models\Challenge;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use App\Models\ReferralAttempt;

class ReferralController extends Controller
{
    public function index()
    {
        return view('referrals.index');
    }

    public function list(Request $request)
    {
        $offset = $request->offset ?? 0;
        $limit = $request->limit ?? 10;
        $sort = $request->sort ?? 'id';
        $order = $request->order ?? 'desc';
        $search = $request->search;
        $challengeId = $request->challenge_id;

        $query = Referral::with(['referrer:id,name', 'referred_user:id,name', 'challenge:id,title']);

        if ($search) {
            $query->whereHas('referrer', function ($q) use ($search) {
                $q->where('name', 'like', "%$search%");
            })->orWhereHas('referred_user', function ($q) use ($search) {
                $q->where('name', 'like', "%$search%");
            });
        }

        if ($challengeId) {
            $query->where('challenge_id', $challengeId);
        }

        $total = $query->count();
        $rows = $query->orderBy($sort, $order)
            ->skip($offset)
            ->take($limit)
            ->get();

        return response()->json([
            'total' => $total,
            'rows' => $rows,
        ]);
    }



    public function attempts(Request $request)
    {
        $offset = (int) ($request->offset ?? 0);
        $limit = $request->limit ?? 10;
        $sort = $request->sort ?? 'created_at';
        $order = strtolower($request->order ?? 'desc');
        $status = $request->status;
        $referrerId = $request->referrer_id;
        $search = $request->search;

        $allowedSorts = ['id', 'code', 'status', 'created_at', 'referrer_id', 'referred_user_id'];

        if (!in_array($sort, $allowedSorts, true)) {
            $sort = 'created_at';
        }

        if (!in_array($order, ['asc', 'desc'], true)) {
            $order = 'desc';
        }

        $query = ReferralAttempt::with([
            'referrer:id,name',
            'referredUser:id,name',
            'referral:id,referrer_id,referred_user_id',
            'challenge:id,title',
        ]);

        if (!empty($status)) {
            $query->where('status', $status);
        }

        if (!empty($referrerId)) {
            $query->where('referrer_id', $referrerId);
        }

        if (!empty($search)) {
            $query->where(function ($q) use ($search) {
                $q->where('code', 'like', "%{$search}%")
                    ->orWhereHas('referrer', function ($referrerQuery) use ($search) {
                        $referrerQuery->where('name', 'like', "%{$search}%");
                    })
                    ->orWhereHas('referredUser', function ($referredQuery) use ($search) {
                        $referredQuery->where('name', 'like', "%{$search}%");
                    });
            });
        }

        $total = (clone $query)->count();

        $query->orderBy($sort, $order);

        if ($limit !== 'all') {
            $limitValue = is_numeric($limit) ? (int) $limit : 10;
            $query->skip($offset)->take($limitValue);
        }

        $rows = $query->get();

        return response()->json([
            'total' => $total,
            'rows' => $rows,
        ]);
    }


    public function topUsers()
    {
        $topUsers = User::select('users.id', 'users.name')
            ->selectRaw('COUNT(DISTINCT referrals.referred_user_id) as total_referrals')
            ->selectRaw('SUM(referrals.points) as total_points')
            ->selectRaw('COUNT(DISTINCT CASE WHEN referrals.challenge_id IS NOT NULL THEN referrals.challenge_id END) as completed_challenges')
            ->leftJoin('referrals', 'users.id', '=', 'referrals.referrer_id')
            ->groupBy('users.id', 'users.name')
            ->orderBy('total_points', 'desc')
            ->orderBy('total_referrals', 'desc')
            ->get()
            ->map(function ($user, $index) {
                $user->rank = $index + 1;
                return $user;
            });

        return response()->json([
            'total' => count($topUsers),
            'rows' => $topUsers
        ]);
    }

    public function generateReferralCode()
    {
        do {
            $code = strtoupper(substr(md5(uniqid()), 0, 8));
        } while (User::where('referral_code', $code)->exists());

        return $code;
    }
}