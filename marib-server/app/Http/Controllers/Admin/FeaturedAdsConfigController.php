<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\FeaturedAdsConfig;
use App\Services\InterfaceSectionService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\View\View;
use Illuminate\Validation\Rule;
use Illuminate\Support\Str;

class FeaturedAdsConfigController extends Controller
{
    private const SECTION_CHOICES = ['real_estate', 'computer', 'shein', 'public'];

    public function __construct()
    {
        $this->middleware(['auth']);
    }

    public function index(): View
    {
        $configs = FeaturedAdsConfig::query()
            ->orderBy('position')
            ->orderBy('id')
            ->get();

        return view('featured-ads-configs.index', compact('configs'));
    }

    public function create(): View
    {
        $config = new FeaturedAdsConfig([
            'enabled' => true,
            'enable_ad_slider' => true,
        ]);

        $sectionTypes = self::SECTION_CHOICES;

        return view('featured-ads-configs.form', [
            'config'        => $config,
            'sectionTypes'  => $sectionTypes,
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        $data = $this->validated($request);
        FeaturedAdsConfig::create($data);

        return redirect()
            ->route('featured-ads-configs.index')
            ->with('success', 'تم الحفظ بنجاح');
    }

    public function edit(FeaturedAdsConfig $featuredAdsConfig): View
    {
        return view('featured-ads-configs.form', [
            'config'       => $featuredAdsConfig,
            'sectionTypes' => self::SECTION_CHOICES,
        ]);
    }

    public function update(Request $request, FeaturedAdsConfig $featuredAdsConfig): RedirectResponse
    {
        $data = $this->validated($request);
        $featuredAdsConfig->update($data);

        return redirect()
            ->route('featured-ads-configs.index')
            ->with('success', 'تم التحديث بنجاح');
    }

    public function destroy(FeaturedAdsConfig $featuredAdsConfig): RedirectResponse
    {
        $featuredAdsConfig->delete();

        return redirect()
            ->route('featured-ads-configs.index')
            ->with('success', 'تم الحذف');
    }

    private function validated(Request $request): array
    {
        $data = $request->validate([
            'name'            => ['nullable', 'string', 'max:150'],
            'title'           => ['nullable', 'string', 'max:150'],
            'root_category_id'=> ['nullable', 'integer', 'min:1'],
            'interface_type'  => ['required', 'string', 'max:100', Rule::in(self::SECTION_CHOICES)],
            'enabled'         => ['sometimes', 'boolean'],
            'enable_ad_slider'=> ['sometimes', 'boolean'],
            'style_key'       => ['nullable', 'string', 'max:50'],
            'order_mode'      => [
                'required',
                'string',
                Rule::in(['most_viewed', 'lowest_price', 'highest_price', 'premium', 'latest']),
            ],
            'position'        => ['nullable', 'integer', 'min:0', 'max:9999'],
        ]);

        $sectionType = InterfaceSectionService::normalizeSectionType($data['interface_type'] ?? null);
        $data['interface_type'] = $sectionType;

        $rootIdentifiers = InterfaceSectionService::rootIdentifiers();
        $data['root_identifier'] = $rootIdentifiers[$sectionType] ?? null;

        $data['slug'] = Str::slug(
            $request->input('slug')
                ?: ($data['name'] ?: ($data['title'] ?: ($sectionType . '-' . ($data['order_mode'] ?? 'latest'))))
        );

        $data['enabled'] = $request->boolean('enabled');
        $data['enable_ad_slider'] = $request->boolean('enable_ad_slider');

        if (empty($data['root_category_id'])) {
            $data['root_category_id'] = null;
        }

        return $data;
    }
}
