<?php
use App\Http\Controllers\BlogController;
use App\Http\Controllers\CategoryController;
use App\Http\Controllers\Controller;
use App\Http\Controllers\CustomersController;
use App\Http\Controllers\CustomFieldController;
use App\Http\Controllers\FaqController;
use App\Http\Controllers\ChatMonitorController;
use App\Http\Controllers\HomeController;
use App\Http\Controllers\InstallerController;
use App\Http\Controllers\ItemController;
use App\Http\Controllers\LanguageController;
use App\Http\Controllers\NotificationController;
use App\Http\Controllers\MarketingCampaignController;
use App\Http\Controllers\CategoryManagerController;
use App\Http\Controllers\CouponController;
use App\Http\Controllers\OrderDocumentController;
use App\Http\Controllers\OrderPaymentActionController;
use App\Http\Controllers\OrderController;
use App\Http\Controllers\OrderReportController;
use App\Http\Controllers\PackageController;
use App\Http\Controllers\ManualPaymentRequestController;
use App\Http\Controllers\PlaceController;
use App\Http\Controllers\ReportReasonController;
use App\Http\Controllers\RoleController;
use App\Http\Controllers\SellerController;
use App\Http\Controllers\SeoSettingController;
use App\Http\Controllers\OrderPaymentGroupController;
use App\Http\Controllers\MetalRateController;
use App\Http\Controllers\StoreDashboardController;
use App\Http\Controllers\MerchantStoreController;
use App\Http\Controllers\Store\StoreManualPaymentController;
use App\Http\Controllers\Store\StoreCouponController;
use App\Http\Controllers\Store\StoreInsightsController;
use App\Http\Controllers\Store\StoreOrderController;
use App\Http\Controllers\Store\MerchantProductController;
use App\Http\Controllers\Store\MerchantWalletController;
use App\Http\Controllers\Store\StoreSettingsController as MerchantStoreSettingsController;
use App\Http\Controllers\StoreSettingsController;

use App\Http\Controllers\SettingController;
use App\Http\Controllers\Admin\FeaturedAdsConfigController as AdminFeaturedAdsConfigController;
use App\Http\Controllers\SliderController;
use App\Http\Controllers\StaffController;
use App\Http\Controllers\SystemUpdateController;
use App\Http\Controllers\TipController;
use App\Http\Controllers\UserVerificationController;
use App\Http\Controllers\WebhookController;
use App\Http\Controllers\CurrencyController;
use App\Http\Controllers\GovernorateController;

use App\Http\Controllers\ChallengeController;
use App\Http\Controllers\ReferralController;
use App\Http\Controllers\ServiceController;
use App\Http\Controllers\RequestDeviceController;
use App\Http\Controllers\ServiceReviewController;
use App\Http\Controllers\WalletAdminController;
use App\Services\NotificationService;
use Illuminate\Http\Request;
use App\Models\UserVerification;
use App\Http\Controllers\SheinRequestController;
use App\Services\CachingService;
use App\Services\DepartmentReportService;
use App\Http\Controllers\SectionCategoryCloneController;
use App\Http\Controllers\WalletWithdrawalRequestAdminController;
use App\Http\Controllers\SheinOrderBatchController;
use App\Http\Controllers\LegalNumberingSettingController;
use App\Http\Controllers\WifiCodeBatchController;
use App\Http\Controllers\WifiNetworkController;
use App\Http\Controllers\WifiPlanController;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Route;
use App\Providers\RouteServiceProvider;
use Rap2hpoutre\LaravelLogViewer\LogViewerController;
use App\Http\Controllers\DeliveryPriceController;
use App\Http\Controllers\ServiceRequestController;
use App\Http\Controllers\DelegateController;
use App\Http\Controllers\DepartmentAdvertiserController;
use App\Http\Controllers\DepartmentSettingsController;
use App\Http\Controllers\Wifi\AdminModerationController as WifiAdminModerationController;
use App\Http\Controllers\Wifi\OwnerBatchController as WifiOwnerBatchController;
use App\Http\Controllers\Wifi\OwnerNetworkController as WifiOwnerNetworkController;
use App\Http\Controllers\Wifi\OwnerPlanController as WifiOwnerPlanController;
use App\Http\Controllers\WifiCabinController;

/*
|--------------------------------------------------------------------------
| Web Routes
|--------------------------------------------------------------------------
|
| ط¸â€¦ط¸â€‍ط¸ظ¾ ط¸â€¦ط·آ³ط·آ§ط·آ±ط·آ§ط·ع¾ ط·آ§ط¸â€‍ط¸ث†ط¸ظ¹ط·آ¨: ط¸ظ¹ط·آ¹ط·آ±ط¸â€کط¸ظ¾ ط·آµط¸ظ¾ط·آ­ط·آ§ط·ع¾ ط·آ§ط¸â€‍ط¸ث†ط¸ظ¹ط·آ¨ (Blade/HTML) ط¸ث†ط¸ظ¹ط·آ¹ط¸â€¦ط¸â€‍ ط·آ¨ط¸ث†ط·آ³ط·آ·ط·آ§ط·طŒ web (ط·آ¬ط¸â€‍ط·آ³ط·آ§ط·ع¾/CSRF).
| ط·آ£ط¸ظ¹ ط¸â€¦ط·آ³ط·آ§ط·آ± ط¸â€،ط¸â€ ط·آ§ ط¸ظ¹ط¸â€¦ط¸ئ’ط¸â€  ط¸â€¦ط¸â€ ط·آ§ط·آ¯ط·آ§ط·ع¾ط¸â€، ط¸â€¦ط¸â€  ط·آ§ط¸â€‍ط¸â€¦ط·ع¾ط·آµط¸ظ¾ط·آ­ ط¸â€¦ط·آ¨ط·آ§ط·آ´ط·آ±ط·آ©.
|
*/

Auth::routes();

Route::get('/', static function () {
    if ($user = Auth::user()) {
        return redirect(RouteServiceProvider::resolveHomePath($user));
    }
    return view('auth.login');
});




// === ط·ع¾ط·آ´ط·آ®ط¸ظ¹ط·آµ TLS/PHP ط¸â€¦ط·آ¤ط¸â€ڑط·ع¾ ===
Route::get('/_ini', function () {
    return response()->json([
        'sapi'           => php_sapi_name(),
        'loaded_ini'     => php_ini_loaded_file(),
        'curl.cainfo'    => ini_get('curl.cainfo'),
        'openssl.cafile' => ini_get('openssl.cafile'),
    ]);
});

Route::get('/_tls', function () {
    try {
        $r = \Illuminate\Support\Facades\Http::withOptions([
            'verify'  => base_path('certs/cacert.pem'),
            'timeout' => 10,
        ])->get('https://oauth2.googleapis.com/token'); // ط¸â€ ط·آ¬ط·آ§ط·آ­ TLS ط¸ظ¹ط¸ئ’ط¸ظ¾ط¸ظ¹ ط·آ­ط·ع¾ط¸â€° ط¸â€‍ط¸ث† ط·آ±ط·آ¬ط·آ¹ 405/400
        return response()->json(['ok' => true, 'status' => $r->status()]);
    } catch (\Throwable $e) {
        return response()->json(['ok' => false, 'err' => $e->getMessage()], 500);
    }
});
// === ط·آ§ط·آ­ط·آ°ط¸ظ¾ ط·آ¨ط·آ¹ط·آ¯ ط·آ§ط¸â€‍ط·آ§ط¸â€ ط·ع¾ط¸â€،ط·آ§ط·طŒ ===



/* ------------------------- ط·آµط¸ظ¾ط·آ­ط·آ§ط·ع¾ ط·آ¹ط·آ§ط¸â€¦ط·آ© (ط·آ¨ط·آ¯ط¸ث†ط¸â€  ط·ع¾ط·آ³ط·آ¬ط¸ظ¹ط¸â€‍ ط·آ¯ط·آ®ط¸ث†ط¸â€‍) ------------------------- */

Route::get('page/privacy-policy', static function () {
    $privacy_policy = CachingService::getSystemSettings('privacy_policy');
    echo htmlspecialchars_decode($privacy_policy);
})->name('public.privacy-policy');

Route::get('page/contact-us', static function () {
    $contact_us = CachingService::getSystemSettings('contact_us');
    echo htmlspecialchars_decode($contact_us);
})->name('public.contact-us');

Route::get('page/terms-conditions', static function () {
    $terms_conditions = CachingService::getSystemSettings('terms_conditions');
    echo htmlspecialchars_decode($terms_conditions);
})->name('public.terms-conditions');


Route::get('page/usage-guide', static function () {
    $usageGuide = CachingService::getSystemSettings('usage_guide');
    echo htmlspecialchars_decode($usageGuide);
})->name('public.usage-guide');



/* ----------------------------- Webhooks ط¸â€¦ط·آ²ط¸ث†ط¸â€کط·آ¯ط¸ظ¹ ط·آ§ط¸â€‍ط·آ¯ط¸ظ¾ط·آ¹ ----------------------------- */

Route::group(['prefix' => 'webhook'], static function () {
    Route::post('/stripe', [WebhookController::class, 'stripe']);
    Route::post('/paystack', [WebhookController::class, 'paystack']);
    Route::post('/razorpay', [WebhookController::class, 'razorpay']);
    Route::post('/phonePe', [WebhookController::class, 'phonePe']);
});

Route::get('response/paystack/success', [WebhookController::class, 'paystackSuccessCallback'])->name('paystack.success');
Route::get('response/phonepe/success', [WebhookController::class, 'phonePeSuccessCallback'])->name('phonepe.success');
Route::get('response/paystack/success/web', [SettingController::class, 'paystackPaymentSucesss'])->name('paystack.success.web');
Route::get('response/phonepe/success/web', [SettingController::class, 'phonepePaymentSucesss'])->name('phonepe.success.web');



/* ----------------------- ط·آ¯ط¸ث†ط·آ§ط¸â€‍ ط·آ¹ط·آ§ط¸â€¦ط·آ© (ط·آ¨ط·آ¯ط¸ث†ط¸â€  ط¸â€¦ط·آµط·آ§ط·آ¯ط¸â€ڑط·آ©) Common ------------------------ */

Route::group(['prefix' => 'common'], static function () {
    Route::get('/js/lang', [Controller::class, 'readLanguageFile'])->name('common.language.read');
});



