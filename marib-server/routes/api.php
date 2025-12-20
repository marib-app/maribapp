<?php



use App\Http\Controllers\AddressController;
use App\Http\Controllers\Api\DeliveryPriceCalculatorController;
use App\Http\Controllers\Api\MetalRateController as PublicMetalRateController;
use App\Http\Controllers\Api\MetalRateManagementController;
use App\Http\Controllers\Api\AdDraftController;
use App\Http\Controllers\Api\StoreDashboardController as ApiStoreDashboardController;
use App\Http\Controllers\Api\StoreManualPaymentController as ApiStoreManualPaymentController;
use App\Http\Controllers\Api\StoreOrderController as ApiStoreOrderController;
use App\Http\Controllers\Api\StoreGatewayAccountController;
use App\Http\Controllers\Api\StoreGatewayController;
use App\Http\Controllers\Api\StoreGatewayPublicController;
use App\Http\Controllers\Api\StoreOnboardingController;
use App\Http\Controllers\Api\StorefrontController;
use App\Http\Controllers\Api\StorefrontUiController;
use App\Http\Controllers\Api\NotificationInboxController;
use App\Http\Controllers\Api\NotificationPreferenceController;
use App\Http\Controllers\Api\FeaturedAdsConfigController;
use App\Http\Controllers\Api\NotificationTopicController;
use App\Http\Controllers\Api\NotificationPaymentController;
use App\Http\Controllers\Api\ActionRequestController;
use App\Http\Controllers\ApiController;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\ServiceRequestController as ApiServiceRequestController;
use App\Http\Middleware\InitializeApiMetrics;
use App\Http\Controllers\CartController;
use App\Http\Controllers\CartShippingQuoteController;
use App\Http\Controllers\OrderApiController;
use App\Http\Controllers\Api\PaymentController as ApiPaymentController;
use App\Http\Controllers\PaymentController as LegacyPaymentController;
use App\Http\Controllers\Payments\PaymentWebhookController;
use App\Http\Controllers\ProductPurchaseOptionsController;
use App\Http\Controllers\ItemPurchaseManagementController;
use App\Http\Controllers\Api\UserPreferenceController;
use App\Http\Controllers\Wifi\AdminModerationController;
use App\Http\Controllers\Wifi\OwnerBatchController;
use App\Http\Controllers\Wifi\OwnerNetworkController;
use App\Http\Controllers\Wifi\OwnerPlanController;
use App\Http\Controllers\Admin\AdminAuthController;
use App\Http\Controllers\Wifi\PublicDiscoveryController;
use App\Http\Controllers\Api\WebExperienceController;


Route::get('diag', fn() => response('ok', 200));


/*
|--------------------------------------------------------------------------
| API Routes
|--------------------------------------------------------------------------
|
| Here is where you can register API routes for your application. These
| routes are loaded by the RouteServiceProvider within a group which
| is assigned the "api" middleware group. Enjoy building your API!
|
*/


Route::middleware(InitializeApiMetrics::class)
    ->get('ping', fn () => response()->json(['ok' => true]))
    ->name('ping');

Route::get('storefront/ui-config', [StorefrontUiController::class, 'show'])->name('api.storefront.ui-config');
    
Route::prefix('admin')->group(function (): void {
    Route::post('login', [AdminAuthController::class, 'login'])->name('admin.api.login');

    Route::middleware(['auth:sanctum', 'ability:admin:full'])->group(function (): void {
        Route::get('me', [AdminAuthController::class, 'me'])->name('admin.api.me');
        Route::post('logout', [AdminAuthController::class, 'logout'])->name('admin.api.logout');
    });
});

Route::prefix('wifi')->group(function (): void {
    Route::get('networks', [PublicDiscoveryController::class, 'networks']);
    Route::get('plans', [PublicDiscoveryController::class, 'plans']);
});

Route::get('products/{item}/purchase-options', [ProductPurchaseOptionsController::class, 'show'])
    ->whereNumber('item');
Route::get('metal-rates', [PublicMetalRateController::class, 'index']);
Route::get('get-featured-section', [ApiController::class, 'getFeaturedSections']);
Route::get('web/experience', WebExperienceController::class)
    ->middleware('web-experience.cors');

