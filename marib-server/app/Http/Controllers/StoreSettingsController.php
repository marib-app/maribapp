<?php

namespace App\Http\Controllers;

use App\Models\Setting;
use App\Models\StoreGateway;
use App\Models\StoreGatewayAccount;
use App\Models\StorefrontUiSetting;
use App\Models\Category;
use App\Services\CachingService;
use App\Services\FileService;
use App\Services\ResponseService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;
use Throwable;

class StoreSettingsController extends Controller
{
    public function index()
    {
        ResponseService::noPermissionThenRedirect('seller-store-settings-manage');

        $storeTerms = Setting::query()
            ->where('name', 'store_terms_conditions')
            ->value('value');

        $storeGateways = StoreGateway::query()
            ->withCount('accounts')
            ->orderBy('name')
            ->get();

        $storeRootId = config('cart.department_roots.store');
        $storeRootId = (int) env('CART_STORE_ROOT_CATEGORY_ID', 3);

        $allCategories = Category::query()
            ->select(['id', 'name', 'slug', 'parent_category_id'])
            ->orderBy('parent_category_id')
            ->orderBy('name')
            ->get();

        $storeCategoryIds = collect();
        if ($storeRootId) {
            // اجمع كل الأبناء (بعمق) للجذر المحدد
            $storeCategoryIds->push($storeRootId);
            $queue = [$storeRootId];
            while (!empty($queue)) {
                $current = array_shift($queue);
                $children = $allCategories
                    ->where('parent_category_id', $current)
                    ->pluck('id')
                    ->all();
                foreach ($children as $childId) {
                    if (!$storeCategoryIds->contains($childId)) {
                        $storeCategoryIds->push($childId);
                        $queue[] = $childId;
                    }
                }
            }
        }

        $categories = $storeCategoryIds->isNotEmpty()
            ? $allCategories->whereIn('id', $storeCategoryIds)
            : collect();

        $uiSetting = StorefrontUiSetting::query()->first();
        if (! $uiSetting) {
            $uiSetting = new StorefrontUiSetting([
                'enabled' => true,
                'featured_categories' => [],
                'promotion_slots' => [],
                'new_offers_items' => [],
                'discount_items' => [],
            ]);
        }

        return view('seller-store-settings.index', [
            'storeTerms'            => $storeTerms,
            'storeGateways'        => $storeGateways,
            'uiSetting'            => $uiSetting,
            'categories'           => $categories,
        ]);
    }

    public function storeTerms(Request $request)
    {
        ResponseService::noPermissionThenSendJson('seller-store-settings-manage');

        $validator = Validator::make($request->all(), [
            'store_terms_conditions' => 'required|string',
        ]);

        if ($validator->fails()) {
            ResponseService::validationError($validator->errors()->first());
        }

        try {
            $value = $validator->validated()['store_terms_conditions'];

            Setting::updateOrCreate(
                ['name' => 'store_terms_conditions'],
                ['value' => $value, 'type' => 'string']
            );

            CachingService::removeCache(config('constants.CACHE.SETTINGS'));

            ResponseService::successResponse(__('Store terms updated successfully'));
        } catch (Throwable $throwable) {
            ResponseService::logErrorResponse($throwable, 'StoreSettingsController -> storeTerms');
            ResponseService::errorResponse();
        }
    }

