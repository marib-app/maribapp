// ignore_for_file: file_names
import 'package:marib/data/model/category_model.dart';
import 'package:marib/data/model/system_settings_model.dart';
import 'package:marib/settings.dart';
import 'package:marib/ui/screens/filter_screen.dart';

import 'package:flutter/material.dart';

import 'package:marib/ui/screens/filter_screen.dart';
import 'package:marib/data/model/item_filter_model.dart';
import 'package:marib/data/model/social_link_model.dart';

const String svgPath = 'assets/svg/';

class Constant {
  static const String appName = AppSettings.applicationName;
  static const String androidPackageName = AppSettings.andoidPackageName;
  static String playstoreURLAndroid = "";
  static String appstoreURLios = "";
  static String iOSAppId = '';
  static const String shareappText = AppSettings.shareAppText;


  static const double defaultPadding = 16.0;

  //backend url
  static String baseUrl = AppSettings.baseUrl;

  static String isGoogleBannerAdsEnabled = "";
  static String isGoogleInterstitialAdsEnabled = "";
  static String isGoogleNativeAdsEnabled = "";

  ///
  static String bannerAdIdAndroid = '';
  static String bannerAdIdIOS = "";

  static String interstitialAdIdAndroid = '';
  static String interstitialAdIdIOS = '';

  static String nativeAdIdAndroid = '';
  static String nativeAdIdIOS = '';

  static String currencySymbol = "";
  static String defaultLatitude = "";
  static String defaultLongitude = "";
  static String mobileAuthentication = "";
  static String googleAuthentication = "";
  static String emailAuthentication = "";
  static String appleAuthentication = "";
  static String usageGuide = "";
  static List<SocialLink> socialLinks = const [];
  static Set<int> geoDisabledCategoryIds = <int>{};

  //
  static int otpTimeOutSecond = AppSettings.otpTimeOutSecond; //otp time out
  static int otpResendSecond = AppSettings.otpResendSecond; // resend otp timer
  //

  static String logintypeMobile = "1"; //always 1
  //
  static String maintenanceMode = "0"; //OFF
  static bool isUserDeactivated = false;

  //
  static int loadLimit = AppSettings.apiDataLoadLimit;

  static const String defaultCountryCode = AppSettings.defaultCountryCode;

  ///This maxCategoryLength is for show limited number of categories and show "More" button,
  ///You have to set less than [loadLimit] constant

  static const int maxCategoryLength =
      AppSettings.maxCategoryShowLengthInHomeScreen;

  //

  ///Lottie animation
  static const String loadingSuccessLottieFile =
      AppSettings.successLoadingLottieFile;
  static const String successItemLottieFile =
      AppSettings.successCheckLottieFile;
  static const String progressLottieFileWhite = AppSettings
      .progressLottieFileWhite; //When there is dark background and you want to show progress so it will be used

  static const String maintenanceModeLottieFile =
      AppSettings.maintenanceModeLottieFile;

  ///

  ///Put your loading json file in assets/lottie/ folder
  static const bool useLottieProgress = AppSettings
      .useLottieProgress; //if you don't want to use lottie progress then set it to false'

  static const String notificationChannel = AppSettings.notificationChannel;
  static int uploadImageQuality = AppSettings.uploadImageQuality; //0 to 100
  //static const int maxSizeInBytes = 4096 * 1024; //0 to 100
  static const int maxSizeInBytes = 3 * 1024; //0 to 100

  static String? subscriptionPackageId;
  static ItemFilterModel? itemFilter;
  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static String typeRent = "rent";
  static String generalNotification = "0";
  static String enquiryNotification = "1";
  static String notificationItemEnquiry = "item_inquiry";
  static String notificationDefault = "default";

  static const int realEstateRootCategoryId = 1;
  static const int sheinRootCategoryId = 4;
  static const int computerRootCategoryId = 5;
  static const int publicRootCategoryId = 6;
  static const int storeRootCategoryId = 6;



  static List<PostedSinceItem> postedSince = [
    PostedSinceItem(status: "All Time", value: "all-time"),
    PostedSinceItem(status: "Today", value: "today"),
    PostedSinceItem(status: "Within 1 week", value: "within-1-week"),
    PostedSinceItem(status: "Within 2 week", value: "within-2-week"),
    PostedSinceItem(status: "Within 1 month", value: "within-1-month"),
    PostedSinceItem(status: "Within 3 month", value: "within-3-month"),
  ];

//

  static List<CategoryModel> selectedCategory = [];

  //
  static double borderWidth = 1.5;
  static int nativeAdsAfterItemNumber = 6; //Only add even numbers

  static List<int> interestedItemIds = [];
  static List<int> favoriteItemList = [];

  static Map<SystemSetting, String> systemSettingKeys = {
    SystemSetting.currencySymbol: "currency_symbol",
    SystemSetting.privacyPolicy: "privacy_policy",
    SystemSetting.contactUs: "",
    SystemSetting.maintenanceMode: "maintenance_mode",
    SystemSetting.termsConditions: "terms_conditions",
    SystemSetting.subscription: "subscription",
    SystemSetting.language: "languages",
    SystemSetting.defaultLanguage: "default_language",
    SystemSetting.forceUpdate: "force_update",
    SystemSetting.androidVersion: "android_version",
    SystemSetting.numberWithSuffix: "number_with_suffix",
    SystemSetting.iosVersion: "ios_version",
    SystemSetting.bannerAdStatus: "banner_ad_status",
    SystemSetting.bannerAdAndroidAd: "banner_ad_id_android",
    SystemSetting.bannerAdiOSAd: "banner_ad_id_ios",
    SystemSetting.interstitialAdStatus: "interstitial_ad_status",
    SystemSetting.interstitialAdAndroidAd: "interstitial_ad_id_android",
    SystemSetting.interstitialAdiOSAd: "interstitial_ad_id_ios",
    SystemSetting.nativeAdStatus: "native_ad_status",
    SystemSetting.nativeAndroidAd: "native_app_id_android",
    SystemSetting.nativeAdiOSAd: "native_app_id_android",
    SystemSetting.playStoreLink: "play_store_link",
    SystemSetting.appStoreLink: "app_store_link",
    SystemSetting.defaultLatitude: "default_latitude",
    SystemSetting.defaultLongitude: "default_longitude",
    SystemSetting.mobileAuthentication: "mobile_authentication",
    SystemSetting.googleAuthentication: "google_authentication",
    SystemSetting.appleAuthentication: "apple_authentication",
    SystemSetting.emailAuthentication: "email_authentication",
    SystemSetting.usageGuide: "usage_guide",
    SystemSetting.socialLinks: "social_links",
    SystemSetting.geoDisabledCategories: "geo_disabled_categories",

  };

  ///This is limit of minimum chat messages load count , make sure you set it grater than 25;
  static int minChatMessages = 35;

  static bool showExperimentals = true;

  //Don't touch this settings
  static bool isUpdateAvailable = false;
  static String newVersionNumber = "";
  static bool isNumberWithSuffix = false;

  //Demo mode settings
  static bool isDemoModeOn = false;
  static String demoCountryCode = "967";
  static String demoMobileNumber = "967775990370";
  static String demoModeOTP = "123456";
}
