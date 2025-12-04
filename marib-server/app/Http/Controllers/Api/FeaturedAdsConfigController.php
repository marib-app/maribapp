<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\FeaturedAdsConfig;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class FeaturedAdsConfigController extends Controller
{
    public function index(Request $request)
    {
        $query = FeaturedAdsConfig::query()->orderBy('position')->orderBy('id');

        if ($request->boolean('enabled_only')) {
            $query->where('enabled', true);
        }

        if ($request->filled('root_category_id')) {
            $query->where('root_category_id', $request->integer('root_category_id'));
        }

        if ($request->filled('interface_type')) {
            $query->where('interface_type', $request->input('interface_type'));
        }

        return response()->json([
            'data' => $query->get(),
        ]);
    }

    public function show(FeaturedAdsConfig $featuredAdsConfig)
    {
        return response()->json(['data' => $featuredAdsConfig]);
    }

    public function store(Request $request)
    {
        $data = $this->validateData($request);

        $config = FeaturedAdsConfig::create($data);

        return response()->json(['data' => $config], 201);
    }

    public function update(Request $request, FeaturedAdsConfig $featuredAdsConfig)
    {
        $data = $this->validateData($request, $featuredAdsConfig->id);

        $featuredAdsConfig->update($data);

        return response()->json(['data' => $featuredAdsConfig]);
    }

    public function destroy(FeaturedAdsConfig $featuredAdsConfig)
    {
        $featuredAdsConfig->delete();

        return response()->json(['data' => true]);
    }

    private function validateData(Request $request, ?int $id = null): array
    {
        return $request->validate([
            'name' => ['nullable', 'string', 'max:150'],
            'title' => ['nullable', 'string', 'max:150'],
            'root_category_id' => ['required', 'integer'],
            'interface_type' => ['nullable', 'string', 'max:100'],
            'root_identifier' => ['nullable', 'string', 'max:120'],
            'slug' => ['nullable', 'string', 'max:120'],
            'enabled' => ['sometimes', 'boolean'],
            'enable_ad_slider' => ['sometimes', 'boolean'],
            'style_key' => ['nullable', 'string', 'max:50'],
            'order_mode' => [
                'nullable',
                'string',
                Rule::in(['most_viewed', 'lowest_price', 'highest_price', 'premium', 'latest']),
            ],
            'position' => ['nullable', 'integer', 'min:0', 'max:9999'],
        ]);
    }
}
