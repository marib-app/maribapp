import 'package:marib/ui/screens/auth/sign_up/mobile_signup_screen.dart';
import 'package:marib/ui/screens/auth/sign_up/mobile_verification_screen.dart';
import 'package:marib/ui/screens/cart/adress.dart';
import 'package:marib/ui/screens/cart/delivery_and_payment.dart';
import 'package:marib/ui/screens/cart/order_step.dart';
import 'dart:ui';

import 'package:marib/ui/screens/competitions/competitions_screen.dart';

import 'package:marib/ui/screens/home/widgets/categoryFilterScreen.dart';
import 'package:marib/ui/screens/home/widgets/postedSinceFilter.dart';
import 'package:marib/ui/screens/home/widgets/subCategoryFilterScreen.dart';
import 'package:marib/ui/screens/info_screen/info_screen.dart';

import 'package:marib/ui/screens/item/purchase_options/product_management_screen.dart';

import 'package:marib/ui/screens/item/items_list_seller.dart';
import 'package:marib/ui/screens/item/viewAll.dart';
import 'package:marib/ui/screens/soon_screen.dart';
import 'package:marib/ui/screens/sub_category/sub_category_screen.dart';
import 'package:marib/ui/screens/auth/login/forgot_password.dart';
import 'package:marib/ui/screens/auth/sign_up/signup_main_screen.dart';
import 'package:marib/ui/screens/auth/sign_up/signup_screen.dart';
import 'package:marib/ui/screens/chat/blocked_user_list_screen.dart';
import 'package:marib/ui/screens/favorite_screen.dart';
import 'package:marib/ui/screens/item/items_list.dart';
import 'package:marib/ui/screens/location/cities_screen.dart';
import 'package:marib/ui/screens/location/countries_screen.dart';
import 'package:marib/ui/screens/location/states_screen.dart';
import 'package:marib/ui/screens/seller/seller_verification_complete.dart';
import 'package:marib/ui/screens/other/faqs_screen.dart';
import 'package:marib/ui/screens/location_permission_screen.dart';
import 'package:marib/ui/screens/my_review_screen.dart';
import 'package:marib/ui/screens/sold_out_bought_screen.dart';
import 'package:marib/ui/screens/support_screen.dart';
import 'package:marib/ui/screens/user_profile/edit_profile.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:marib/ui/screens/advertisement/my_advertisment_screen.dart';
import 'package:marib/ui/screens/auth/login/login_screen.dart';
import 'package:marib/ui/screens/home/category_list.dart';
import 'package:marib/ui/screens/home/change_language_screen.dart';
import 'package:marib/ui/screens/home/search_screen.dart';

import 'package:marib/ui/screens/item/my_items_screen.dart';
import 'package:marib/ui/screens/location/areas_screen.dart';
import 'package:marib/ui/screens/location/nearby_location.dart';
import 'package:marib/ui/screens/onboarding/onboarding_screen.dart';
import 'package:marib/ui/screens/seller/seller_intro_verification.dart';
import 'package:marib/ui/screens/seller/seller_profile.dart';
import 'package:marib/ui/screens/seller/seller_verification.dart';
import 'package:marib/ui/screens/subscription/packages_list.dart';
import 'package:marib/ui/screens/subscription/transaction_history_screen.dart';
import 'package:marib/ui/screens/filter_screen.dart';
import 'package:marib/ui/screens/widgets/maintenance_mode.dart';
import 'package:marib/data/repositories/item/item_repository.dart';
import 'package:marib/data/model/data_output.dart';
import 'package:marib/data/model/item/item_model.dart';
import 'package:marib/ui/screens/cart/cart.dart';

import 'package:marib/app/navigation/app_page_route.dart';

import 'package:marib/ui/screens/settings/contact_us.dart';
import 'package:marib/ui/screens/settings/notification_detail.dart';
import 'package:marib/ui/screens/settings/notifications.dart';
import 'package:marib/ui/screens/settings/profile_setting.dart';

import 'package:marib/ui/screens/classified_ads/details.dart';
import 'package:marib/ui/screens/classified_ads/classified_screen.dart';
import 'package:marib/ui/screens/classified_ads/classified_screen2.dart';
import 'package:marib/ui/screens/classified_ads/classified_screen3.dart';
import 'package:marib/ui/screens/classified_ads/units/service_payment_page.dart';
import 'package:marib/ui/screens/home_screen/section/section_screen/section_screen.dart';

