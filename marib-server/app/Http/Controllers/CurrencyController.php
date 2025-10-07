<?php

namespace App\Http\Controllers;

use App\Models\CurrencyRate;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class CurrencyController extends Controller
{
    public function index()
    {
        $currencies = CurrencyRate::latest()->get();
        return view('currency.index', compact('currencies'));
    }

    public function create()
    {
        return view('currency.create');
    }

    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'currency_name' => 'required|string|max:255|unique:currency_rates',
            'sell_price' => 'required|numeric|min:0',
            'buy_price' => 'required|numeric|min:0'
        ]);

        if ($validator->fails()) {
            return response()->json(['errors' => $validator->errors()], 422);
        }

        $currency = CurrencyRate::create([
            'currency_name' => $request->currency_name,
            'sell_price' => $request->sell_price,
            'buy_price' => $request->buy_price,
            'last_updated_at' => now()
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Currency rate created successfully',
            'data' => $currency
        ]);
    }

    public function edit($id)
    {
        $currency = CurrencyRate::findOrFail($id);
        return view('currency.edit', compact('currency'));
    }

    public function update(Request $request, $id)
    {
        $currency = CurrencyRate::findOrFail($id);

        $validator = Validator::make($request->all(), [
            'currency_name' => 'required|string|max:255|unique:currency_rates,currency_name,' . $id,
            'sell_price' => 'required|numeric|min:0',
            'buy_price' => 'required|numeric|min:0'
        ]);

        if ($validator->fails()) {
            return response()->json(['errors' => $validator->errors()], 422);
        }

        $currency->update([
            'currency_name' => $request->currency_name,
            'sell_price' => $request->sell_price,
            'buy_price' => $request->buy_price,
            'last_updated_at' => now()
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Currency rate updated successfully',
            'data' => $currency
        ]);
    }

    public function destroy($id)
    {
        $currency = CurrencyRate::findOrFail($id);
        $currency->delete();

        return response()->json([
            'success' => true,
            'message' => 'Currency rate deleted successfully'
        ]);
    }

    public function show()
    {
        $offset = request('offset', 0);
        $limit = request('limit', 10);
        $search = request('search', '');
        $sort = request('sort', 'id');
        $order = request('order', 'desc');

        $query = CurrencyRate::query();

        if (!empty($search)) {
            $query->where(function($q) use ($search) {
                $q->where('currency_name', 'like', '%' . $search . '%')
                  ->orWhere('sell_price', 'like', '%' . $search . '%')
                  ->orWhere('buy_price', 'like', '%' . $search . '%');
            });
        }

        $total = $query->count();

        $currencies = $query->orderBy($sort, $order)
                           ->offset($offset)
                           ->limit($limit)
                           ->get()
                           ->map(function ($currency) {
                               $currency->last_updated_at = $currency->last_updated_at ? $currency->last_updated_at->format('Y-m-d H:i:s') : null;
                               return $currency;
                           });

        return response()->json([
            'total' => $total,
            'rows' => $currencies
        ]);
    }
}