    public function storeUiSettings(Request $request)
    {
        ResponseService::noPermissionThenRedirect('seller-store-settings-manage');

        $validator = Validator::make($request->all(), [
            'enabled' => ['nullable', 'boolean'],
            'featured_categories' => ['nullable', 'string'],
            'promotion_slots' => ['nullable', 'string'],
            'new_offers_items' => ['nullable', 'string'],
            'discount_items' => ['nullable', 'string'],
        ]);

        if ($validator->fails()) {
            return back()->withErrors($validator)->withInput();
        }

        try {
            $data = $validator->validated();
            $featured = $this->decodeJsonField($data['featured_categories'] ?? '');
            $promotions = $this->decodeJsonField($data['promotion_slots'] ?? '');
            $newOffers = $this->decodeJsonField($data['new_offers_items'] ?? '');
            $discounts = $this->decodeJsonField($data['discount_items'] ?? '');

            StorefrontUiSetting::query()->updateOrCreate(
                ['id' => StorefrontUiSetting::query()->value('id')],
                [
                    'store_id' => null,
                    'enabled' => $request->boolean('enabled'),
                    'featured_categories' => $featured,
                    'promotion_slots' => $promotions,
                    'new_offers_items' => $newOffers,
                    'discount_items' => $discounts,
                ]
            );

            return redirect()
                ->route('seller-store-settings.index')
                ->with('success', __('Storefront UI settings updated.'));
        } catch (Throwable $throwable) {
            ResponseService::logErrorResponse($throwable, 'StoreSettingsController -> storeUiSettings', 'Error occurred while saving storefront UI settings.', false);

            return back()->withErrors([
                'message' => __('Failed to save storefront UI settings. Please check your JSON payloads and try again.'),
            ])->withInput();
        }
    }

    private function decodeJsonField(?string $raw): ?array
    {
        $raw = trim((string) $raw);
        if ($raw === '') {
            return [];
        }

        $decoded = json_decode($raw, true);
        if (json_last_error() !== JSON_ERROR_NONE) {
            throw new \InvalidArgumentException('Invalid JSON provided.');
        }

        return $decoded;
    }

    public function searchStoreItems(Request $request)
    {
        ResponseService::noPermissionThenSendJson('seller-store-settings-manage');

        $query = trim($request->get('q', ''));
        $limit = min(max((int) $request->get('limit', 20), 1), 50);

        $itemsQuery = \App\Models\Item::query()
            ->select(['id', 'name', 'thumbnail_url', 'image', 'interface_type', 'price'])
            ->where(function ($q) {
                $q->where('interface_type', 'e_store')
                    ->orWhere('interface_type', 'store');
            });

        if ($query !== '') {
            $itemsQuery->where('name', 'like', '%' . $query . '%');
        }

        $items = $itemsQuery
            ->orderByDesc('id')
            ->limit($limit)
            ->get()
            ->map(function ($item) {
                return [
                    'id' => $item->id,
                    'name' => $item->name,
                    'price' => $item->price,
                    'thumbnail' => $item->thumbnail_url ?: $item->image,
                ];
            });

        return response()->json([
            'data' => $items,
        ]);
    }


    public function gateways()
    {
        ResponseService::noPermissionThenRedirect('seller-store-settings-manage');

        $storeGateways = StoreGateway::query()
            ->with(['accounts.user'])
            ->orderBy('name')
            ->get();

        return view('seller-store-settings.gateways.index', [
            'storeGateways' => $storeGateways,
        ]);
    }

    public function createGateway()
    {
        ResponseService::noPermissionThenRedirect('seller-store-settings-manage');

        return view('seller-store-settings.gateways.create', [
            'storeGateway' => new StoreGateway(),
        ]);
    }

    public function storeGateway(Request $request)
    {
        ResponseService::noPermissionThenRedirect('seller-store-settings-manage');

        $validator = Validator::make($request->all(), [
            'name'      => ['required', 'string', 'max:255'],
            'logo'      => ['required', 'file', 'mimes:jpg,jpeg,png,svg,webp', 'max:2048'],
            'is_active' => ['nullable', 'boolean'],
        ]);

        if ($validator->fails()) {
            return back()->withErrors($validator)->withInput();
        }

        try {
            $data = $validator->validated();

            $logoPath = FileService::upload($request->file('logo'), 'store-gateways');

            StoreGateway::query()->create([
                'name'      => $data['name'],
                'logo_path' => $logoPath,
                'is_active' => $request->boolean('is_active'),
            ]);

            return redirect()
                ->route('seller-store-settings.gateways.index')
                ->with('success', __('Store gateway created successfully.'));
        } catch (Throwable $throwable) {
            ResponseService::logErrorResponse($throwable, 'StoreSettingsController -> storeGateway', 'Error occurred while creating store gateway.', false);

            return back()->withErrors([
                'message' => __('Failed to create store gateway. Please try again.'),
            ])->withInput();
        }
    }