import 'package:marib/ui/screens/item/purchase_options/product_purchase_options_screen.dart';
import 'package:marib/ui/screens/item/promo/promote_ad_screen.dart';
import 'package:marib/ui/screens/settings/main_activity.dart';
import 'package:marib/ui/screens/settings/splash_screen.dart';
import 'package:marib/ui/screens/item/add_item_screen/widgets/success_item_screen.dart';

import 'package:marib/ui/screens/item/add_item_screen/select_category.dart';

//
import 'package:marib/ui/screens/item/add_item_screen/add_item_details.dart';
import 'package:marib/ui/screens/item/add_item_screen/add_item_details.dart';
import 'package:marib/ui/screens/item/ad_details_screen/ad_details_screen.dart';
import 'package:marib/ui/screens/user_profile/show_profile.dart';
import 'package:marib/ui/screens/item/location/confirm_location_screen.dart';
import 'package:marib/ui/screens/item/add_item_screen/more_details.dart';
import 'package:marib/ui/screens/item/add_item_screen/widgets/pdf_viewer.dart';
import 'package:marib/ui/screens/currency/currency_screen.dart';
import 'package:marib/ui/screens/classified_ads/add.dart';
import 'package:marib/ui/screens/classified_ads/main_service_details.dart';
import 'package:marib/ui/screens/home_screen/section/TemporarySectionScreen.dart';

import 'package:marib/ui/screens/widgets/errors/error_screen.dart';

import 'package:marib/ui/screens/classified_ads/other_services/wifi_cabin/wifi_cabin_screen.dart';
import 'package:marib/ui/screens/classified_ads/other_services/other_services_screen.dart';
import 'package:marib/ui/screens/classified_ads/service_add_more_details_screen.dart';
import 'package:marib/ui/screens/home_screen/section/section_screen/widgets/map_search/map_search_screen.dart'; // عدّل المسار حسب موقع الملف الفعلي
import 'package:marib/ui/screens/wallet/wallet_screen.dart';
import 'package:marib/ui/screens/cart/orders_list_screen.dart';

class Routes {
  //private constructor
  //Routes._();

  static const section_screen = 'section_screen'; // واجهة الاقسام
  static const promoteAdScreen = '/promoteAdScreen';
  static const productManagementScreen = '/productManagementScreen';

  // الخدمات
  static const classifiedScreenRoute = 'classifiedScreenRoute';
  static const classifiedScreenRoute2 = 'classifiedScreen2Route';
  static const classifiedScreenRoute3 = 'classifiedScreen3Route';
  static const servicePaymentPage = '/service-payment';
  static const myReviewsScreen = '/myReviewsScreenRoute';
  static const serviceAddMoreDetails = '/service-add-more-details';

  // خدمات اخرى
  static const otherServices = '/other-services';
  static const otherServicesWifiCabin = '/other-services/wifi-cabin';

  static const temporarySection = '/temporarySection';
  static const String challengeInstructions = '/challenge-instructions';

  static const mapSearch = '/mapSearch'; // البحث بالخريطة

  static const splash = 'splash';
  static const onboarding = 'onboarding';
  static const login = 'login';
  static const forgotPassword = 'forgotPassword';
  static const signup = 'signup';
  static const signupMainScreen = 'signUpMainScreen';
  static const mobileSignUp = 'mobileSignUp';
  static const completeProfile = 'complete_profile';
  static const showProfile = 'show_profile';
  static const main = 'main';
  static const home = 'Home';
  static const addItem = 'addItem';
  static const waitingScreen = 'waitingScreen';
  static const categories = 'Categories';
  static const CategoryPublic = 'CategoryPublic';

  static const addresses = 'address';
  static const chooseAdrs = 'chooseAddress';
  static const itemsList = 'itemsList';
  static const itemsListShein = 'itemsListShein';
  static const itemsListSeller = 'ItemsListSeller';

  static const itemsListComputers = 'itemsListComputers';
  static const itemsListTravel = 'ItemsListTravel';

  static const soon = 'soon';

  static const competition = 'competition';

  static const cart = 'cart';
  static const deliveryandpayment = 'deliveryandpayment';

  static const orderSteps = 'orderSteps';
  static const ordersList = 'ordersList';

  static const adress = 'adress';

  static const otp = 'otp';

  static const currency = 'currency';

  static const info = 'info';
  static const support = 'support';