// Featured ads config (admin only)
Route::middleware(['auth:sanctum', 'ability:admin:full'])->group(function (): void {
    Route::get('featured-ads-configs', [FeaturedAdsConfigController::class, 'index']);
    Route::post('featured-ads-configs', [FeaturedAdsConfigController::class, 'store']);
    Route::get('featured-ads-configs/{featuredAdsConfig}', [FeaturedAdsConfigController::class, 'show']);
    Route::put('featured-ads-configs/{featuredAdsConfig}', [FeaturedAdsConfigController::class, 'update']);
    Route::delete('featured-ads-configs/{featuredAdsConfig}', [FeaturedAdsConfigController::class, 'destroy']);
});

    



/* Authenticated Routes */
Route::group(['middleware' => ['auth:sanctum']], static function () {
    Route::get('notifications', [NotificationInboxController::class, 'index']);
    Route::get('notifications/unread-count', [NotificationInboxController::class, 'unreadCount']);
    Route::post('notifications/mark-read', [NotificationInboxController::class, 'markRead']);
    Route::post('notifications/mark-all-read', [NotificationInboxController::class, 'markAllRead']);
    Route::post('notifications/{delivery}/payment-request', [NotificationPaymentController::class, 'update'])
        ->whereNumber('delivery');

    Route::get('notification-preferences', [NotificationPreferenceController::class, 'index']);
    Route::post('notification-preferences', [NotificationPreferenceController::class, 'store']);

    Route::get('topics', [NotificationTopicController::class, 'index']);
    Route::post('topics/subscribe', [NotificationTopicController::class, 'subscribe']);
    Route::post('topics/unsubscribe', [NotificationTopicController::class, 'unsubscribe']);

    Route::get('action-requests/{actionRequest}', [ActionRequestController::class, 'show'])
        ->whereUuid('actionRequest');
    Route::post('action-requests/{actionRequest}/perform', [ActionRequestController::class, 'perform'])
        ->whereUuid('actionRequest');


    Route::prefix('store')->group(function (): void {
        Route::get('dashboard/summary', [ApiStoreDashboardController::class, 'summary']);
        Route::get('orders', [ApiStoreOrderController::class, 'index']);
        Route::post('orders/{order}/status', [ApiStoreOrderController::class, 'updateStatus'])->whereNumber('order');
        Route::get('manual-payments', [ApiStoreManualPaymentController::class, 'index']);
        Route::get('manual-payments/{manualPaymentRequest}', [ApiStoreManualPaymentController::class, 'show'])
            ->whereNumber('manualPaymentRequest');
        Route::post('manual-payments/{manualPaymentRequest}/decision', [ApiStoreManualPaymentController::class, 'decide'])
            ->whereNumber('manualPaymentRequest');
    });

    Route::prefix('wifi/owner')->group(function (): void {
        Route::get('networks', [OwnerNetworkController::class, 'index']);
        Route::post('networks', [OwnerNetworkController::class, 'store']);
        Route::get('networks/{network}', [OwnerNetworkController::class, 'show'])->whereNumber('network');
        Route::match(['put', 'patch'], 'networks/{network}', [OwnerNetworkController::class, 'update'])->whereNumber('network');
        Route::delete('networks/{network}', [OwnerNetworkController::class, 'destroy'])->whereNumber('network');
        Route::patch('networks/{network}/commission', [OwnerNetworkController::class, 'setCommission'])->whereNumber('network');
        Route::patch('networks/{network}/availability', [OwnerNetworkController::class, 'toggleAvailability'])->whereNumber('network');
        Route::get('networks/{network}/stats', [OwnerNetworkController::class, 'stats'])->whereNumber('network');
        Route::get('networks/{network}/codes', [OwnerNetworkController::class, 'codes'])->whereNumber('network');

    Route::get('networks/{network}/plans', [OwnerPlanController::class, 'index'])->whereNumber('network');
    Route::post('networks/{network}/plans', [OwnerPlanController::class, 'store'])->whereNumber('network');
        Route::get('plans/{plan}', [OwnerPlanController::class, 'show'])->whereNumber('plan');
        Route::match(['put', 'patch'], 'plans/{plan}', [OwnerPlanController::class, 'update'])->whereNumber('plan');
        Route::delete('plans/{plan}', [OwnerPlanController::class, 'destroy'])->whereNumber('plan');

        Route::get('plans/{plan}/batches', [OwnerBatchController::class, 'index'])->whereNumber('plan');
        Route::post('plans/{plan}/batches', [OwnerBatchController::class, 'store'])->whereNumber('plan');
        Route::get('batches/{batch}', [OwnerBatchController::class, 'show'])->whereNumber('batch');
        Route::patch('batches/{batch}/status', [OwnerBatchController::class, 'updateStatus'])->whereNumber('batch');
        Route::delete('batches/{batch}', [OwnerBatchController::class, 'destroy'])->whereNumber('batch');
    });

    // Wifi plan purchase code reveal (after successful payment)
    Route::get('wifi/orders/{transaction}/code', [\App\Http\Controllers\Wifi\WifiOrderController::class, 'revealCode'])
        ->whereNumber('transaction');

    Route::middleware(['auth:sanctum', 'permission:wifi.admin|wifi-cabin-manage'])
        ->prefix('wifi/admin')
        ->group(function (): void {
            Route::get('networks', [AdminModerationController::class, 'networks']);
            Route::patch('networks/{network}/status', [AdminModerationController::class, 'updateNetworkStatus'])->whereNumber('network');

            Route::get('reports', [AdminModerationController::class, 'reports']);
            Route::patch('reports/{report}', [AdminModerationController::class, 'updateReport'])->whereNumber('report');

            Route::get('reputation-counters', [AdminModerationController::class, 'reputationCounters']);
            Route::post('networks/{network}/reputation-counters', [AdminModerationController::class, 'storeReputationCounter'])->whereNumber('network');
            Route::patch('reputation-counters/{counter}', [AdminModerationController::class, 'updateReputationCounter'])->whereNumber('counter');
        });

    Route::get('user/preferences', [UserPreferenceController::class, 'show']);
    Route::put('user/preferences', [UserPreferenceController::class, 'update']);

    Route::post('items/{item}/attributes', [ItemPurchaseManagementController::class, 'updateAttributes'])
        ->whereNumber('item');
    Route::post('admin/items/{item}/stock/bulk-set', [ItemPurchaseManagementController::class, 'bulkSetStock'])
        ->whereNumber('item');
    Route::patch('items/{item}/discount', [ItemPurchaseManagementController::class, 'updateDiscount'])
        ->whereNumber('item');






    Route::get('get-package', [ApiController::class, 'getPackage']);
    Route::post('update-profile', [ApiController::class, 'updateProfile']);
    Route::post('complete-registration', [ApiController::class, 'completeRegistration']);
    Route::delete('delete-user', [ApiController::class, 'deleteUser']);
    Route::get('user-profile-stats', [ApiController::class, 'getUserProfileStats']);

    Route::get('my-items', [ApiController::class, 'getItem']);
    Route::post('add-item', [ApiController::class, 'addItem']);
    Route::post('update-item', [ApiController::class, 'updateItem']);
    Route::post('delete-item', [ApiController::class, 'deleteItem']);
    Route::post('update-item-status', [ApiController::class, 'updateItemStatus']);
    Route::get('item-buyer-list', [ApiController::class, 'getItemBuyerList']);

    Route::post('renew-item', [ApiController::class, 'renewItem']);
    Route::get('ads/featured/count', [ApiController::class, 'getFeaturedAdsCount']);
    Route::post('ads/{item}/unfeature', [ApiController::class, 'unfeatureAd'])->whereNumber('item');
    Route::post('assign-free-package', [ApiController::class, 'assignFreePackage']);
    Route::post('make-item-featured', [ApiController::class, 'makeFeaturedItem']);
    Route::post('manage-favourite', [ApiController::class, 'manageFavourite']);
    Route::post('add-reports', [ApiController::class, 'addReports']);
    Route::get('get-notification-list', [ApiController::class, 'getNotificationList']);
    Route::get('get-limits', [ApiController::class, 'getLimits']);
    Route::get('get-favourite-item', [ApiController::class, 'getFavouriteItem']);
    Route::get('delegates/sections', [ApiController::class, 'getAllowedSections']);

    Route::prefix('storefront')->group(function (): void {
        Route::post('stores/{store}/follow', [StorefrontController::class, 'follow']);
        Route::post('stores/{store}/unfollow', [StorefrontController::class, 'unfollow']);
    });

    Route::patch('addresses/{address}/default', [AddressController::class, 'setDefault'])
        ->whereNumber('address');
    Route::apiResource('addresses', AddressController::class);


    Route::get('get-payment-settings', [ApiController::class, 'getPaymentSettings']);
    Route::post('payment-intent', [ApiController::class, 'getPaymentIntent']);
    Route::get('payment-transactions', [ApiController::class, 'getPaymentTransactions']);

    Route::get('wallet', [ApiController::class, 'walletSummary']);
    Route::get('wallet/transactions', [ApiController::class, 'walletTransactions']);

    Route::get('wallet/withdrawals/options', [ApiController::class, 'walletWithdrawalOptions']);
    Route::post('wallet/withdrawals', [ApiController::class, 'storeWalletWithdrawalRequest']);

    Route::get('wallet/withdrawals', [ApiController::class, 'walletWithdrawalRequests']);
    Route::get('wallet/withdrawals/{withdrawalRequest}', [ApiController::class, 'showWalletWithdrawalRequest'])->whereNumber('withdrawalRequest');


    Route::post('wallet/transfers', [ApiController::class, 'transferRequest']);
    Route::get('wallet/recipients/lookup', [ApiController::class, 'walletRecipientLookup']);
    Route::get('wallet/recipients/{recipient}', [ApiController::class, 'walletRecipient'])
        ->whereNumber('recipient');
    Route::get('store-gateways', [StoreGatewayController::class, 'index']);
    Route::get('store-gateway-accounts', [StoreGatewayAccountController::class, 'index']);
    Route::post('store-gateway-accounts', [StoreGatewayAccountController::class, 'store']);
    Route::match(['put', 'patch'], 'store-gateway-accounts/{storeGatewayAccount}', [StoreGatewayAccountController::class, 'update'])
        ->whereNumber('storeGatewayAccount');
    Route::delete('store-gateway-accounts/{storeGatewayAccount}', [StoreGatewayAccountController::class, 'destroy'])
        ->whereNumber('storeGatewayAccount');

    Route::prefix('store')->group(function (): void {
        Route::get('onboarding', [StoreOnboardingController::class, 'show']);
        Route::post('onboarding', [StoreOnboardingController::class, 'store']);
    });

    Route::get('manual-banks', [ApiController::class, 'getManualBanks']);
    Route::get('manual-payments/banks', [ApiController::class, 'getManualBanks']);

    Route::post('manual-payment-requests', [ApiController::class, 'storeManualPaymentRequest']);
    Route::get('manual-payment-requests', [ApiController::class, 'getManualPaymentRequests']);
    Route::get('manual-payment-requests/{manualPaymentRequest}', [ApiController::class, 'showManualPaymentRequest']);

    Route::get('services/{service}', [ApiController::class, 'getManagedService'])->middleware('service.manager');


    Route::get('my-services', [ApiController::class, 'getOwnedServices']);
    Route::patch('my-services/{service}', [ApiController::class, 'updateOwnedService']);
    Route::delete('my-services/{service}', [ApiController::class, 'deleteOwnedService']);


    Route::get('service-requests', [ApiServiceRequestController::class, 'index']);
    Route::post('service-requests', [ApiServiceRequestController::class, 'store']);
    Route::get('service-requests/{service_request}', [ApiServiceRequestController::class, 'show'])
        ->whereNumber('service_request');
    Route::get('service-requests/{service_request}/purchase-options', [ApiServiceRequestController::class, 'purchaseOptions'])
        ->whereNumber('service_request');
    Route::post('services/requests', [ApiServiceRequestController::class, 'store']);



    /*Chat Module*/
    Route::post('item-offer', [ApiController::class, 'createItemOffer']);
    Route::get('chat-list', [ApiController::class, 'getChatList']);
    Route::post('send-message', [ApiController::class, 'sendMessage']);
    Route::post('mark-message-delivered', [ApiController::class, 'markMessageDelivered']);
    Route::post('mark-message-read', [ApiController::class, 'markMessageRead']);
    Route::get('chat-messages', [ApiController::class, 'getChatMessages']);

    Route::post('chat/conversations/{conversation}/typing', [ApiController::class, 'updateTypingStatus']);
    Route::post('chat/conversations/{conversation}/presence', [ApiController::class, 'updatePresenceStatus']);

    Route::post('in-app-purchase', [ApiController::class, 'inAppPurchase']);

    Route::post('block-user', [ApiController::class, 'blockUser']);
    Route::post('unblock-user', [ApiController::class, 'unblockUser']);
    Route::get('blocked-users', [ApiController::class, 'getBlockedUsers']);

    Route::post('add-item-review', [ApiController::class, 'addItemReview']);
    Route::get('my-review', [ApiController::class, 'getMyReview']);
    Route::post('add-review-report', [ApiController::class, 'addReviewReport']);
    Route::post('add-service-review', [ApiController::class, 'addServiceReview']);
    Route::get('my-service-reviews', [ApiController::class, 'getMyServiceReviews']);
    Route::post('add-service-review-report', [ApiController::class, 'addServiceReviewReport']);


    Route::get('cart', [CartController::class, 'index']);
    Route::get('checkout-info', [CartController::class, 'checkoutInfo']);
    Route::post('cart/items', [CartController::class, 'store']);
    Route::post('cart/add', [CartController::class, 'store']);
    Route::post('add-to-cart', [CartController::class, 'store']);
    Route::patch('cart/items/{cartItem}', [CartController::class, 'updateQuantity'])->whereNumber('cartItem');
    Route::patch('cart/items/{cartItem}/quantity', [CartController::class, 'updateQuantity'])->whereNumber('cartItem');
    Route::post('cart/items/{cartItem}/update', [CartController::class, 'updateQuantity'])->whereNumber('cartItem');
    Route::post('cart/apply-coupon', [CartController::class, 'applyCoupon']);
    Route::delete('cart/coupon', [CartController::class, 'removeCoupon']);
    Route::get('cart/delivery-payment-timing', [CartController::class, 'showDeliveryPaymentTiming']);
    Route::post('cart/delivery-payment-timing', [CartController::class, 'updateDeliveryPaymentTiming']);

    Route::post('cart/quote-shipping', CartShippingQuoteController::class);
    Route::delete('cart/items/{cartItem}', [CartController::class, 'destroy'])->whereNumber('cartItem');
    Route::delete('cart/items/{cartItem}/remove', [CartController::class, 'destroy'])->whereNumber('cartItem');
    Route::delete('cart/clear', [CartController::class, 'clear']);
    Route::post('cart/clear', [CartController::class, 'clear']);

    Route::get('orders', [OrderApiController::class, 'index']);
    Route::post('orders', [OrderApiController::class, 'store']);
    Route::get('orders/{order}', [OrderApiController::class, 'show'])->whereNumber('order');
    Route::post('orders/{order}/cancel', [OrderApiController::class, 'cancel'])->whereNumber('order');


    Route::post('orders/{order}/collect-delivery', [OrderApiController::class, 'collectDelivery'])->whereNumber('order');
    Route::get('orders/{order}/invoice.pdf', [OrderApiController::class, 'invoice'])->whereNumber('order');

    Route::post('payments/initiate', [ApiPaymentController::class, 'initiate'])
        ->middleware('throttle:payments-initiate');
    Route::post('payments/confirm', [ApiPaymentController::class, 'confirm']);
    Route::post('payments/manual', [LegacyPaymentController::class, 'manual']);


    Route::get('verification-fields', [ApiController::class, 'getVerificationFields']);
    Route::get('verification/metadata', [ApiController::class, 'getVerificationMetadata']);
    Route::post('send-verification-request',[ApiController::class,'sendVerificationRequest']);
Route::get('verification-request',[ApiController::class,'getVerificationRequest']);

});

