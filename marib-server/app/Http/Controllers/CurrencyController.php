<?php

namespace App\Http\Controllers;

use App\Services\CurrencyIconStorageService;
use Illuminate\Support\Facades\Auth;
use App\Models\CurrencyRate;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class CurrencyController extends Controller
{

        public function __construct(private readonly CurrencyIconStorageService $iconStorageService)
    {
    }

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
            'buy_price' => 'required|numeric|min:0',
            'icon' => 'nullable|image|mimes:jpg,jpeg,png,webp,svg|max:2048',
            'icon_alt' => 'nullable|string|max:255',
        
        ]);

        if ($validator->fails()) {
            return response()->json(['errors' => $validator->errors()], 422);
        }

        $data = [
            'currency_name' => $request->currency_name,
            'sell_price' => $request->sell_price,
            'buy_price' => $request->buy_price,
            'icon_alt' => $request->filled('icon_alt') ? $request->icon_alt : null,
            'last_updated_at' => now(),
        ];

        if ($request->hasFile('icon')) {
            $path = $this->iconStorageService->storeIcon($request->file('icon'));
            $data['icon_path'] = $path;
            $data['icon_uploaded_by'] = Auth::id();
            $data['icon_uploaded_at'] = now();
            $data['icon_removed_by'] = null;
            $data['icon_removed_at'] = null;
        }

        $currency = CurrencyRate::create($data);

        return response()->json([
            'success' => true,
            'message' => 'Currency rate created successfully',
            'data' => $currency->fresh()

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
            'buy_price' => 'required|numeric|min:0',
            'icon' => 'nullable|image|mimes:jpg,jpeg,png,webp,svg|max:2048',
            'icon_alt' => 'nullable|string|max:255',
            'remove_icon' => 'sometimes|boolean',
        
        ]);

        if ($validator->fails()) {
            return response()->json(['errors' => $validator->errors()], 422);
        }

        $data = [

            'currency_name' => $request->currency_name,
            'sell_price' => $request->sell_price,
            'buy_price' => $request->buy_price,
            'icon_alt' => $request->filled('icon_alt') ? $request->icon_alt : null,
            'last_updated_at' => now(),
        ];

        if ($request->boolean('remove_icon')) {
            $this->iconStorageService->deleteIcon($currency->icon_path);
            $data['icon_path'] = null;
            $data['icon_alt'] = null;
            $data['icon_uploaded_by'] = null;
            $data['icon_uploaded_at'] = null;
            $data['icon_removed_by'] = Auth::id();
            $data['icon_removed_at'] = now();
        }

        if ($request->hasFile('icon')) {
            $path = $this->iconStorageService->storeIcon($request->file('icon'), $currency->icon_path);
            $data['icon_path'] = $path;
            $data['icon_uploaded_by'] = Auth::id();
            $data['icon_uploaded_at'] = now();
            $data['icon_removed_by'] = null;
            $data['icon_removed_at'] = null;
        }

        $currency->update($data);

        return response()->json([
            'success' => true,
            'message' => 'Currency rate updated successfully',
            'data' => $currency->fresh()

        ]);
    }

    public function destroy($id)
    {
        $currency = CurrencyRate::findOrFail($id);
        $this->iconStorageService->deleteIcon($currency->icon_path);


        $currency->delete();

        return response()->json([
            'success' => true,
            'message' => 'Currency rate deleted successfully'
        ]);
    }


    public function destroyIcon($id)
    {
        $currency = CurrencyRate::findOrFail($id);

        if (!$currency->icon_path) {
            return response()->json([
                'success' => true,
                'message' => 'Currency icon already removed',
                'data' => $currency->fresh(),
            ]);
        }

        $this->iconStorageService->deleteIcon($currency->icon_path);

        $currency->update([
            'icon_path' => null,
            'icon_alt' => null,
            'icon_uploaded_by' => null,
            'icon_uploaded_at' => null,
            'icon_removed_by' => Auth::id(),
            'icon_removed_at' => now(),
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Currency icon removed successfully',
            'data' => $currency->fresh(),
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
                               return [
                                   'id' => $currency->id,
                                   'currency_name' => $currency->currency_name,
                                   'sell_price' => $currency->sell_price,
                                   'buy_price' => $currency->buy_price,
                                   'icon_url' => $currency->icon_url,
                                   'icon_alt' => $currency->icon_alt,
                                   'last_updated_at' => $currency->last_updated_at ? $currency->last_updated_at->format('Y-m-d H:i:s') : null,
                               ];
                           });

        return response()->json([
            'total' => $total,
            'rows' => $currencies
        ]);
    }
}