  static const contactUs = 'ContactUs';
  static const profileSettings = 'profileSettings';
  static const filterScreen = 'filterScreen';
  static const notificationPage = 'notificationpage';
  static const notificationDetailPage = 'notificationdetailpage';
  static const addItemScreenRoute = 'addItemScreenRoute';
  static const subscriptionPackageListRoute = 'subscriptionPackageListRoute';
  static const subscriptionScreen = 'subscriptionScreen';
  static const maintenanceMode = '/maintenanceMode';
  static const favoritesScreen = '/favoritescreen';
  static const promotedItemsScreen = '/promotedItemsScreen';
  static const mostLikedItemsScreen = '/mostLikedItemsScreen';
  static const mostViewedItemsScreen = '/mostViewedItemsScreen';
  static const classifiedDetailsScreenRoute = 'classifiedDetailsScreenRoute';
  static const mainServiceDetailsRoute = 'mainServiceDetailsRoute';

  static const addclassifiedScreenRoute = '/addclassifiedScreenRoute';

  static const languageListScreenRoute = '/languageListScreenRoute';
  static const searchScreenRoute = '/searchScreenRoute';
  static const itemMapScreen = '/ItemMap';
  static const dashboard = '/dashboard';
  static const subCategoryScreen = '/subCategoryScreen';
  static const categoryFilterScreen = '/categoryFilterScreen';
  static const subCategoryFilterScreen = '/subCategoryFilterScreen';
  static const postedSinceFilterScreen = '/postedSinceFilterScreen';
  static const locationPermissionScreen = '/locationPermissionScreen';
  static const sellerProfileScreen = '/sellerProfileScreen';
  static const nearbyLocationScreen = '/nearbyLocationScreen';

  static const myAdvertisment = '/myAdvertisment';
  static const transactionHistory = '/transactionHistory';
  static const wallet = '/wallet';

  static const personalizedItemScreen = '/personalizedItemScreen';
  static const myItemScreen = '/myItemScreen';
  static const pdfViewerScreen = '/pdfViewerScreen';
  static const countriesScreen = '/countriesScreen';
  static const statesScreen = '/statesScreen';
  static const citiesScreen = '/citiesScreen';
  static const areasScreen = '/areasScreen';
  static const faqsScreen = '/faqsScreen';
  static const soldOutBoughtScreen = '/soldOutBoughtScreen';
  static const sellerIntroVerificationScreen = '/sellerIntroVerificationScreen';
  static const sellerVerificationScreen = '/sellerVerificationScreen';
  static const sellerVerificationComplteScreen =
      '/sellerVerificationComplteScreen';

  ///Add Item screens
  static const selectItemTypeScreen = '/selectItemType';
  static const addItemDetailsScreen = '/addItemDetailsScreen';
  static const setItemParametersScreen = '/setItemParametersScreen';
  static const selectOutdoorFacility = '/selectOutdoorFacility';
  static const adDetailsScreen = '/adDetailsScreen';
  static const successItemScreen = '/successItemScreen';
  static const productPurchaseOptionsScreen = '/productPurchaseOptionsScreen';

  ///Add item screens
  static const selectCategoryScreen = '/selectCategoryScreen';
  static const selectNestedCategoryScreen = '/selectNestedCategoryScreen';
  static const addItemDetails = '/addItemDetails';
  static const addMoreDetailsScreen = '/addMoreDetailsScreen';
  static const confirmLocationScreen = '/confirmLocationScreen';
  static const sectionWiseItemsScreen = '/sectionWiseItemsScreen';
  static const blockedUserListScreen = '/blockedUserListScreen';
  static const payStackWebViewScreen = '/payStackWebViewScreen';

  // static const myItemsScreen = '/myItemsScreen';

  //Sandbox[test]
  static const playground = 'playground';

  static String currentRoute = splash;

  //static String previousCustomerRoute = splash;