Route::get('stores/{seller}/gateways', [StoreGatewayPublicController::class, 'index'])
    ->whereNumber('seller');

Route::prefix('storefront')->group(function (): void {
    Route::get('stores', [StorefrontController::class, 'index']);
    Route::get('stores/{store}', [StorefrontController::class, 'show']);
    Route::get('stores/{store}/products', [StorefrontController::class, 'products']);
    Route::get('stores/{store}/manual-banks', [StorefrontController::class, 'manualBankAccounts']);
    Route::get('stores/{store}/follow-status', [StorefrontController::class, 'followStatus']);
    Route::get('stores/{store}/reviews', [StorefrontController::class, 'reviews']);
    Route::middleware('auth:sanctum')->group(function (): void {
        Route::post('stores/{store}/reviews', [StorefrontController::class, 'addReview']);
        Route::put('stores/{store}/reviews', [StorefrontController::class, 'updateReview']);
        Route::delete('stores/{store}/reviews', [StorefrontController::class, 'deleteReview']);
    });
});

    
/* Non Authenticated Routes */
Route::get('get-package', [ApiController::class, 'getPackage']);
Route::get('get-languages', [ApiController::class, 'getLanguages']);
Route::post('user-signup', [ApiController::class, 'userSignup']);
Route::post('user-login', [ApiController::class, 'userLogin']);
Route::post('set-item-total-click', [ApiController::class, 'setItemTotalClick']);
Route::get('get-system-settings', [ApiController::class, 'getSystemSettings']);
Route::get('get-customfields', [ApiController::class, 'getCustomFields']);
Route::get('get-item', [ApiController::class, 'getItem']);
Route::get('get-slider', [ApiController::class, 'getSlider']);
Route::post('sliders/{slider}/click', [ApiController::class, 'recordSliderClick'])->whereNumber('slider');


