<?php

namespace App\Http\Controllers;

use App\Models\Setting;
use App\Models\StoreGateway;
use App\Models\StoreGatewayAccount;
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

        return view('seller-store-settings.index', [
            'storeTerms'            => $storeTerms,
            'storeGateways'        => $storeGateways,
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