/* --------------------------------- ط·آ§ط¸â€‍ط¸â€¦ط¸عˆط·آ«ط·آ¨ط¸â€کط·ع¾ --------------------------------- */

Route::group(['prefix' => 'install'], static function () {
    Route::get('purchase-code', [InstallerController::class, 'purchaseCodeIndex'])->name('install.purchase-code.index');
    Route::post('purchase-code', [InstallerController::class, 'checkPurchaseCode'])->name('install.purchase-code.post');
    Route::get('php-function', [InstallerController::class, 'phpFunctionIndex'])->name('install.php-function.index');
});



/*
|--------------------------------------------------------------------------
| ط¸â€¦ط·آ³ط·آ§ط·آ±ط·آ§ط·ع¾ ط·ع¾ط·ع¾ط·آ·ط¸â€‍ط·آ¨ ط·ع¾ط·آ³ط·آ¬ط¸ظ¹ط¸â€‍ ط·آ¯ط·آ®ط¸ث†ط¸â€‍ + ط·آ§ط·آ®ط·ع¾ط¸ظ¹ط·آ§ط·آ± ط·آ§ط¸â€‍ط¸â€‍ط·ط›ط·آ©
|--------------------------------------------------------------------------
*/

Route::group(['middleware' => ['auth', 'language']], static function () {

    /* ------------------------------ ط·آ§ط¸â€‍ط·آ®ط·آ¯ط¸â€¦ط·آ§ط·ع¾ Services ------------------------------ */
    Route::group([
        'prefix' => 'services',
        'as' => 'services.',
        'middleware' => ['permission:service-list|service-create|service-edit|service-delete|service-managers-manage']
    ], function () {
        Route::get('/', [ServiceController::class, 'index'])->name('index');
        Route::get('/list', [ServiceController::class, 'list'])->name('list');
        Route::get('/create', [ServiceController::class, 'create'])->name('create');
        Route::post('/', [ServiceController::class, 'store'])->name('store');
        Route::get('/category/{category}', [ServiceController::class, 'category'])->name('category')->middleware('category.manager');
        Route::get('/category/{category}/reviews', [ServiceController::class, 'categoryReviews'])->name('category.reviews')->middleware('category.manager');

        Route::get('/{service}', [ServiceController::class, 'show'])->name('show')->middleware('service.manager');
        Route::get('/{service}/edit', [ServiceController::class, 'edit'])->name('edit')->middleware('service.manager');
        Route::put('/{service}', [ServiceController::class, 'update'])->name('update')->middleware('service.manager');
        Route::delete('/{service}', [ServiceController::class, 'destroy'])->name('destroy')->middleware('service.manager');

        Route::get('/{service}/reviews', [ServiceReviewController::class, 'index'])->name('reviews.index')->middleware('service.manager');
        Route::patch('/{service}/reviews/{serviceReview}', [ServiceReviewController::class, 'updateStatus'])->name('reviews.update')->middleware(['service.manager', 'permission:service-managers-manage']);




    });

    Route::group([
        'prefix' => 'wifi-cabin/api',
        'as' => 'wifi.api.',
        'middleware' => ['auth', 'permission:wifi-cabin-manage'],
    ], static function () {
        Route::get('networks', [WifiAdminModerationController::class, 'networks']);
        Route::patch('networks/{network}/status', [WifiAdminModerationController::class, 'updateNetworkStatus'])->whereNumber('network');

        Route::get('reports', [WifiAdminModerationController::class, 'reports']);
        Route::patch('reports/{report}', [WifiAdminModerationController::class, 'updateReport'])->whereNumber('report');

        Route::prefix('owner')->group(function (): void {
            Route::get('networks/{network}', [WifiOwnerNetworkController::class, 'show'])->whereNumber('network');
            Route::patch('networks/{network}/commission', [WifiOwnerNetworkController::class, 'setCommission'])->whereNumber('network');
            Route::get('networks/{network}/stats', [WifiOwnerNetworkController::class, 'stats'])->whereNumber('network');

            Route::get('networks/{network}/plans', [WifiOwnerPlanController::class, 'index'])->whereNumber('network');
            Route::get('plans/{plan}', [WifiOwnerPlanController::class, 'show'])->whereNumber('plan');

            Route::patch('batches/{batch}/status', [WifiOwnerBatchController::class, 'updateStatus'])->whereNumber('batch');
        });
    });


    Route::group([
        'prefix' => 'payment-requests',
        'as' => 'payment-requests.',
        'middleware' => ['permission:manual-payments-list|manual-payments-review']
    ], static function () {
        Route::get('/', [ManualPaymentRequestController::class, 'index'])->name('index');
        Route::get('/list', [ManualPaymentRequestController::class, 'list'])->name('list');
        Route::get('/table', [ManualPaymentRequestController::class, 'table'])->name('table');


        Route::get('/{manualPaymentRequest}/review', [ManualPaymentRequestController::class, 'review'])->name('review');

        Route::get('/{manualPaymentRequest}/timeline', [ManualPaymentRequestController::class, 'timeline'])->name('timeline');


        Route::get('/{manualPaymentRequest}', [ManualPaymentRequestController::class, 'show'])->name('show');
        Route::post('/{manualPaymentRequest}/decision', [ManualPaymentRequestController::class, 'decide'])->name('decision');


        Route::post('/{manualPaymentRequest}/approve', [ManualPaymentRequestController::class, 'approve'])->name('approve');
        Route::post('/{manualPaymentRequest}/reject', [ManualPaymentRequestController::class, 'reject'])->name('reject');
        Route::post('/{manualPaymentRequest}/notify', [ManualPaymentRequestController::class, 'notify'])->name('notify');


        Route::post('/{manualPaymentRequest}/east-yemen/request', [ManualPaymentRequestController::class, 'eastYemenRequestPayment'])->name('east-yemen.request');
        Route::post('/{manualPaymentRequest}/east-yemen/confirm', [ManualPaymentRequestController::class, 'eastYemenConfirmPayment'])->name('east-yemen.confirm');
        Route::post('/{manualPaymentRequest}/east-yemen/check', [ManualPaymentRequestController::class, 'eastYemenCheckVoucher'])->name('east-yemen.check');
    });


    Route::group([
        'prefix' => 'wifi-cabin',
        'as' => 'wifi.',
        'middleware' => ['permission:wifi-cabin-manage'],
    ], static function () {
        Route::get('/', [WifiCabinController::class, 'index'])->name('index');
        Route::get('/create', [WifiCabinController::class, 'create'])->name('create');
        Route::get('/networks/{network}', [WifiCabinController::class, 'show'])->name('show')->whereNumber('network');
        Route::get('/networks/{network}/codes', [WifiCabinController::class, 'codes'])
            ->name('codes')
            ->whereNumber('network');
        Route::get('/networks/{network}/financials/export', [WifiCabinController::class, 'exportSalesReport'])
            ->name('financials.export')
            ->whereNumber('network');
        Route::post('/batches', [WifiCabinController::class, 'store'])->name('voucher-batches.store');
        Route::get('/{network}/edit', [WifiCabinController::class, 'edit'])->name('edit');

        Route::post('/owner-requests/{batch}/approve', [WifiCabinController::class, 'approveOwnerRequest'])
            ->name('owner-requests.approve')
            ->whereNumber('batch');
        Route::post('/owner-requests/{batch}/reject', [WifiCabinController::class, 'rejectOwnerRequest'])
            ->name('owner-requests.reject')
            ->whereNumber('batch');


    });

    // ط¸ث†ط·آ§ط·آ¬ط¸â€،ط·آ§ط·ع¾ ط·آ¥ط·آ¯ط·آ§ط·آ±ط·آ© ط¸ئ’ط·آ¨ط¸ظ¹ط¸â€ ط·آ© ط·آ§ط¸â€‍ط¸ث†ط·آ§ط¸ظ¹ ط¸ظ¾ط·آ§ط¸ظ¹ ط·آ¹ط·آ¨ط·آ± ط·آ§ط¸â€‍ط·آ¬ط¸â€‍ط·آ³ط·آ© (ط¸â€‍ط·ع¾ط·آ¬ط¸â€ ط·آ¨ ط·آ£ط·آ®ط·آ·ط·آ§ط·طŒ Unauthenticated ط¸ظ¾ط¸ظ¹ ط·آ§ط¸â€‍ط¸ث†ط·آ§ط·آ¬ط¸â€،ط·آ© ط·آ§ط¸â€‍ط·آ¥ط·آ¯ط·آ§ط·آ±ط¸ظ¹ط·آ©)
    Route::group([
        'prefix' => 'wifi-cabin/api',
        'middleware' => ['auth', 'permission:wifi-cabin-manage'],
    ], static function () {
        Route::get('/admin/networks', [WifiAdminModerationController::class, 'networks']);
        Route::patch('/admin/networks/{network}/status', [WifiAdminModerationController::class, 'updateNetworkStatus'])
            ->whereNumber('network');
        Route::patch('/admin/networks/{network}/commission', [WifiOwnerNetworkController::class, 'setCommission'])
            ->whereNumber('network');
    });


    Route::group([
        'prefix' => 'wallet',
        'as' => 'wallet.',
        'middleware' => ['permission:wallet-manage']
    ], static function () {
        Route::get('/', [WalletAdminController::class, 'index'])->name('index');
        Route::get('/withdrawals', [WalletWithdrawalRequestAdminController::class, 'index'])
            ->name('withdrawals.index');

        Route::post('/withdrawals/{withdrawalRequest}/approve', [WalletWithdrawalRequestAdminController::class, 'approve'])
            ->name('withdrawals.approve')
            ->whereNumber('withdrawalRequest');
        Route::post('/withdrawals/{withdrawalRequest}/reject', [WalletWithdrawalRequestAdminController::class, 'reject'])
            ->name('withdrawals.reject')
            ->whereNumber('withdrawalRequest');
        Route::get('/{user}', [WalletAdminController::class, 'show'])->name('show')->whereNumber('user');
        Route::post('/{user}/credit', [WalletAdminController::class, 'credit'])->name('credit')->whereNumber('user');



    });




    /* ---------------------- ط·آ¯ط¸ث†ط·آ§ط¸â€‍ ط·آ¹ط·آ§ط¸â€¦ط·آ© ط·آ¨ط·آ¹ط·آ¯ ط·آ§ط¸â€‍ط¸â€¦ط·آµط·آ§ط·آ¯ط¸â€ڑط·آ© (Common) ---------------------- */
    Route::group(['prefix' => 'common'], static function () {
        Route::put('/change-row-order', [Controller::class, 'changeRowOrder'])->name('common.row-order.change');
        Route::put('/change-status', [Controller::class, 'changeStatus'])->name('common.status.change');
    });

    /* ط·ع¾ط¸â€ ط·آ¨ط¸ظ¹ط¸â€،: ط·ع¾ط¸ث†ط·آ¬ط·آ¯ ط¸â€¦ط·آ¬ط¸â€¦ط¸ث†ط·آ¹ط·آ© "common" ط¸â€¦ط¸ئ’ط·آ±ط·آ±ط·آ© ط¸ظ¾ط¸ظ¹ ط¸â€¦ط¸â€‍ط¸ظ¾ط¸ئ’ ط·آ§ط¸â€‍ط·آ£ط·آµط¸â€‍ط¸ظ¹ أ¢â‚¬â€‌ ط·آ£ط·آ¨ط¸â€ڑط¸ظ¹ط·ع¾ط¸â€،ط·آ§ ط¸ئ’ط¸â€¦ط·آ§ ط¸â€،ط¸ظ¹ ط¸â€‍ط·ع¾ط·آ¬ط¸â€ ط¸â€کط·آ¨ ط·آ£ط¸ظ¹ ط·ع¾ط·آ£ط·آ«ط¸ظ¹ط·آ± ط·آ¬ط·آ§ط¸â€ ط·آ¨ط¸ظ¹. */
    Route::group(['prefix' => 'common'], static function () {
        Route::put('/change-row-order', [Controller::class, 'changeRowOrder'])->name('common.row-order.change');
        Route::put('/change-status', [Controller::class, 'changeStatus'])->name('common.status.change');
    });

    


    /* --------------------------------- Challenges -------------------------------- */
    Route::group([
        'prefix' => 'challenges',
        'as' => 'challenges.',
        'middleware' => ['permission:challenge-list|challenge-create|challenge-edit|challenge-delete']
    ], function () {
        Route::get('/', [ChallengeController::class, 'index'])->name('index');
        Route::get('/list', [ChallengeController::class, 'list'])->name('list');
        Route::match(['get', 'post'], '/store', [ChallengeController::class, 'store'])->name('store');
        Route::get('/{challenge}/edit', [ChallengeController::class, 'edit'])->name('edit');
        Route::match(['put','post','get'], '/{challenge}', [ChallengeController::class, 'update'])->name('update');
        Route::delete('/{challenge}', [ChallengeController::class, 'destroy'])->name('delete');
    });



    /* --------------------------------- Referrals --------------------------------- */
    Route::group([
        'prefix' => 'referrals',
        'as' => 'referrals.',
        'middleware' => ['permission:referral-list']
    ], function () {
        Route::get('/', [ReferralController::class, 'index'])->name('index');
        Route::get('/list', [ReferralController::class, 'list'])->name('list');
        Route::get('/top-users', [ReferralController::class, 'topUsers'])->name('top-users');
        Route::get('/attempts', [ReferralController::class, 'attempts'])->name('attempts');


    });






    /* ------------------------------- ط¸ئ’ط·آ¨ط¸ظ¹ط¸â€ ط·آ© ط·آ§ط¸â€‍ط¸ث†ط·آ§ط¸ظ¹ ط¸ظ¾ط·آ§ط¸ظ¹  ------------------------------ */



    Route::group([
        'prefix' => 'wifi',
        'as' => 'wifi.',
        'middleware' => ['permission:service-list|service-create|service-edit|service-delete'],
    ], function () {
        Route::get('networks', [WifiNetworkController::class, 'index'])->name('networks.index');
        Route::post('networks', [WifiNetworkController::class, 'store'])->name('networks.store');
        Route::put('networks/{network}', [WifiNetworkController::class, 'update'])
            ->whereNumber('network')
            ->name('networks.update'); 
        Route::get('networks/{network}/plans', [WifiPlanController::class, 'index'])
            ->whereNumber('network')
            ->name('plans.index');
        Route::post('networks/{network}/plans', [WifiPlanController::class, 'store'])
            ->whereNumber('network')
            ->name('plans.store');

        Route::put('plans/{plan}', [WifiPlanController::class, 'update'])
            ->whereNumber('plan')
            ->name('plans.update');

        Route::post('plans/{plan}/batches', [WifiCodeBatchController::class, 'store'])
            ->whereNumber('plan')
            ->name('plans.batches.store');
    });


    /* ------------------------------- ط·آ§ط¸â€‍ط·آ¹ط¸â€¦ط¸â€‍ط·آ© Currency ------------------------------ */


    Route::group(['middleware' => ['permission:governorate-list|governorate-create|governorate-edit|governorate-delete']], static function () {
        Route::get('/governorates', [GovernorateController::class, 'index'])
            ->name('governorates.index');
        Route::get('/governorates/create', [GovernorateController::class, 'create'])
            ->middleware('permission:governorate-create')
            ->name('governorates.create');
        Route::post('/governorates', [GovernorateController::class, 'store'])
            ->middleware('permission:governorate-create')
            ->name('governorates.store');
        Route::get('/governorates/{governorate}/edit', [GovernorateController::class, 'edit'])
            ->middleware('permission:governorate-edit')
            ->name('governorates.edit');
        Route::put('/governorates/{governorate}', [GovernorateController::class, 'update'])
            ->middleware('permission:governorate-edit')
            ->name('governorates.update');
        Route::delete('/governorates/{governorate}', [GovernorateController::class, 'destroy'])
            ->middleware('permission:governorate-delete')
            ->name('governorates.destroy');
    });



    Route::group(['middleware' => ['permission:currency-rate-list|currency-rate-create|currency-rate-edit|currency-rate-delete|currency-rate-import']], static function () {

        Route::get('/currency', [CurrencyController::class, 'index'])->name('currency.index');
        Route::get('/currency/create', [CurrencyController::class, 'create'])
            ->middleware('permission:currency-rate-create')
            ->name('currency.create');
        Route::post('/currency', [CurrencyController::class, 'store'])
            ->middleware('permission:currency-rate-create')
            ->name('currency.store');
        Route::post('/currency/import', [CurrencyController::class, 'import'])
            ->middleware('permission:currency-rate-import')
            ->name('currency.import');


        Route::get('/currency/{id}/edit', [CurrencyController::class, 'edit'])
            ->middleware('permission:currency-rate-edit')
            ->name('currency.edit');



        Route::get('/currency/show', [CurrencyController::class, 'show'])->name('currency.show');
        Route::get('/currency/logs', [CurrencyController::class, 'changeLogs'])->name('currency.logs');
        Route::put('/currency/{id}', [CurrencyController::class, 'update'])
            ->middleware('permission:currency-rate-edit')
            ->name('currency.update');
        Route::delete('/currency/{id}', [CurrencyController::class, 'destroy'])
            ->middleware('permission:currency-rate-delete')
            ->name('currency.destroy');
        Route::delete('/currency/{id}/icon', [CurrencyController::class, 'destroyIcon'])
            ->middleware('permission:currency-rate-edit')
            ->name('currency.icon.destroy');


    });

    /* ------------------------------- ط·آ£ط·آ³ط·آ¹ط·آ§ط·آ± ط·آ§ط¸â€‍ط¸â€¦ط·آ¹ط·آ§ط·آ¯ط¸â€  Metal Rates ------------------------------ */


    Route::group([
        'prefix' => 'metal-rates',
        'as' => 'metal-rates.',
        'middleware' => ['permission:metal-rate-list|metal-rate-create|metal-rate-edit|metal-rate-delete|metal-rate-schedule'],
    ], static function () {
        Route::get('/', [MetalRateController::class, 'index'])->name('index');
        Route::get('/show', [MetalRateController::class, 'show'])->name('show');
        Route::get('/create', [MetalRateController::class, 'create'])
            ->middleware('permission:metal-rate-create')
            ->name('create');
        Route::get('/{metalRate}/edit', [MetalRateController::class, 'edit'])
            ->whereNumber('metalRate')
            ->middleware('permission:metal-rate-edit')
            ->name('edit');
        Route::post('/', [MetalRateController::class, 'store'])
            ->middleware('permission:metal-rate-create')
            ->name('store');
            
        Route::put('/{metalRate}', [MetalRateController::class, 'update'])
            ->whereNumber('metalRate')
            ->middleware('permission:metal-rate-edit')
            ->name('update');
        Route::delete('/{metalRate}', [MetalRateController::class, 'destroy'])
            ->whereNumber('metalRate')
            ->middleware('permission:metal-rate-delete')
            ->name('destroy');
        Route::post('/{metalRate}/schedule', [MetalRateController::class, 'schedule'])
            ->whereNumber('metalRate')
            ->middleware('permission:metal-rate-schedule')
            ->name('schedule');
        Route::delete('/schedules/{metalRateUpdate}', [MetalRateController::class, 'cancelSchedule'])
            ->whereNumber('metalRateUpdate')
            ->middleware('permission:metal-rate-schedule')
            ->name('schedule.cancel');
    });




    /* --------------------------------- ط·آ§ط¸â€‍ط·آ±ط·آ¦ط¸ظ¹ط·آ³ط¸ظ¹ط·آ© Home ------------------------------- */
    Route::get('/home', [HomeController::class, 'index'])->name('home');

    Route::get('change-password', [HomeController::class, 'changePasswordIndex'])->name('change-password.index');
    Route::post('change-password', [HomeController::class, 'changePasswordUpdate'])->name('change-password.update');

    Route::get('change-profile', [HomeController::class, 'changeProfileIndex'])->name('change-profile.index');
    Route::post('change-profile', [HomeController::class, 'changeProfileUpdate'])->name('change-profile.update');



    /* --------------------------------- ط·آ§ط¸â€‍ط·ع¾ط·آµط¸â€ ط¸ظ¹ط¸ظ¾ط·آ§ط·ع¾ Category ------------------------------- */
    Route::resource('category', CategoryController::class);

    Route::group(['prefix' => 'category'], static function () {
        Route::get('/{id}/subcategories', [CategoryController::class, 'getSubCategories'])->name('category.subcategories');
        Route::get('/{id}/custom-fields', [CategoryController::class, 'customFields'])->name('category.custom-fields');
        Route::get('/{id}/custom-fields/show', [CategoryController::class, 'getCategoryCustomFields'])->name('category.custom-fields.show');
        Route::delete('/{id}/custom-fields/{customFieldID}/delete', [CategoryController::class, 'destroyCategoryCustomField'])->name('category.custom-fields.destroy');

        Route::get('/{category}/clone-targets', [CategoryController::class, 'cloneTargets'])->name('category.clone-targets');
        Route::post('/{category}/clone', [CategoryController::class, 'cloneCategory'])->name('category.clone');

        Route::get('/{category}/managers', [CategoryManagerController::class, 'edit'])->name('category.managers.edit')->middleware(['category.manager', 'permission:service-managers-manage']);
        Route::post('/{category}/managers', [CategoryManagerController::class, 'update'])->name('category.managers.update')->middleware(['category.manager', 'permission:service-managers-manage']);

        Route::get('/categories/order', [CategoryController::class, 'categoriesReOrder'])->name('category.order');
        Route::post('categories/change-order', [CategoryController::class, 'updateOrder'])->name('category.order.change');
        Route::get('/{id}/sub-category/change-order', [CategoryController::class, 'subCategoriesReOrder'])->name('sub.category.order.change');
    });



    /* --------------------------------- ط·آ§ط¸â€‍ط·آ­ط¸â€ڑط¸ث†ط¸â€‍ ط·آ§ط¸â€‍ط¸â€¦ط·آ®ط·آµط¸â€کط·آµط·آ© Custom Fields ------------------------------- */
    Route::group(['prefix' => 'custom-fields'], static function () {
        Route::post('/{id}/value/add', [CustomFieldController::class, 'addCustomFieldValue'])->name('custom-fields.value.add');
        Route::get('/{id}/value/show', [CustomFieldController::class, 'getCustomFieldValues'])->name('custom-fields.value.show');
        Route::put('/{id}/value/edit', [CustomFieldController::class, 'updateCustomFieldValue'])->name('custom-fields.value.update');
        Route::delete('/{id}/value/{value}/delete', [CustomFieldController::class, 'deleteCustomFieldValue'])->name('custom-fields.value.delete');
        Route::get('/{categoryId}/order', [CustomFieldController::class, 'customFieldsReOrder'])->name('custom-fields.order');
        Route::post('/order/update', [CustomFieldController::class, 'updateCustomFieldsOrder'])->name('custom-fields.order.update');
        Route::post('/{category}/clone', [CustomFieldController::class, 'cloneCategory'])->name('custom-fields.clone');

    });

    Route::resource('custom-fields', CustomFieldController::class);



    /* --------------------------- ط·ع¾ط¸ث†ط·آ«ط¸ظ¹ط¸â€ڑ ط·آ§ط¸â€‍ط·آ¨ط·آ§ط·آ¦ط·آ¹ Seller Verification --------------------------- */
    Route::group(['prefix' => 'seller-verification'], static function () {
        Route::get('/dashboard', [UserVerificationController::class, 'dashboard'])->name('seller-verification.dashboard');
        Route::get('/verification-payments', [UserVerificationController::class, 'payments'])->name('verification_payments.show');
        Route::get('/verified-accounts', [UserVerificationController::class, 'verifiedAccounts'])->name('verification_verified_accounts.show');
        Route::post('/plans', [UserVerificationController::class, 'storePlan'])->name('seller-verification.plan.store');
        Route::put('/plans/{plan}', [UserVerificationController::class, 'updatePlan'])->name('seller-verification.plan.update');
        Route::delete('/plans/{plan}', [UserVerificationController::class, 'destroyPlan'])->name('seller-verification.plan.delete');

        Route::put('/{id}/approval', [UserVerificationController::class, 'updateSellerApproval'])->name('seller_verification.approval');

        Route::get('/verification-requests', [UserVerificationController::class, 'show'])->name('verification_requests.show');
        Route::get('/verification-details/{id}', [UserVerificationController::class, 'getVerificationDetails']);
        Route::get('/requests/{id}', [UserVerificationController::class, 'requestDetails'])->name('seller-verification.request.details');

        Route::put('/seller-verification/status-change', [UserVerificationController::class, 'updateStatus'])->name('seller-verification.update_status');

        Route::get('/verification-field/index', [UserVerificationController::class, 'verificationField'])->name('seller-verification.verification-field');
        Route::get('/verification-field', [UserVerificationController::class, 'showVerificationFields'])->name('verification-field.show');

        Route::get('/{id}/edit', [UserVerificationController::class, 'edit'])->name('seller-verification.verification-field.edit');
        Route::put('/{id}', [UserVerificationController::class, 'update'])->name('seller-verification.verification-field.update');
        Route::delete('/{id}/delete', [UserVerificationController::class, 'destroy'])->name('seller-verification.verification-field.delete');

        Route::post('/{id}/value/add', [UserVerificationController::class, 'addSellerVerificationValue'])->name('seller-verification.value.add');
        Route::get('/{id}/value/show', [UserVerificationController::class, 'getSellerVerificationValues'])->name('seller-verification.value.show');
        Route::put('/{id}/value/edit', [UserVerificationController::class, 'updateSellerVerificationValue'])->name('seller-verification.value.update');
        Route::delete('/{id}/value/{value}/delete', [UserVerificationController::class, 'deleteSellerVerificationValue'])->name('seller-verification.value.delete');
    });

    Route::resource('seller-verification', UserVerificationController::class);



    /* --------------------------------- ط·آ§ط¸â€‍ط·آ¥ط·آ¹ط¸â€‍ط·آ§ط¸â€ ط·آ§ط·ع¾ Items --------------------------------- */
    Route::group(['prefix' => 'item'], static function () {
        Route::put('/{id}/approval', [ItemController::class, 'updateItemApproval'])->name('item.approval');
        Route::post('/{item}/feature', [ItemController::class, 'feature'])
            ->name('item.feature')
            ->middleware('permission:item-update|shein-products-update|computer-ads-update');

        Route::prefix('shein')->name('item.shein.')->group(function () {
            Route::get('/', [ItemController::class, 'shein'])->name('index');
            Route::get('/create', [ItemController::class, 'createShein'])->name('create');
            Route::post('/store', [ItemController::class, 'storeShein'])->name('store');
            Route::get('/edit/{id}', [ItemController::class, 'editShein'])->name('edit');
            Route::post('/update/{id}', [ItemController::class, 'updateShein'])->name('update');

            Route::get('/settings', [DepartmentSettingsController::class, 'editShein'])
                ->name('settings')
                ->middleware('permission:shein-products-update');
            Route::post('/settings', [DepartmentSettingsController::class, 'updateShein'])
                ->name('settings.update')
                ->middleware('permission:shein-products-update');



            Route::get('/products', [ItemController::class, 'sheinProducts'])->name('products');

            Route::get('/products/data', [ItemController::class, 'sheinProductsData'])
                ->name('products.data')
                ->middleware('permission:shein-products-list|shein-products-update|shein-products-delete');

            Route::get('/products/create', [ItemController::class, 'createShein'])->name('products.create');
            Route::post('/products', [ItemController::class, 'storeShein'])->name('products.store');
            Route::get('/products/{id}/edit', [ItemController::class, 'editShein'])->name('products.edit');
            Route::post('/products/{id}', [ItemController::class, 'updateShein'])->name('products.update');

            Route::get('/orders', [OrderController::class, 'indexShein'])->name('orders');

            Route::get('/custom-orders', [SheinRequestController::class, 'index'])->name('custom-orders.index');
            Route::get('/custom-orders/{id}', [SheinRequestController::class, 'show'])->name('custom-orders.show');
            Route::delete('/custom-orders/{id}', [SheinRequestController::class, 'destroy'])->name('custom-orders.destroy');

            Route::get('/batches', [SheinOrderBatchController::class, 'index'])->name('batches.index');
            Route::get('/batches/create', [SheinOrderBatchController::class, 'create'])->name('batches.create');
            Route::post('/batches', [SheinOrderBatchController::class, 'store'])->name('batches.store');
            Route::get('/batches/report', [SheinOrderBatchController::class, 'report'])->name('batches.report');
            Route::get('/batches/{batch}', [SheinOrderBatchController::class, 'show'])->name('batches.show');
            Route::put('/batches/{batch}', [SheinOrderBatchController::class, 'update'])->name('batches.update');
            Route::post('/batches/{batch}/assign-orders', [SheinOrderBatchController::class, 'assignOrders'])->name('batches.assign-orders');
            Route::post('/batches/{batch}/bulk-update', [SheinOrderBatchController::class, 'bulkUpdate'])->name('batches.bulk-update');

            Route::get('/delegates', [DelegateController::class, 'sheinIndex'])
                ->name('delegates')
                ->middleware('permission:shein-products-list|shein-products-update');
            Route::post('/delegates', [DelegateController::class, 'sheinUpdate'])
                ->name('delegates.update')
                ->middleware('permission:shein-products-update');
            Route::post('/advertiser', [DepartmentAdvertiserController::class, 'updateShein'])
                ->name('advertiser.update')
                ->middleware('permission:shein-products-update');

            Route::get('/reports', [OrderReportController::class, 'section'])
                ->name('reports')
                ->defaults('section', DepartmentReportService::DEPARTMENT_SHEIN);


            Route::get('/support', [ChatMonitorController::class, 'index'])
                ->name('support')
                ->defaults('department', DepartmentReportService::DEPARTMENT_SHEIN);

        });
    });


    Route::get('item/list', [ItemController::class, 'listData'])->name('item.list');
   
    Route::get('item/{item}/details', [ItemController::class, 'details'])->name('item.details');
    Route::resource('item', ItemController::class);




    Route::prefix('computer')->group(function () {

        Route::get('/', [ItemController::class, 'computer'])->name('item.computer');
        Route::get('/create', [ItemController::class, 'computerCreate'])->name('item.computer.create');

        Route::get('/settings', [DepartmentSettingsController::class, 'editComputer'])
            ->name('item.computer.settings')
            ->middleware('permission:computer-ads-update');
        Route::post('/settings', [DepartmentSettingsController::class, 'updateComputer'])
            ->name('item.computer.settings.update')
            ->middleware('permission:computer-ads-update');

            
        Route::post('/products', [ItemController::class, 'storeComputer'])
            ->name('item.computer.products.store')
            ->middleware('permission:computer-ads-create');


        Route::get('/publish', [ItemController::class, 'computerPublish'])->name('item.computer.publish');
        Route::get('/products', [ItemController::class, 'computerProducts'])->name('item.computer.products');
        Route::get('/orders', [OrderController::class, 'indexComputer'])->name('item.computer.orders');
        Route::get('/custom-orders', [RequestDeviceController::class, 'index'])->name('item.computer.custom-orders.index');
        Route::get('/custom-orders/{id}', [RequestDeviceController::class, 'show'])->name('item.computer.custom-orders.show');
        Route::delete('/custom-orders/{id}', [RequestDeviceController::class, 'destroy'])->name('item.computer.custom-orders.destroy');
        Route::get('/delegates', [DelegateController::class, 'computerIndex'])
            ->name('item.computer.delegates')
            ->middleware('permission:computer-ads-list|computer-ads-update');
        Route::post('/delegates', [DelegateController::class, 'computerUpdate'])
            ->name('item.computer.delegates.update')
            ->middleware('permission:computer-ads-update');
            
            

        Route::post('/advertiser', [DepartmentAdvertiserController::class, 'updateComputer'])
            ->name('item.computer.advertiser.update')
            ->middleware('permission:computer-ads-update');

        Route::get('/reports', [OrderReportController::class, 'section'])
            ->name('item.computer.reports')
            ->defaults('section', DepartmentReportService::DEPARTMENT_COMPUTER);

        Route::get('/support', [ChatMonitorController::class, 'index'])
            ->name('item.computer.support')
            ->defaults('department', DepartmentReportService::DEPARTMENT_COMPUTER);

    });


        Route::post('/sections/{section}/categories/clone', SectionCategoryCloneController::class)
        ->name('sections.clone-categories')
        ->middleware('permission:category-create');


    /* ---------------------------- ط·آ·ط¸â€‍ط·آ¨ط·آ§ط·ع¾ ط·آ§ط¸â€‍ط·آ®ط·آ¯ط¸â€¦ط·آ§ط·ع¾ Service Requests ---------------------------- */


        // ط·آ·ط¸â€‍ط·آ¨ط·آ§ط·ع¾ ط·آ§ط¸â€‍ط·آ®ط·آ¯ط¸â€¦ط·آ§ط·ع¾ (ط¸â€‍ط¸ث†ط·آ­ط·آ© ط·آ§ط¸â€‍ط·آ¥ط·آ¯ط·آ§ط·آ±ط·آ©) أ¢â‚¬â€‌ ط·آ§ط¸â€‍ط·آµط·آ­ط¸ظ¹ط·آ­ط·آ©
        Route::prefix('service-requests')
            ->name('service.requests.')
            ->middleware('permission:service-requests-list|service-requests-update|service-requests-delete')
            ->group(function () {
                
            Route::get('/',                     [ServiceRequestController::class, 'index'])->name('index');
            Route::get('/datatable',            [ServiceRequestController::class, 'datatable'])->name('datatable');
            Route::get('/{serviceRequest}/review', [ServiceRequestController::class, 'review'])->name('review');
            Route::get('/{serviceRequest}',     [ServiceRequestController::class, 'show'])->name('show');
            
            Route::post('/approval/{id}',       [ServiceRequestController::class, 'updateApproval'])->name('approval');
            Route::delete('/{id}',              [ServiceRequestController::class, 'destroy'])->name('destroy');
        });



    /* --------------------------------- ط·ع¾ط¸â€ڑط¸ظ¹ط¸ظ¹ط¸â€¦ط·آ§ط·ع¾ ط·آ§ط¸â€‍ط·آ¨ط·آ§ط·آ¦ط·آ¹ Seller Reviews --------------------------------- */
    Route::resource('seller-review', SellerController::class);
    Route::get('review-report', [SellerController::class, 'showReports'])->name('seller-review.report');


    Route::group([
        'prefix' => 'seller-store-settings',
        'as' => 'seller-store-settings.',
        'middleware' => ['permission:seller-store-settings-manage'],
    ], static function () {
        Route::get('/', [StoreSettingsController::class, 'index'])->name('index');
        Route::post('/terms', [StoreSettingsController::class, 'storeTerms'])->name('terms.store');

        Route::get('/gateways', [StoreSettingsController::class, 'gateways'])->name('gateways.index');
        Route::get('/gateways/create', [StoreSettingsController::class, 'createGateway'])->name('gateways.create');
        Route::post('/gateways', [StoreSettingsController::class, 'storeGateway'])->name('gateways.store');
        Route::get('/gateways/{storeGateway}/edit', [StoreSettingsController::class, 'editGateway'])->name('gateways.edit');
        Route::put('/gateways/{storeGateway}', [StoreSettingsController::class, 'updateGateway'])->name('gateways.update');
        Route::delete('/gateways/{storeGateway}', [StoreSettingsController::class, 'destroyGateway'])->name('gateways.destroy');
        Route::patch('/gateways/{storeGateway}/toggle', [StoreSettingsController::class, 'toggleGateway'])->name('gateways.toggle');
        Route::patch('/gateway-accounts/{storeGatewayAccount}/toggle', [StoreSettingsController::class, 'toggleGatewayAccount'])->name('gateway-accounts.toggle');

        Route::post('/ui', [StoreSettingsController::class, 'storeUiSettings'])->name('ui.store');
        Route::get('/items', [StoreSettingsController::class, 'searchStoreItems'])->name('items');
    });

    Route::group([
        'prefix' => 'merchant-stores',
        'as' => 'merchant-stores.',
        'middleware' => ['permission:seller-store-settings-manage'],
    ], static function () {
        Route::get('/', [MerchantStoreController::class, 'index'])->name('index');
        Route::get('/{store}', [MerchantStoreController::class, 'show'])->name('show');
        Route::post('/{store}/status', [MerchantStoreController::class, 'updateStatus'])->name('status');
    });

    Route::group([
        'prefix' => 'merchant',
        'as' => 'merchant.',
        'middleware' => ['store.access'],
    ], static function () {
        Route::get('dashboard', [StoreDashboardController::class, 'index'])->name('dashboard');
        Route::get('orders', [StoreOrderController::class, 'index'])->name('orders.index');
        Route::get('orders/{order}', [StoreOrderController::class, 'show'])
            ->whereNumber('order')
            ->name('orders.show');
        Route::post('orders/{order}/status', [StoreOrderController::class, 'updateStatus'])
            ->whereNumber('order')
            ->name('orders.status');
        Route::get('manual-payments', [StoreManualPaymentController::class, 'index'])->name('manual-payments.index');
          Route::get('manual-payments/{manualPaymentRequest}', [StoreManualPaymentController::class, 'show'])
              ->whereNumber('manualPaymentRequest')
              ->name('manual-payments.show');
          Route::post('manual-payments/{manualPaymentRequest}/decide', [StoreManualPaymentController::class, 'decide'])
              ->whereNumber('manualPaymentRequest')
              ->name('manual-payments.decide');
          Route::get('wallet', [MerchantWalletController::class, 'index'])->name('wallet.index');
          Route::post('wallet/withdraw', [MerchantWalletController::class, 'submitWithdrawal'])->name('wallet.withdraw');
          Route::get('products', [MerchantProductController::class, 'index'])->name('products.index');
          Route::post('products', [MerchantProductController::class, 'store'])->name('products.store');
          Route::patch('products/{item}/stock', [MerchantProductController::class, 'updateStock'])
              ->whereNumber('item')
              ->name('products.stock');
          Route::patch('products/{item}/status', [MerchantProductController::class, 'updateStatus'])
              ->whereNumber('item')
              ->name('products.status');
          Route::delete('products/{item}', [MerchantProductController::class, 'destroy'])
              ->whereNumber('item')
              ->name('products.destroy');
          Route::get('coupons', [StoreCouponController::class, 'index'])->name('coupons.index');
          Route::get('coupons/create', [StoreCouponController::class, 'create'])->name('coupons.create');
          Route::post('coupons', [StoreCouponController::class, 'store'])->name('coupons.store');
          Route::get('coupons/{coupon}/edit', [StoreCouponController::class, 'edit'])
              ->whereNumber('coupon')
              ->name('coupons.edit');
          Route::match(['put', 'patch'], 'coupons/{coupon}', [StoreCouponController::class, 'update'])
              ->whereNumber('coupon')
              ->name('coupons.update');
          Route::patch('coupons/{coupon}/toggle', [StoreCouponController::class, 'toggle'])
              ->whereNumber('coupon')
              ->name('coupons.toggle');
          Route::delete('coupons/{coupon}', [StoreCouponController::class, 'destroy'])
              ->whereNumber('coupon')
              ->name('coupons.destroy');
          Route::get('settings', [MerchantStoreSettingsController::class, 'index'])->name('settings');
          Route::post('settings/general', [MerchantStoreSettingsController::class, 'updateGeneral'])->name('settings.general');
          Route::post('settings/hours', [MerchantStoreSettingsController::class, 'updateHours'])->name('settings.hours');
          Route::post('settings/policies', [MerchantStoreSettingsController::class, 'updatePolicies'])->name('settings.policies');
          Route::post('settings/staff', [MerchantStoreSettingsController::class, 'updateStaff'])->name('settings.staff');
          Route::post('settings/gateway-accounts', [MerchantStoreSettingsController::class, 'storeGatewayAccount'])->name('settings.gateway-accounts.store');
          Route::match(['put', 'patch'], 'settings/gateway-accounts/{storeGatewayAccount}', [MerchantStoreSettingsController::class, 'updateGatewayAccount'])
              ->whereNumber('storeGatewayAccount')
              ->name('settings.gateway-accounts.update');
          Route::delete('settings/gateway-accounts/{storeGatewayAccount}', [MerchantStoreSettingsController::class, 'destroyGatewayAccount'])
              ->whereNumber('storeGatewayAccount')
              ->name('settings.gateway-accounts.destroy');
          Route::post('settings/wallet/withdraw', [MerchantStoreSettingsController::class, 'submitWalletWithdrawal'])
              ->name('settings.wallet.withdraw');
          Route::get('reports/orders', [StoreInsightsController::class, 'orderReports'])->name('reports.orders');
          Route::get('reports/sales', [StoreInsightsController::class, 'salesReports'])->name('reports.sales');
          Route::get('reports/customers', [StoreInsightsController::class, 'customerReports'])->name('reports.customers');
      });

    /* --------------------------------- ط·آ§ط¸â€‍ط·آ¥ط·آ¹ط·آ¯ط·آ§ط·آ¯ط·آ§ط·ع¾ Settings --------------------------------- */
Route::group(['prefix' => 'settings'], static function () {
        Route::get('/', [SettingController::class, 'index'])->name('settings.index');
        Route::post('/store', [SettingController::class, 'store'])->name('settings.store');

        Route::get('system', [SettingController::class, 'page'])->name('settings.system');

        Route::get('invoice', [SettingController::class, 'page'])->name('settings.invoice.index');


        Route::get('about-us', [SettingController::class, 'page'])->name('settings.about-us.index');
        Route::get('privacy-policy', [SettingController::class, 'page'])->name('settings.privacy-policy.index');
        Route::get('contact-us', [SettingController::class, 'page'])->name('settings.contact-us.index');
        Route::get('terms-conditions', [SettingController::class, 'page'])->name('settings.terms-conditions.index');

        Route::get('usage-guide', [SettingController::class, 'page'])->name('settings.usage-guide.index');
        Route::get('whatsapp', [SettingController::class, 'page'])->name('settings.whatsapp.index');


        Route::get('firebase', [SettingController::class, 'page'])->name('settings.firebase.index');
        Route::post('firebase/update', [SettingController::class, 'updateFirebaseSettings'])->name('settings.firebase.update');

        Route::get('payment-gateway', [SettingController::class, 'paymentSettingsIndex'])->name('settings.payment-gateway.index');
        Route::post('payment-gateway', [SettingController::class, 'paymentSettingsStore'])->name('settings.payment-gateway.store');

        Route::post('payment-gateway/east-yemen-bank', [SettingController::class, 'eastYemenBankSettings'])->name('settings.payment-gateway.east-yemen-bank');

        Route::get('legal-numbering', [LegalNumberingSettingController::class, 'index'])->name('settings.legal-numbering.index');
        Route::post('legal-numbering', [LegalNumberingSettingController::class, 'update'])->name('settings.legal-numbering.update');

        
        Route::put('payment-gateway/manual-banks/{manualBank}', [SettingController::class, 'paymentSettingsUpdate'])->name('settings.manual-banks.update');
        Route::delete('payment-gateway/manual-banks/{manualBank}', [SettingController::class, 'paymentSettingsDestroy'])->name('settings.manual-banks.destroy');

        Route::get('language', [SettingController::class, 'page'])->name('settings.language.index');
        Route::get('admob', [SettingController::class, 'page'])->name('settings.admob.index');

        Route::get('/system-status', [SettingController::class, 'systemStatus'])->name('settings.system-status.index');
        Route::get('/toggle-storage-link', [SettingController::class, 'toggleStorageLink'])->name('toggle.storage.link');

        Route::get('error-logs', [LogViewerController::class, 'index'])->name('settings.error-logs.index');
        Route::get('seo-setting', [SettingController::class, 'page'])->name('settings.seo-settings.index');

        Route::get('file-manager', [SettingController::class, 'page'])->name('settings.file-manager.index');
        Route::post('file-manager-store', [SettingController::class, 'fileManagerSettingStore'])->name('settings.file-manager.store');
    });

    Route::group(['prefix' => 'system-update'], static function () {
        Route::get('/', [SystemUpdateController::class, 'index'])->name('system-update.index');
        Route::post('/', [SystemUpdateController::class, 'update'])->name('system-update.update');
    });



    /* --------------------------------- ط·آ§ط¸â€‍ط¸â€‍ط·ط›ط·آ§ط·ع¾ Language --------------------------------- */
    Route::group(['prefix' => 'language'], static function () {
        Route::get('set-language/{lang}', [LanguageController::class, 'setLanguage'])->name('language.set-current');
        Route::get('download/panel', [LanguageController::class, 'downloadPanelFile'])->name('language.download.panel.json');
        Route::get('download/app', [LanguageController::class, 'downloadAppFile'])->name('language.download.app.json');
        Route::get('download/web', [LanguageController::class, 'downloadWebFile'])->name('language.download.web.json');

        Route::put('/language/update/{id}/{type}', [LanguageController::class, 'updatelanguage'])->name('updatelanguage');
        Route::get('languageedit/{id}/{type}', [LanguageController::class, 'editLanguage'])->name('languageedit');
    });

    Route::resource('language', LanguageController::class);



    /* --------------------------------- SEO --------------------------------- */
    Route::resource('seo-setting', SeoSettingController::class);



    /* --------------------------------- ط·آ§ط¸â€‍ط¸â€¦ط¸ث†ط·آ¸ط¸ظ¾ط¸ث†ط¸â€  Staff --------------------------------- */
    Route::group(['prefix' => 'staff'], static function () {
        Route::put('/{id}/change-password', [StaffController::class, 'changePassword'])->name('staff.change-password');
    });

    Route::resource('staff', StaffController::class);



    /* --------------------------------- ط·آ§ط¸â€‍ط·آ¹ط¸â€¦ط¸â€‍ط·آ§ط·طŒ Customers --------------------------------- */
    Route::group(['prefix' => 'customer'], static function () {
        Route::post('/assign-package', [CustomersController::class, 'assignPackage'])->name('customer.assign.package');
        Route::post('/additional-info', [CustomersController::class, 'updateAdditionalInfo'])->name('customer.update.additional.info');
    });

    Route::group(['middleware' => ['permission:customer-list|customer-update']], static function () {
        Route::get('/customer', [CustomersController::class, 'index'])->name('customer.index');
        Route::put('/customer', [CustomersController::class, 'update'])->name('customer.update');
        Route::get('/customer/list', [CustomersController::class, 'list'])->name('customer.list');
        Route::get('/customer/show/{id}', [CustomersController::class, 'showDetails'])->name('customer.show');
    });

    Route::resource('customer', CustomersController::class)->except(['index', 'update', 'show']);



    /* --------------------------------- ط·آ§ط¸â€‍ط·آ³ط¸â€‍ط·آ§ط¸ظ¹ط·آ¯ط·آ± Slider --------------------------------- */
    Route::resource('slider', SliderController::class);
    Route::resource('featured-ads-configs', AdminFeaturedAdsConfigController::class)
        ->except(['show']);
    Route::get('slider/metrics/summary', [SliderController::class, 'metricsSummary'])->name('slider.metrics.summary');
    Route::get('slider/defaults/create', [SliderController::class, 'createDefault'])->name('slider.defaults.create');
    Route::post('slider/defaults', [SliderController::class, 'storeDefault'])->name('slider.defaults.store');
    Route::delete('slider/defaults/{sliderDefault}', [SliderController::class, 'destroyDefault'])->name('slider.defaults.destroy');


    /* --------------------------------- ط·آ§ط¸â€‍ط·آ¨ط·آ§ط¸â€ڑط·آ§ط·ع¾ Packages --------------------------------- */
    Route::group(['prefix' => 'package'], static function () {
        Route::get('/advertisement', [PackageController::class, 'advertisementIndex'])->name('package.advertisement.index');
        Route::get('/advertisement/show', [PackageController::class, 'advertisementShow'])->name('package.advertisement.show');
        Route::post('/advertisement/store', [PackageController::class, 'advertisementStore'])->name('package.advertisement.store');
        Route::put('/advertisement/{id}/update', [PackageController::class, 'advertisementUpdate'])->name('package.advertisement.update');

        Route::get('/users/', [PackageController::class, 'userPackagesIndex'])->name('package.users.index');
        Route::get('/users/show', [PackageController::class, 'userPackagesShow'])->name('package.users.show');

        Route::get('/payment-transactions/', [PackageController::class, 'paymentTransactionIndex'])->name('package.payment-transactions.index');
        Route::get('/payment-transactions/show', [PackageController::class, 'paymentTransactionShow'])->name('package.payment-transactions.show');
    });

    Route::resource('package', PackageController::class);



    /* --------------------------------- ط·آ£ط·آ³ط·آ¨ط·آ§ط·آ¨ ط·آ§ط¸â€‍ط·آ¨ط¸â€‍ط·آ§ط·ط›ط·آ§ط·ع¾ Report Reasons --------------------------------- */
    Route::group(['prefix' => 'report-reasons'], static function () {
        Route::get('/user-report', [ReportReasonController::class, 'usersReports'])->name('report-reasons.user-reports.index');
        Route::get('/user-report/show', [ReportReasonController::class, 'userReportsShow'])->name('report-reasons.user-reports.show');
    });

    Route::resource('report-reasons', ReportReasonController::class);



    /* --------------------------------- ط·آ§ط¸â€‍ط·آ¥ط·آ´ط·آ¹ط·آ§ط·آ±ط·آ§ط·ع¾ Notifications --------------------------------- */
    Route::group(['prefix' => 'notification'], static function () {
        Route::delete('/batch-delete', [NotificationController::class, 'batchDelete'])->name('notification.batch.delete');
});

Route::middleware(['permission:manual-payments-review'])->group(static function () {
    Route::get('delivery/requests', [\App\Http\Controllers\DeliveryRequestController::class, 'index'])
        ->name('delivery.requests.index');
    Route::get('delivery/requests/{deliveryRequest}', [\App\Http\Controllers\DeliveryRequestController::class, 'show'])
        ->name('delivery.requests.show');
    Route::patch('delivery/requests/{deliveryRequest}', [\App\Http\Controllers\DeliveryRequestController::class, 'update'])
        ->name('delivery.requests.update');
    Route::post('delivery/requests/{deliveryRequest}/notify', [\App\Http\Controllers\DeliveryRequestController::class, 'notifyAgent'])
        ->name('delivery.requests.notify');
    Route::get('delivery/agents', [\App\Http\Controllers\DeliveryAgentController::class, 'index'])
        ->name('delivery.agents.index');
    Route::post('delivery/agents', [\App\Http\Controllers\DeliveryAgentController::class, 'store'])
        ->name('delivery.agents.store');
    Route::post('delivery/agents/{deliveryAgent}/toggle', [\App\Http\Controllers\DeliveryAgentController::class, 'toggle'])
        ->name('delivery.agents.toggle');
    Route::delete('delivery/agents/{deliveryAgent}', [\App\Http\Controllers\DeliveryAgentController::class, 'destroy'])
        ->name('delivery.agents.destroy');
});

    Route::prefix('notification/campaigns')->as('notification.campaigns.')->group(function () {
        Route::post('/', [MarketingCampaignController::class, 'store'])->name('store');
        Route::put('{campaign}', [MarketingCampaignController::class, 'update'])->name('update');
        Route::post('{campaign}/schedule', [MarketingCampaignController::class, 'schedule'])->name('schedule');
        Route::post('{campaign}/send', [MarketingCampaignController::class, 'sendCampaign'])->name('send');




    });

    Route::post('notification/automation/trigger', [MarketingCampaignController::class, 'triggerAutomation'])
        ->name('notification.automation.trigger');

    Route::resource('notification', NotificationController::class);



    /* --------------------------------- ط·آ§ط¸â€‍ط·آ£ط·آ¯ط¸ث†ط·آ§ط·آ± Roles --------------------------------- */
    Route::get("/roles-list", [RoleController::class, 'list'])->name('roles.list');
    Route::resource('roles', RoleController::class);



    /* --------------------------------- ط·آ§ط¸â€‍ط¸â€ ط·آµط·آ§ط·آ¦ط·آ­ Tips --------------------------------- */
    Route::resource('tips', TipController::class);



    /* ------------------------------ ط·آ§ط¸â€‍ط¸â€¦ط·آ¯ط¸ث†ط¸â€کط¸â€ ط·آ© Blog (ط·آ§ط¸â€‍ط¸â€¦ط·آ·ط¸â€‍ط¸ث†ط·آ¨) ------------------------------ */
    // أ¢إ“â€¦ ط¸â€،ط·آ°ط·آ§ ط·آ§ط¸â€‍ط·آ³ط·آ·ط·آ± ط¸ظ¹ط¸â€ ط·آ´ط·آ¦ ط·آ¬ط¸â€¦ط¸ظ¹ط·آ¹ ط¸â€¦ط·آ³ط·آ§ط·آ±ط·آ§ط·ع¾ CRUD ط·آ§ط¸â€‍ط¸â€ڑط¸ظ¹ط·آ§ط·آ³ط¸ظ¹ط·آ© ط¸ث†ط·آ£ط¸â€،ط¸â€¦ط¸â€،ط·آ§: blog.index
    // ط·آ¥ط·آ°ط·آ§ ط¸ئ’ط·آ§ط¸â€ ط·ع¾ ط·آ§ط¸â€‍ط¸ث†ط·آ§ط·آ¬ط¸â€،ط·آ© (ط·آ§ط¸â€‍ط¸â€ڑط·آ§ط·آ¦ط¸â€¦ط·آ© ط·آ§ط¸â€‍ط·آ¬ط·آ§ط¸â€ ط·آ¨ط¸ظ¹ط·آ©) ط·ع¾ط¸â€ ط·آ§ط·آ¯ط¸ظ¹ route('blog.index') ط·آ³ط¸ظ¹ط·آ¹ط¸â€¦ط¸â€‍ ط·آ§ط¸â€‍ط·آ¢ط¸â€ .
    Route::resource('blog', BlogController::class);
    // ط¸â€¦ط¸â€‍ط·آ§ط·آ­ط·آ¸ط·آ©: ط¸â€‍ط¸ث† ط·آ±ط·ط›ط·آ¨ط·ع¾ ط¸â€‍ط·آ§ط·آ­ط¸â€ڑط¸â€¹ط·آ§ ط·آ¨ط¸ث†ط·آ¶ط·آ¹ ط·آµط¸â€‍ط·آ§ط·آ­ط¸ظ¹ط·آ§ط·ع¾ ط·آ£ط¸ث† Prefix ط¸â€¦ط·آ¹ط¸ظ¹ط¸â€کط¸â€ ط·إ’ ط¸ظ¹ط¸â€¦ط¸ئ’ط¸â€  ط·ع¾ط·ط›ط¸â€‍ط¸ظ¹ط¸ظ¾ط¸â€،ط·آ§ ط·آ¨ط¸â‚¬ Route::prefix()->name()->middleware()



    /* --------------------------------- ط·آ§ط¸â€‍ط·آ£ط·آ³ط·آ¦ط¸â€‍ط·آ© ط·آ§ط¸â€‍ط·آ´ط·آ§ط·آ¦ط·آ¹ط·آ© FAQ --------------------------------- */
    Route::resource('faq', FaqController::class);



    /* --------------------------------- ط·آ§ط¸â€‍ط·آ¯ط¸ث†ط¸â€‍/ط·آ§ط¸â€‍ط¸â€¦ط·آ¯ط¸â€ /ط·آ§ط¸â€‍ط¸â€¦ط¸â€ ط·آ§ط·آ·ط¸â€ڑ --------------------------------- */
    Route::group(['prefix' => 'countries'], static function () {
        Route::get("/", [PlaceController::class, 'countryIndex'])->name('countries.index');
        Route::get("/show", [PlaceController::class, 'countryShow'])->name('countries.show');
        Route::post("/import", [PlaceController::class, 'importCountry'])->name('countries.import');
        Route::delete("/{id}/delete", [PlaceController::class, 'destroyCountry'])->name('countries.destroy');
    });

    Route::group(['prefix' => 'states'], static function () {
        Route::get("/", [PlaceController::class, 'stateIndex'])->name('states.index');
        Route::get("/show", [PlaceController::class, 'stateShow'])->name('states.show');
        Route::get("/search", [PlaceController::class, 'stateSearch'])->name('states.search');
    });

    Route::group(['prefix' => 'cities'], static function () {
        Route::get("/", [PlaceController::class, 'cityIndex'])->name('cities.index');
        Route::get("/show", [PlaceController::class, 'cityShow'])->name('cities.show');
        Route::get("/search", [PlaceController::class, 'citySearch'])->name('cities.search');
    });

    /* ط·آ§ط¸â€‍ط¸â€¦ط¸â€ ط·آ§ط·آ·ط¸â€ڑ Area */
    Route::group(['prefix' => 'area'], static function () {
        Route::get('/', [PlaceController::class, 'createArea'])->name('area.index');
        Route::post('/create', [PlaceController::class, 'addArea'])->name('area.create');
        Route::get("/show/{id}", [PlaceController::class, 'areaShow'])->name('area.show');
        Route::put("/{id}/update-area", [PlaceController::class, 'updateArea'])->name('area.update');
        Route::delete("/{id}/delete-area", [PlaceController::class, 'destroyArea'])->name('area.destroy');

        Route::post('/create-city', [PlaceController::class, 'addCity'])->name('city.create');
        Route::put("/{id}/update", [PlaceController::class, 'updateCity'])->name('city.update');
        Route::delete("/{id}/delete", [PlaceController::class, 'destroyCity'])->name('city.destroy');
    });



    /* --------------------------------- ط·ع¾ط¸ث†ط·آ§ط·آµط¸â€‍ ط¸â€¦ط·آ¹ط¸â€ ط·آ§ (ط·آ¥ط·آ¯ط·آ§ط·آ±ط¸ظ¹) --------------------------------- */
    Route::group(['prefix' => 'contact-us'], function () {
        Route::get('/', [FaqController::class, 'contactUsIndex'])->name('contact-us.index');
        Route::get('/show', [FaqController::class, 'contactUsShow'])->name('contact-us.show');
        Route::delete('/{id}', [FaqController::class, 'contactUsDelete'])->name('contact-us.delete');
    });



    /* --------------------------------- ط·آ¥ط·آ¯ط·آ§ط·آ±ط·آ© ط·آ§ط¸â€‍ط·آ·ط¸â€‍ط·آ¨ط·آ§ط·ع¾ --------------------------------- */


    Route::get('orders/{order}/invoice.pdf', [OrderDocumentController::class, 'invoice'])->name('orders.invoice.pdf');
    Route::get('orders/{order}/invoice/preview', [OrderDocumentController::class, 'preview'])
        ->name('orders.invoice.preview')
        ->middleware(['signed', 'throttle:60,1']);

    Route::get('orders/{order}/deposit-receipts', [OrderDocumentController::class, 'depositReceipts'])->name('orders.deposit-receipts');
    Route::post('orders/{order}/manual-payments', [OrderPaymentActionController::class, 'storeManualPayment'])->name('orders.manual-payments.store');
    Route::post('orders/{order}/notifications', [OrderPaymentActionController::class, 'sendInstantNotification'])->name('orders.notifications.send');

    Route::post('orders/{order}/payment-groups', [OrderPaymentGroupController::class, 'store'])->name('orders.payment-groups.store');
    Route::get('orders/payment-groups/{group}', [OrderPaymentGroupController::class, 'show'])->name('orders.payment-groups.show');
    Route::post('orders/payment-groups/{group}/orders', [OrderPaymentGroupController::class, 'addOrders'])->name('orders.payment-groups.orders.store');
    Route::post('orders/payment-groups/{group}/bulk-update', [OrderPaymentGroupController::class, 'bulkUpdate'])->name('orders.payment-groups.bulk-update');

    Route::resource('orders', OrderController::class);




    /* --------------------------------- ط·آ®ط·آ¯ط¸â€¦ط·آ§ط·ع¾ ط·آ§ط¸â€‍ط·ع¾ط¸ث†ط·آµط¸ظ¹ط¸â€‍ --------------------------------- */


    Route::group(['prefix' => 'delivery-prices', 'as' => 'delivery-prices.'], function () {
        Route::get('/', [DeliveryPriceController::class, 'index'])->name('index');
        Route::get('/create', [DeliveryPriceController::class, 'create'])->name('create');
        Route::get('/{deliveryPrice}/edit', [DeliveryPriceController::class, 'edit'])->name('edit');
        Route::put('/policies/{policy}', [DeliveryPriceController::class, 'updatePolicy'])->name('policies.update');
        Route::post('/policies/{policy}/weight-tiers', [DeliveryPriceController::class, 'storeWeightTier'])->name('weight-tiers.store');
        Route::put('/weight-tiers/{weightTier}', [DeliveryPriceController::class, 'updateWeightTier'])->name('weight-tiers.update');
        Route::delete('/weight-tiers/{weightTier}', [DeliveryPriceController::class, 'destroyWeightTier'])->name('weight-tiers.destroy');

        Route::post('/', [DeliveryPriceController::class, 'store'])->name('store');

        Route::put('/{deliveryPrice}', [DeliveryPriceController::class, 'update'])->name('update');
        Route::delete('/{deliveryPrice}', [DeliveryPriceController::class, 'destroy'])->name('destroy');
        Route::put('/{deliveryPrice}/toggle-status', [DeliveryPriceController::class, 'toggleStatus'])->name('toggle-status');
    });




    /* --------------------------------- ط·آ§ط¸â€‍ط¸ئ’ط¸ث†ط·آ¨ط¸ث†ط¸â€   --------------------------------- */

    Route::resource('coupons', CouponController::class)->except(['show', 'destroy']);





    /* --------------------------------- ط·آ§ط¸â€‍ط·ع¾ط¸â€ڑط·آ§ط·آ±ط¸ظ¹ط·آ± --------------------------------- */
    Route::group(['prefix' => 'reports', 'as' => 'reports.'], function () {
        Route::get('/', [OrderReportController::class, 'index'])->name('index');
        Route::get('/sales', [OrderReportController::class, 'sales'])->name('sales');
        Route::get('/customers', [OrderReportController::class, 'customers'])->name('customers');
        Route::get('/payment-requests', [OrderReportController::class, 'manualPayments'])->name('payment-requests');
        Route::get('/statuses', [OrderReportController::class, 'statuses'])->name('statuses');


                Route::group([
            'prefix' => 'payment-requests',
            'as' => 'payment-requests.',
            'middleware' => ['permission:reports-orders'],
        ], function () {
            Route::get('/list', [OrderReportController::class, 'manualPaymentsList'])->name('list');
            Route::get('/{manualPaymentRequest}', [OrderReportController::class, 'manualPaymentsShow'])->name('show');
        });
    });



    /* --------------------------------- API ط·آ¯ط·آ§ط·آ®ط¸â€‍ط¸ظ¹ ط¸â€‍ط¸â€‍ط¸ث†ط·آ­ط·آ© --------------------------------- */
    Route::group(['prefix' => 'api'], function () {
        Route::get('/items/search', [ItemController::class, 'search'])->name('api.items.search.alt');
    });

    // ط·آ§ط·آ®ط·ع¾ط·آµط·آ§ط·آ± ط¸â€‍ط¸â€‍ط·آ¨ط·آ­ط·آ« ط¸â€ ط¸ظ¾ط·آ³ط¸â€، ط·آ®ط·آ§ط·آ±ط·آ¬ /api
    Route::get('/items/search', [ItemController::class, 'search'])->name('api.items.search');

}); // ط¸â€ ط¸â€،ط·آ§ط¸ظ¹ط·آ© ط¸â€¦ط·آ¬ط¸â€¦ط¸ث†ط·آ¹ط·آ© (auth, language)



