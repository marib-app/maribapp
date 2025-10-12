<?php
use App\Http\Controllers\AddressController;
use App\Http\Controllers\Api\DeliveryPriceCalculatorController;
use App\Http\Controllers\WifiCabinApiController;
use App\Http\Controllers\WifiPaymentGatewayController;
use App\Http\Controllers\ApiController;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\ServiceRequestController as ApiServiceRequestController;
use App\Http\Middleware\InitializeApiMetrics;
use App\Http\Controllers\CartController;
use App\Http\Controllers\CartShippingQuoteController;
use App\Http\Controllers\OrderApiController;
use App\Http\Controllers\PaymentController;
use App\Http\Controllers\Payments\PaymentWebhookController;
use App\Http\Controllers\WifiCodeBatchController;
use App\Http\Controllers\WifiNetworkController;
use App\Http\Controllers\WifiPlanController;
use App\Http\Controllers\WifiPurchaseController;
use App\Http\Controllers\ProductPurchaseOptionsController;
use App\Http\Controllers\ItemPurchaseManagementController;
use App\Http\Controllers\WifiCodeRevealController;



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


Route::get('ping', fn () => response()->json(['ok' => true]))
    ->middleware(InitializeApiMetrics::class)
    ->name('ping');
    
Route::get('products/{item}/purchase-options', [ProductPurchaseOptionsController::class, 'show'])
    ->whereNumber('item');

    
Route::prefix('wifi-cabin')
    ->middleware(['auth:sanctum', 'permission:wifi-cabin-manage'])
    ->group(function () {
        Route::get('networks', [WifiCabinApiController::class, 'networks']);
        Route::get('plans', [WifiCabinApiController::class, 'plans']);
        Route::get('networks/{network}/plans', [WifiCabinApiController::class, 'networkPlans']);
        Route::get('balances', [WifiCabinApiController::class, 'balances']);
        Route::get('alerts', [WifiCabinApiController::class, 'alerts']);
        Route::get('networks/{network}', [WifiCabinApiController::class, 'network']);
        Route::get('owner-requests', [WifiCabinApiController::class, 'ownerRequests']);
        Route::get('networks/{network}/stock', [WifiCabinApiController::class, 'networkStock']);
        Route::get('networks/{network}/alerts', [WifiCabinApiController::class, 'networkAlerts']);
    });



/* Authenticated Routes */
    Route::group(['middleware' => ['auth:sanctum']], static function () {


    Route::post('items/{item}/attributes', [ItemPurchaseManagementController::class, 'updateAttributes'])
        ->whereNumber('item');
    Route::post('admin/items/{item}/stock/bulk-set', [ItemPurchaseManagementController::class, 'bulkSetStock'])
        ->whereNumber('item');
    Route::patch('items/{item}/discount', [ItemPurchaseManagementController::class, 'updateDiscount'])
        ->whereNumber('item');


    Route::prefix('wifi')->group(function () {
        Route::get('networks', [WifiNetworkController::class, 'index']);
        Route::post('networks', [WifiNetworkController::class, 'store']);
        Route::put('networks/{network}', [WifiNetworkController::class, 'update'])->whereNumber('network');
        Route::get('networks/{network}/plans', [WifiPlanController::class, 'index'])->whereNumber('network');
        Route::post('networks/{network}/plans', [WifiPlanController::class, 'store'])->whereNumber('network');

        Route::put('plans/{plan}', [WifiPlanController::class, 'update'])->whereNumber('plan');

        Route::get('payment-gateways', [WifiPaymentGatewayController::class, 'index']);

        Route::post('plans/{plan}/batches', [WifiCodeBatchController::class, 'store'])->whereNumber('plan');
        Route::post('plans/{plan}/purchase', [WifiPlanController::class, 'purchase'])->whereNumber('plan');
        Route::post('plans/purchase/webhook', [WifiPlanController::class, 'webhook'])
            ->withoutMiddleware(['auth:sanctum']);
            
        Route::get('codes/mine', [WifiPurchaseController::class, 'index']);
        Route::get('purchases', [WifiPurchaseController::class, 'index']);
        Route::get('orders/{transaction}/code', [WifiPurchaseController::class, 'show'])
            ->whereNumber('transaction');

        Route::post('codes/{code}/events', [WifiCodeRevealController::class, 'store'])
            ->whereNumber('code');

    });



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

    Route::post('payments/initiate', [PaymentController::class, 'initiate'])
        ->middleware('throttle:payments-initiate');
        
        Route::post('payments/confirm', [PaymentController::class, 'confirm']);
    Route::post('payments/manual', [PaymentController::class, 'manual']);


    Route::get('verification-fields', [ApiController::class, 'getVerificationFields']);
    Route::post('send-verification-request',[ApiController::class,'sendVerificationRequest']);
    Route::get('verification-request',[ApiController::class,'getVerificationRequest']);

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
Route::get('get-featured-section', [ApiController::class, 'getFeaturedSection']);
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