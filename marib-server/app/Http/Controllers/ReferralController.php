<?php

namespace App\Http\Controllers;

use App\Models\Referral;
use App\Models\User;
use App\Models\Challenge;
use Illuminate\Http\Request;
use App\Models\ReferralAttempt;

class ReferralController extends Controller
{
    public function index()
    {
        return view('referrals.index');
    }

    public function list(Request $request)
    {
        $offset = max(0, (int) ($request->offset ?? 0));
        $limit = $request->limit ?? 10;
        $sort = $request->sort ?? 'created_at';
        $order = strtolower($request->order ?? 'desc');
        $search = trim((string) $request->search);
        $challengeId = $request->challenge_id;
        $status = $request->status;

        if (!in_array($order, ['asc', 'desc'], true)) {
            $order = 'desc';
        }


        $sortColumns = [
            'id' => 'referrals.id',
            'referrer.name' => 'referrers.name',
            'referred_user.name' => 'referred_users.name',
            'challenge.title' => 'challenges.title',
            'points' => 'referrals.points',
            'created_at' => 'referrals.created_at',
        ];

        $sortColumn = $sortColumns[$sort] ?? 'referrals.created_at';

        $query = Referral::query()
            ->select('referrals.*')
            ->with(['referrer:id,name', 'referred_user:id,name', 'challenge:id,title'])
            ->leftJoin('users as referrers', 'referrers.id', '=', 'referrals.referrer_id')
            ->leftJoin('users as referred_users', 'referred_users.id', '=', 'referrals.referred_user_id')
            ->leftJoin('challenges', 'challenges.id', '=', 'referrals.challenge_id');

        if ($search !== '') {
            $query->where(function ($q) use ($search) {
                $like = "%{$search}%";
                $q->where('referrers.name', 'like', $like)
                    ->orWhere('referred_users.name', 'like', $like)
                    ->orWhere('referrals.id', 'like', $like);
            });
        }

        if (!empty($challengeId)) {
            $query->where('referrals.challenge_id', $challengeId);
        }

        if ($request->filled('status')) {
            $query->whereHas('attempts', function ($attemptQuery) use ($status) {
                $attemptQuery->where('status', $status);
            });
        }

        $total = (clone $query)->distinct('referrals.id')->count('referrals.id');

        $query->orderBy($sortColumn, $order);

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