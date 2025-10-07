<?php

namespace App\Http\Controllers;

use App\Models\Challenge;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use App\Services\ResponseService;

class ChallengeController extends Controller
{
    public function index()
    {
        return view('challenges.index');
    }

    public function list(Request $request)
    {
        $offset = $request->offset ?? 0;
        $limit = $request->limit ?? 10;
        $sort = $request->sort ?? 'id';
        $order = $request->order ?? 'desc';
        $search = $request->search;

        $query = Challenge::query();

        if ($search) {
            $query->where(function ($q) use ($search) {
                $q->where('title', 'like', "%$search%")
                    ->orWhere('description', 'like', "%$search%");
            });
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

    public function store(Request $request)
    {
        $validated = $request->validate([
            'title' => 'required|string|max:255',
            'description' => 'nullable|string',
            'required_referrals' => 'required|integer|min:0',
            'points_per_referral' => 'required|integer|min:0',
            'is_active' => 'boolean',
        ]);
        
        try {
            $challenge = Challenge::create($request->except('_token'));
        
    
            return redirect()->route('challenges.index')
                ->with('success', __('Challenge added successfully'));
        } catch (\Throwable $th) {
            return redirect()->route('challenges.index')
                ->with('error', __('Challenge added failed'));
        }
    }

    public function update(Request $request, Challenge $challenge)
    {
        $request->validate([
            'title' => 'required|string|max:255',
            'description' => 'nullable|string',
            'required_referrals' => 'required|integer|min:0',
            'points_per_referral' => 'required|integer|min:0',
            'is_active' => 'boolean',
        ]);

        $data = $request->all();
        if (!$request->has('is_active')) {
            $data['is_active'] = 0;
        }

        $challenge->update($data);

        if ($request->ajax()) {
            return response()->json(['success' => true, 'message' => __('Challenge updated successfully'), 'data' => $challenge]);
        }

        return redirect()->route('challenges.index')
            ->with('success', __('Challenge updated successfully'));
    }

    public function destroy(Challenge $challenge)
    {
        $challenge->delete();

        return redirect()->route('challenges.index')
            ->with('success', __('Challenge deleted successfully'));
    }


    public function edit(Challenge $challenge)
    {
   
        return response()->json($challenge);
    }
}