Route::get('get-report-reasons', [ApiController::class, 'getReportReasons']);
Route::get('get-categories', [ApiController::class, 'getSubCategories']);
Route::get('get-parent-categories', [ApiController::class, 'getParentCategoryTree']);
Route::get('blogs', [ApiController::class, 'getBlog']);
Route::get('blog-tags', [ApiController::class, 'getAllBlogTags']);
Route::get('faq', [ApiController::class, 'getFaqs']);
Route::get('tips', [ApiController::class, 'getTips']);
Route::get('countries', [ApiController::class, 'getCountries']);
Route::get('states', [ApiController::class, 'getStates']);
Route::get('cities', [ApiController::class, 'getCities']);
Route::get('areas', [ApiController::class, 'getAreas']);
Route::get('seo-settings', [ApiController::class, 'seoSettings']);
Route::get('get-seller', [ApiController::class, 'getSeller']);
Route::get('get-services', [ApiController::class, 'getServices']);
Route::get('currency-rates', [ApiController::class, 'getCurrencyRates']);
Route::get('currency-rates/history', [\App\Http\Controllers\CurrencyHistoryController::class, 'index']);
Route::get('service-reviews', [ApiController::class, 'getServiceReviews']);


// Challenges and Referrals API
Route::get('challenges', [ApiController::class, 'getChallenges']);
Route::middleware('auth:sanctum')->get('user-referral-points', [ApiController::class, 'getUserReferralPoints']);