/* ------------------------------- ط·آ±ط¸ث†ط·آ§ط·آ¨ط·آ· ط·آ¹ط·آ§ط¸â€¦ط·آ© ط·آ£ط·آ®ط·آ±ط¸â€° ------------------------------- */

Route::get('/product-details/{slug}', [SettingController::class, 'webPageURL'])->name('deep-link');
Route::get('payment-requests/open/{paymentTransaction}', [ManualPaymentRequestController::class, 'deepLink'])->name('payment-requests.deep-link');

Route::get(
    'payment-requests/review-transaction/{paymentTransaction}',
    [ManualPaymentRequestController::class, 'reviewTransaction']
)->name('payment-requests.review-transaction')->middleware('can:manual-payments-review');

/* ----------------------- ط·آ£ط·آ¯ط¸ث†ط·آ§ط·ع¾ ط·آµط¸ظ¹ط·آ§ط¸â€ ط·آ© (ط¸â€‍ط¸â€‍ط·آ§ط·آ³ط·ع¾ط·آ®ط·آ¯ط·آ§ط¸â€¦ ط·آ¨ط·آ­ط·آ°ط·آ±) ----------------------- */

Route::get('/migrate', static function () {
    Artisan::call('migrate');
    echo Artisan::output();
});

Route::get('/migrate-rollback', static function () {
    Artisan::call('migrate:rollback');
    echo "done";
});