    public function editGateway(StoreGateway $storeGateway)
    {
        ResponseService::noPermissionThenRedirect('seller-store-settings-manage');

        return view('seller-store-settings.gateways.edit', [
            'storeGateway' => $storeGateway,
        ]);
    }

    public function updateGateway(Request $request, StoreGateway $storeGateway)
    {
        ResponseService::noPermissionThenRedirect('seller-store-settings-manage');

        $validator = Validator::make($request->all(), [
            'name'      => ['required', 'string', 'max:255'],
            'logo'      => ['nullable', 'file', 'mimes:jpg,jpeg,png,svg,webp', 'max:2048'],
            'is_active' => ['nullable', 'boolean'],
        ]);

        if ($validator->fails()) {
            return back()->withErrors($validator)->withInput();
        }

        try {
            $data = $validator->validated();

            if ($request->hasFile('logo')) {
                $data['logo_path'] = FileService::replace($request->file('logo'), 'store-gateways', $storeGateway->logo_path);
            }

            $data['is_active'] = $request->boolean('is_active');
            unset($data['logo']);

            $storeGateway->update($data);

            return redirect()
                ->route('seller-store-settings.gateways.index')
                ->with('success', __('Store gateway updated successfully.'));
        } catch (Throwable $throwable) {
            ResponseService::logErrorResponse($throwable, 'StoreSettingsController -> updateGateway', 'Error occurred while updating store gateway.', false);

            return back()->withErrors([
                'message' => __('Failed to update store gateway. Please try again.'),
            ])->withInput();
        }
    }

    public function destroyGateway(StoreGateway $storeGateway)
    {
        ResponseService::noPermissionThenRedirect('seller-store-settings-manage');

        try {
            FileService::delete($storeGateway->logo_path);

            $storeGateway->delete();

            return redirect()
                ->route('seller-store-settings.gateways.index')
                ->with('success', __('Store gateway deleted successfully.'));
        } catch (Throwable $throwable) {
            ResponseService::logErrorResponse($throwable, 'StoreSettingsController -> destroyGateway', 'Error occurred while deleting store gateway.', false);

            return back()->withErrors([
                'message' => __('Failed to delete store gateway. Please try again.'),
            ]);
        }
    }

    public function toggleGateway(Request $request, StoreGateway $storeGateway)
    {
        ResponseService::noPermissionThenRedirect('seller-store-settings-manage');

        $validator = Validator::make($request->all(), [
            'is_active' => ['required', 'boolean'],
        ]);

        if ($validator->fails()) {
            return back()->withErrors($validator);
        }

        try {
            $storeGateway->update([
                'is_active' => (bool) $validator->validated()['is_active'],
            ]);

            return redirect()
                ->back()
                ->with('success', __('Gateway status updated successfully.'));
        } catch (Throwable $throwable) {
            ResponseService::logErrorResponse($throwable, 'StoreSettingsController -> toggleGateway', 'Error occurred while updating gateway status.', false);

            return back()->withErrors([
                'message' => __('Failed to update gateway status. Please try again.'),
            ]);
        }
    }

    public function toggleGatewayAccount(Request $request, StoreGatewayAccount $storeGatewayAccount)
    {
        ResponseService::noPermissionThenRedirect('seller-store-settings-manage');

        $validator = Validator::make($request->all(), [
            'is_active' => ['required', 'boolean'],
        ]);

        if ($validator->fails()) {
            return back()->withErrors($validator);
        }

        try {
            $storeGatewayAccount->update([
                'is_active' => (bool) $validator->validated()['is_active'],
            ]);

            return redirect()
                ->back()
                ->with('success', __('Gateway account status updated successfully.'));
        } catch (Throwable $throwable) {
            ResponseService::logErrorResponse($throwable, 'StoreSettingsController -> toggleGatewayAccount', 'Error occurred while updating gateway account status.', false);

            return back()->withErrors([
                'message' => __('Failed to update gateway account status. Please try again.'),
            ]);
        }
    }


}