// User Orders API
Route::middleware('auth:sanctum')->get('user-orders', [ApiController::class, 'getUserOrders']);

// Delivery Prices API
Route::get('delivery-prices', [ApiController::class, 'getDeliveryPrices']);
Route::post('delivery-prices/calculate', DeliveryPriceCalculatorController::class);

Route::get('get-slider', [ApiController::class, 'getSlider']);
Route::get('users-by-account-type', [ApiController::class, 'getUsersByAccountType']);


Route::post('request-device', [ApiController::class, 'storeRequestDevice']);

Route::post('contact-us', [ApiController::class, 'storeContactUs']);

Route::post('send-otp', [ApiController::class, 'sendOtp']);
Route::post('verify-otp', [ApiController::class, 'verifyOtp']);
Route::post('update-password', [ApiController::class, 'updatePassword']);

Route::group([
    'prefix' => 'payments/webhook',
    'middleware' => ['throttle:api'],
], static function () {
    Route::post('wallet', [PaymentWebhookController::class, 'wallet'])->name('payments.webhook.wallet');
    Route::post('bank-alsharq', [PaymentWebhookController::class, 'bankAlsharq'])->name('payments.webhook.bank-alsharq');



});
    Route::group([
        'prefix' => 'admin/metal-rates',
        'middleware' => ['permission:metal-rate-list|metal-rate-create|metal-rate-edit|metal-rate-delete|metal-rate-schedule'],
    ], static function () {
        Route::get('/', [MetalRateManagementController::class, 'index']);
        Route::post('/', [MetalRateManagementController::class, 'store'])->middleware('permission:metal-rate-create');
        Route::get('/{metalRate}', [MetalRateManagementController::class, 'show'])->whereNumber('metalRate');
        Route::put('/{metalRate}', [MetalRateManagementController::class, 'update'])
            ->whereNumber('metalRate')
            ->middleware('permission:metal-rate-edit');
        Route::delete('/{metalRate}', [MetalRateManagementController::class, 'destroy'])
            ->whereNumber('metalRate')
            ->middleware('permission:metal-rate-delete');
        Route::post('/{metalRate}/schedule', [MetalRateManagementController::class, 'schedule'])
            ->whereNumber('metalRate')
            ->middleware('permission:metal-rate-schedule');
        Route::delete('/schedules/{metalRateUpdate}', [MetalRateManagementController::class, 'cancelSchedule'])
            ->whereNumber('metalRateUpdate')
            ->middleware('permission:metal-rate-schedule');
    });
    Route::post('ad-drafts', [AdDraftController::class, 'store']);
    Route::post('ad-drafts/publish', [AdDraftController::class, 'publish']);
    Route::put('ad-drafts/{draft}', [AdDraftController::class, 'update'])->whereNumber('draft');
    Route::get('ad-drafts/{draft}', [AdDraftController::class, 'show'])->whereNumber('draft');