  static Route onGenerateRouted(RouteSettings routeSettings) {
    currentRoute = routeSettings.name ?? "";

    // ⛔️ حارس: امنع الذهاب لتعديل/إكمال البروفايل إلا لو تم التصريح عبر arguments
    if (routeSettings.name ==
        Routes
            .completeProfile /* || routeSettings.name == Routes.editProfile */) {
      final args = routeSettings.arguments;
      final bool allow = args is Map &&
          (args['allowProfileRoute'] == true || args['force'] == true);
      if (!allow) {
        // تحويل للرئيسية إذا كانت محاولة تلقائية/غير مصرّح بها
        return MainActivity.route(routeSettings);
      }
    }

    // --- أمثلتك الخاصة قبل الـ switch (temporarySection وغيره) تبقى كما هي ---
    if (routeSettings.name == Routes.temporarySection) {
      final arguments = routeSettings.arguments as Map<String, dynamic>?;
      if (arguments == null) {
        return AppPageRoute.build(
          settings: routeSettings,
          builder: (context) => ErrorScreen(),
        );
      }

      return AppPageRoute.build(
        settings: routeSettings,
        builder: (context) => TemporarySectionScreen(
          catName: arguments['catName'] ?? 'Default CatName',
          catID: arguments['catID'] ?? 'Default CatID',
        ),
      );
    }

    if (routeSettings.name!.contains('/product-details/')) {
      String itemSlug = routeSettings.name!.split('/').last;
      return AppPageRoute.build(
        settings: routeSettings,
        builder: (context) {
          return FutureBuilder<DataOutput<ItemModel>>(
            future: ItemRepository().fetchItemFromItemSlug(itemSlug),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                    body: Center(child: CircularProgressIndicator()));
              } else if (snapshot.hasError) {
                return Scaffold(
                    body: Center(child: Text('Error: ${snapshot.error}')));
              } else {
                return AdDetailsScreen(model: snapshot.data!.modelList.first);
              }
            },
          );
        },
      );
    }

    switch (routeSettings.name) {
      // الخدمات

      case classifiedScreenRoute:
        return ClassifiedScreen.route(routeSettings);

      case classifiedScreenRoute2:
        return ClassifiedScreen2.route(routeSettings);

      case classifiedScreenRoute3:
        return ClassifiedScreen3.route(routeSettings);

      case Routes.serviceAddMoreDetails:
        return ServiceAddMoreDetailsScreen.route(routeSettings);

      case productManagementScreen:
        return ProductManagementScreen.route(routeSettings);

// ✅ جديد: خدمات أخرى
      case otherServices:
        return OtherServicesScreen.route(routeSettings);

      case otherServicesWifiCabin:
        return WifiCabinScreen.route(routeSettings);

      case mapSearch:
        return AppPageRoute.build(
          settings: routeSettings,
          builder: (_) => const MapSearchScreen(),
        );

      // الدفع
      case Routes.servicePaymentPage:
        return ServicePaymentPage.route(routeSettings);

      case Routes.section_screen: // 👈 مسارك الجديد
        return Section_screen.route(routeSettings);

      case promoteAdScreen:
        return PromoteAdScreen.route(routeSettings);

      //  الأقسام الموقوفة
      case Routes.temporarySection:
        final arguments = routeSettings.arguments as Map<String, String>;

        return AppPageRoute.build(
          settings: routeSettings,
          builder: (context) => TemporarySectionScreen(
            catName: arguments['catName'] ?? '',
            catID: arguments['catID'] ?? '',
          ),
        );

      case splash:
        return AppPageRoute.build(
          settings: routeSettings,
          builder: (context) => const SplashScreen(),
        );
      case onboarding:
        return AppPageRoute.build(
          settings: routeSettings,
          builder: (context) => const OnboardingScreen(),
        );

      case main:
        return MainActivity.route(routeSettings);
      case login:
        return LoginScreen.route(routeSettings);
      case forgotPassword:
        return ForgotPasswordScreen.route(routeSettings);
      case signup:
        return SignupScreen.route(routeSettings);
      case signupMainScreen:
        return SignUpMainScreen.route(routeSettings);
      case mobileSignUp:
        return MobileSignUpScreen.route(routeSettings);

      // ✅ بدّل هذه: كانت تفتح UserProfileScreen، خلّها ترجع الرئيسية
      case completeProfile:
        // الآن سيصل هنا فقط لو allowProfileRoute == true
        return UserProfileScreen.route(routeSettings);

      case showProfile:
        return ShowUserProfileScreen.route(routeSettings);

      case categories:
        return CategoryList.route(routeSettings);

      case CategoryPublic:
      //    return CategoryListPublic.route(routeSettings);

      case subCategoryScreen:
        return SubCategoryScreen.route(routeSettings);
      case categoryFilterScreen:
        return CategoryFilterScreen.route(routeSettings);
      case subCategoryFilterScreen:
        return SubCategoryFilterScreen.route(routeSettings);
      case postedSinceFilterScreen:
        return PostedSinceFilterScreen.route(routeSettings);
      case maintenanceMode:
        return MaintenanceMode.route(routeSettings);
      case languageListScreenRoute:
        return LanguagesListScreen.route(routeSettings);
      case contactUs:
        return ContactUs.route(routeSettings);
      case locationPermissionScreen:
        return LocationPermissionScreen.route(routeSettings);
      case profileSettings:
        return ProfileSettings.route(routeSettings);
      case filterScreen:
        return FilterScreen.route(routeSettings);
      case notificationPage:
        return Notifications.route(routeSettings);
      case notificationDetailPage:
        return NotificationDetail.route(routeSettings);

      case successItemScreen:
        return SuccessItemScreen.route(routeSettings);

      case productPurchaseOptionsScreen:
        return ProductPurchaseOptionsScreen.route(routeSettings);

      case classifiedDetailsScreenRoute:
        return ClassifiedDetails.route(routeSettings);

      case mainServiceDetailsRoute:
        return MainServiceDetails.route(routeSettings);

      case addclassifiedScreenRoute:
        return AddClassified.route(routeSettings);
      case subscriptionPackageListRoute:
        return SubscriptionPackageListScreen.route(routeSettings);

      case favoritesScreen:
        return FavoriteScreen.route(routeSettings);

      case transactionHistory:
        return TransactionHistory.route(routeSettings);

      case wallet:
        return WalletScreen.route(routeSettings);

      case blockedUserListScreen:
        return BlockedUserListScreen.route(routeSettings);
      case countriesScreen:
        return CountriesScreen.route(routeSettings);

      case statesScreen:
        return StatesScreen.route(routeSettings);
      case citiesScreen:
        return CitiesScreen.route(routeSettings);
      case areasScreen:
        return AreasScreen.route(routeSettings);

      case myAdvertisment:
        return MyAdvertisementScreen.route(routeSettings);
      case myItemScreen:
        return ItemsScreen.route(routeSettings);
      case searchScreenRoute:
        return SearchScreen.route(routeSettings);

      case itemsList:
        return ItemsList.route(routeSettings);

      case itemsListSeller:
        return ItemsListSeller.route(routeSettings);

      case faqsScreen:
        return FaqsScreen.route(routeSettings);

      //Add item screen
      case selectCategoryScreen:
        return SelectCategoryScreen.route(routeSettings);
      case selectNestedCategoryScreen:
        return SelectNestedCategory.route(routeSettings);
      case addItemDetails:
        return AddItemDetails.route(routeSettings);

      case addMoreDetailsScreen:
        return AddMoreDetailsScreen.route(routeSettings);

      case confirmLocationScreen:
        return ConfirmLocationScreen.route(routeSettings);
      case sectionWiseItemsScreen:
        return SectionItemsScreen.route(routeSettings);

      case adDetailsScreen:
        return AdDetailsScreen.route(routeSettings);

      case pdfViewerScreen:
        return PdfViewer.route(routeSettings);
      case soldOutBoughtScreen:
        return SoldOutBoughtScreen.route(routeSettings);
      case sellerProfileScreen:
        return SellerProfileScreen.route(routeSettings);
      case sellerIntroVerificationScreen:
        return SellerIntroVerificationScreen.route(routeSettings);
      case sellerVerificationScreen:
        return SellerVerificationScreen.route(routeSettings);
      case sellerVerificationComplteScreen:
        return SellerVerificationCompleteScreen.route(routeSettings);
      case nearbyLocationScreen:
        return NearbyLocationScreen.route(routeSettings);
      case myReviewsScreen:
        return MyReviewScreen.route(routeSettings);

      case soon:
        return SoonScreen.route(routeSettings);

      case competition:
        return CompetitionScreen.route(routeSettings);

      case cart:
        return CartScreen.route(routeSettings);

      case deliveryandpayment:
        return DeliveryandpaymentScreen.route(routeSettings);

      case adress:
        return AdressScreen.route(routeSettings);

      case orderSteps:
        return OrderStepsScreen.route(routeSettings);

      case ordersList:
        return OrdersListScreen.route(routeSettings);

      case otp:
        return MobileVerificationScreen.route(routeSettings);

      case info:
        return AppPageRoute.build(
          settings: routeSettings,
          builder: (context) => const InfoScreen(),
        );
      case currency:
        return AppPageRoute.build(
          settings: routeSettings,
          builder: (context) => const CurrencyScreen(),
        );

      case support:
        return AppPageRoute.build(
          settings: routeSettings,
          builder: (context) => const SupportScreen(),
        );

      /*case payStackWebViewScreen:
        return PaystackWebView.route(routeSettings);*/

      /*  case myItemsScreen:
        return ItemsScreen.route(routeSettings);*/

      default:
        return AppPageRoute.build(
          settings: routeSettings,
          builder: (context) => const Scaffold(),
        );
      /*
        if (routeSettings.name!.contains(AppSettings.shareNavigationWebUrl)) {

          return NativeLinkWidget.render(routeSettings);
        }

        return BlurredRouter(
          builder: ((context) => Scaffold(
                body: Text(
                  "pageNotFoundErrorMsg".translate(context),
                ),
              )),
        );*/
    }
  }
}