Route::get('/seeder', static function () {
    Artisan::call('db:seed --class=SystemUpgradeSeeder');
    return redirect()->back();
});

Route::get('clear', static function () {
    Artisan::call('config:clear');
    Artisan::call('view:clear');
    Artisan::call('cache:clear');
    Artisan::call('optimize:clear');
    Artisan::call('debugbar:clear');
    return redirect()->back();
});

Route::get('storage-link', static function () {
    Artisan::call('storage:link');
});



/* ----------------------------- ط·آ£ط·آ¯ط·آ§ط·آ© ط·ع¾ط·آ±ط·آ¬ط¸â€¦ط·آ© ط·ع¾ط¸â€‍ط¸â€ڑط·آ§ط·آ¦ط¸ظ¹ط·آ© ----------------------------- */

Route::get('auto-translate/{id}/{type}/{locale}', function ($id, $type, $locale) {
    \Log::info("Running auto-translate with ID: $id, Type: $type, Locale: $locale");

    $exitCode = Artisan::call('custom:translate-missing', [
        'type' => $type,
        'locale' => $locale
    ]);

    if ($exitCode === 0) {
        \Log::info("Auto translation completed successfully.");

        return redirect()
            ->route('languageedit', ['id' => $id, 'type' => $type])
            ->with('success', 'Auto translation completed successfully.');
    } else {
        \Log::error("Auto translation failed with exit code: $exitCode");

        return redirect()
            ->route('languageedit', ['id' => $id, 'type' => $type])
            ->with('error', 'Auto translation failed.');
    }
})->name('auto-translate');



