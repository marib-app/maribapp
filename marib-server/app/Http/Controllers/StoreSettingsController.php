<?php

namespace App\Http\Controllers;

use App\Models\PaymentConfiguration;
use App\Models\Setting;
use App\Services\CachingService;
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

        $storePaymentGateways = PaymentConfiguration::query()
            ->orderBy('display_name')
            ->orderBy('payment_method')
            ->get();

        return view('seller-store-settings.index', [
            'storeTerms'            => $storeTerms,
            'storePaymentGateways' => $storePaymentGateways,
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
}