/* --------------------------- ط¸â€¦ط·آ±ط·آ§ط¸â€ڑط·آ¨ط·آ© ط·آ§ط¸â€‍ط¸â€¦ط·آ­ط·آ§ط·آ¯ط·آ«ط·آ§ط·ع¾ (ط¸â€‍ط¸ث†ط·آ­ط·آ©) --------------------------- */

Route::prefix('chat-monitor')->name('chat-monitor.')->middleware(['auth'])->group(function () {
    Route::get('/', [App\Http\Controllers\ChatMonitorController::class, 'index'])->name('index');
    Route::get('/conversations', [App\Http\Controllers\ChatMonitorController::class, 'conversations'])->name('conversations');
    Route::get('/view-conversation/{id}', [App\Http\Controllers\ChatMonitorController::class, 'viewConversation'])->name('view-conversation');
    Route::get('/delete-conversation/{id}', [App\Http\Controllers\ChatMonitorController::class, 'deleteConversation'])->name('delete-conversation');
    Route::get('/search', [App\Http\Controllers\ChatMonitorController::class, 'search'])->name('search');
    Route::get('/statistics', [App\Http\Controllers\ChatMonitorController::class, 'statistics'])->name('statistics');

    Route::post('/{conversation}/assign', [App\Http\Controllers\ChatMonitorController::class, 'assign'])->name('assign');
    Route::post('/tickets', [App\Http\Controllers\ChatMonitorController::class, 'storeTicket'])->name('tickets.store');
    Route::post('/tickets/{ticket}/status', [App\Http\Controllers\ChatMonitorController::class, 'updateTicketStatus'])->name('tickets.update-status');


    // ط¸ظ¾ط·آ­ط·آµ ط·آ³ط·آ±ط¸ظ¹ط·آ¹ ط¸â€‍ط¸â€¦ط·آ­ط·آ§ط·آ¯ط·آ«ط·آ© ط¸â€¦ط·آ¹ط¸ظ¹ط¸â€ ط·آ© (ط¸â€‍ط¸â€‍ط·آ§ط·آ®ط·ع¾ط·آ¨ط·آ§ط·آ±/ط·آ§ط¸â€‍ط·ع¾ط·آ´ط·آ®ط¸ظ¹ط·آµ)
    Route::get('/test-conversation/{id}', function($id) {
        try {


            $conversation = \App\Models\Chat::with([
                    'messages' => function ($query) {
                        $query->orderBy('created_at', 'asc');
                    },
                    'participants'
                ])->where('item_offer_id', $id)->first();

            if (!$conversation && is_numeric($id)) {
                $conversation = \App\Models\Chat::with([
                        'messages' => function ($query) {
                            $query->orderBy('created_at', 'asc');
                        },
                        'participants'
                    ])->find($id);
            }


            if (!$conversation) {
                return response()->json([
                    'error'   => true,
                    'message' => 'ط·آ§ط¸â€‍ط¸â€¦ط·آ­ط·آ§ط·آ¯ط·آ«ط·آ© ط·ط›ط¸ظ¹ط·آ± ط¸â€¦ط¸ث†ط·آ¬ط¸ث†ط·آ¯ط·آ©'
                ]);
            }

            $messages = $conversation->messages;

            $userIds = $conversation->participants->pluck('id')
                ->merge($messages->pluck('sender_id'))
                ->unique()
                ->values();
                
                
                $users   = \App\Models\User::whereIn('id', $userIds)->get();

            $usersArray = [];
            foreach ($users as $user) {
                $usersArray[$user->id] = [
                    'id'    => $user->id,
                    'name'  => $user->name,
                    'email' => $user->email,
                    'image' => $user->image ? url($user->image) : null
                ];
            }

            return response()->json([
                'success'          => true,
                'id'               => $conversation->item_offer_id,
                'conversation_id'  => $conversation->id,
                'chats_count'      => $messages->count(),
                'users_count'      => count($usersArray),
                'chats'            => $messages->values()->toArray(),
                'users'            => $usersArray

                
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'error'   => true,
                'message' => $e->getMessage(),
                'trace'   => $e->getTraceAsString()
            ]);
        }
    })->name('test-conversation');
});



/* ------------------------------ ط·آ±ط¸ث†ط·آ§ط·آ¨ط·آ· ط·آ¥ط·آ¶ط·آ§ط¸ظ¾ط¸ظ¹ط·آ© ط¸â€¦ط·ع¾ط¸ظ¾ط·آ±ط¸â€ڑط·آ© ------------------------------ */

