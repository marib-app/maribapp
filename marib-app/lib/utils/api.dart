import 'dart:io';

import 'package:dio/dio.dart';
import 'package:marib/data/cubits/system/user_details.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/utils/network_request_interseptor.dart';
import 'package:marib/data/cubits/chat/get_buyer_chat_users_cubit.dart';

import 'package:marib/data/cubits/report/update_report_items_list_cubit.dart';
import 'package:marib/data/cubits/chat/blocked_users_list_cubit.dart';
import 'package:marib/data/cubits/favorite/favorite_cubit.dart';

import 'package:marib/utils/errorFilter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// ✅ إضافة موديل الحساب البنكي
import 'package:marib/utils/payment/bank_account.dart';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'dart:collection';
import 'dart:convert';



class ApiException implements Exception {
  ApiException(this.errorMessage);

  dynamic errorMessage;

  @override
  String toString() {
    return ErrorFilter.check(errorMessage).error;
  }
}

class ApiHttpException extends ApiException {
  ApiHttpException({
    required dynamic errorMessage,
    this.statusCode,
    this.payload,
    this.cause,
  }) : super(errorMessage);

  final int? statusCode;
  final dynamic payload;
  final DioException? cause;
}

class _CachedApiResponse {
  const _CachedApiResponse({
    required this.payload,
    this.eTag,
  });

  final Map<String, dynamic> payload;
  final String? eTag;
}

class _ApiResponseCache {
  static final Map<String, _CachedApiResponse> _cache = {};

  static String _buildKey(
      String url,
      Map<String, dynamic>? queryParameters,
      ) {
    if (queryParameters == null || queryParameters.isEmpty) {
      return url;
    }

    final normalizedParameters = SplayTreeMap<String, dynamic>.from(
      queryParameters,
    );

    final serializedParameters = jsonEncode(normalizedParameters);
    return '$url?$serializedParameters';
  }

  static _CachedApiResponse? get(
      String url,
      Map<String, dynamic>? queryParameters,
      ) {
    final key = _buildKey(url, queryParameters);
    return _cache[key];
  }

  static void store(
      String url,
      Map<String, dynamic>? queryParameters,
      Map<String, dynamic> payload,
      String? eTag,
      ) {
    final key = _buildKey(url, queryParameters);
    _cache[key] = _CachedApiResponse(
      payload: Map<String, dynamic>.from(payload),
      eTag: eTag,
    );
  }
}






class Api {



  // تهيئة الهيدرز لكل الطلبات
  // - لو المستخدم غير مسجل: نضيف اللغة فقط إن وجدت
  // - لو مسجل: نضيف Bearer <JWT> + اللغة


  static Map<String, dynamic> headers() {

    final Map<String, dynamic> headers = {
      "Accept": "application/json",
    };

    final language = HiveUtils.getLanguage();
    final languageCode = language is Map ? language['code'] : null;
    if (languageCode is String && languageCode.isNotEmpty) {
      headers["Content-Language"] = languageCode;
    }


    if (!HiveUtils.isUserAuthenticated()) {
      _ensureSliderSessionHeaders(headers);

      return headers;
    }

    String? jwtToken = HiveUtils.getJWT();

    // تنظيف أي شوائب محتملة داخل التوكن (حماية من قيم مخلوطة)
    if (jwtToken != null && jwtToken.isNotEmpty) {
      if (jwtToken.contains('DEMO_MODE') ||
          jwtToken.contains('=false') ||
          jwtToken.contains('=true')) {
        jwtToken = jwtToken.split('DEMO_MODE')[0];
        jwtToken = jwtToken.split('=')[0];
        jwtToken = jwtToken.trim();

        // تحقق سريع من تركيب JWT
        List<String> parts = jwtToken.split('.');
        if (parts.length == 3) {
          bool isValidJWT = true;
          for (String part in parts) {
            if (part.isEmpty || part.contains(' ') || part.contains('\n')) {
              isValidJWT = false;
              break;
            }
          }
          if (!isValidJWT) {
            jwtToken = null;
          }
        } else {
          jwtToken = null;
        }
      }
    }
    if (kDebugMode && jwtToken != null && jwtToken.isNotEmpty) {
      final String visibleSuffix =
      jwtToken.length > 4 ? jwtToken.substring(jwtToken.length - 4) : jwtToken;
      print("JWT token ****$visibleSuffix");
    }

    if (jwtToken != null && jwtToken.isNotEmpty) {
      headers["Authorization"] = "Bearer $jwtToken";
    }
    _ensureSliderSessionHeaders(headers);
    return headers;
  }


  static Map<String, dynamic>? _cloneMap(Map<String, dynamic>? source) {
    if (source == null) {
      return null;
    }

    if (source.isEmpty) {
      return <String, dynamic>{};
    }

    return Map<String, dynamic>.from(source);
  }
  static const Object _contentTypeNotSpecified = Object();

  @visibleForTesting
  static Dio Function()? dioFactory;


  static String? _resolveContentType({
    Object? override = _contentTypeNotSpecified,
    Object? base,
  }) {
    final bool hasOverride = !identical(override, _contentTypeNotSpecified);
    final Object? candidate = hasOverride ? override : base;

    if (candidate == null) {
      return null;
    }

    if (candidate is String) {
      return candidate;
    }

    // Dio accepts String values for content type; ensure we don't surface
    // unexpected object instances.
    return candidate.toString();
  }


  static Options _buildRequestOptions({
    Options? base,
    String? method,
    Map<String, dynamic>? headers,
    Object? contentType = _contentTypeNotSpecified,
    bool? followRedirects,
  }) {
    final Options resolvedBase = base ?? Options(contentType: null);

    return Options(
      method: method ?? resolvedBase.method,
      sendTimeout: resolvedBase.sendTimeout,
      receiveTimeout: resolvedBase.receiveTimeout,
      extra: _cloneMap(resolvedBase.extra),
      headers: headers ?? _cloneMap(resolvedBase.headers),
      responseType: resolvedBase.responseType,
      contentType: _resolveContentType(
        override: contentType,
        base: resolvedBase.contentType,
      ),
      validateStatus: resolvedBase.validateStatus,
      receiveDataWhenStatusError:
      resolvedBase.receiveDataWhenStatusError,
      followRedirects: followRedirects ?? resolvedBase.followRedirects,
      maxRedirects: resolvedBase.maxRedirects,
      requestEncoder: resolvedBase.requestEncoder,
      responseDecoder: resolvedBase.responseDecoder,
      listFormat: resolvedBase.listFormat,
    );
  }


  static void _ensureSliderSessionHeaders(Map<String, dynamic> headers) {
    final String? sliderSessionId = HiveUtils.getSliderSessionId();
    if (sliderSessionId == null || sliderSessionId.isEmpty) {
      return;
    }

    headers['X-Session-Id'] = sliderSessionId;

    final String sliderCookie = 'slider_session=$sliderSessionId';
    final dynamic existingCookieRaw =
        headers['Cookie'] ?? headers['cookie'];
    String? resolvedCookie;

    if (existingCookieRaw is String && existingCookieRaw.isNotEmpty) {
      final List<String> cookies = existingCookieRaw
          .split(';')
          .map((cookie) => cookie.trim())
          .where((cookie) => cookie.isNotEmpty)
          .toList();

      bool replaced = false;
      for (int i = 0; i < cookies.length; i++) {
        if (cookies[i].startsWith('slider_session=')) {
          cookies[i] = sliderCookie;
          replaced = true;
          break;
        }
      }

      if (!replaced) {
        cookies.add(sliderCookie);
      }

      resolvedCookie = cookies.join('; ');
      if (resolvedCookie.trim().isEmpty) {
        resolvedCookie = sliderCookie;
      }
    }

    headers['Cookie'] = resolvedCookie ?? sliderCookie;
    if (headers.containsKey('cookie')) {
      headers['cookie'] = headers['Cookie'];
    }
  }

  static bool _isSliderEndpoint(String url) {
    if (url.isEmpty) {
      return false;
    }
    final String sanitized = url.split('?').first;
    final String sliderPath = getSliderApi;
    if (sanitized == sliderPath) {
      return true;
    }
    if (sanitized.endsWith('/$sliderPath')) {
      return true;
    }
    if (sanitized.contains('/$sliderPath/')) {
      return true;
    }
    return false;
  }

  // Place API
  static const String _placeApiBaseUrl =
      "https://maps.googleapis.com/maps/api/place/";
  static String placeApiKey = "key";
  static const String input = "input";
  static const String types = "types";
  static const String placeid = "placeid";
  static String placeAPI = "${_placeApiBaseUrl}autocomplete/json";
  static String placeApiDetails = "${_placeApiBaseUrl}details/json";

  // Stripe
  static String stripeIntentAPI = "https://api.stripe.com/v1/payment_intents";

  // =======================
  // مسارات الـ API (ثوابت)
  // =======================

  // Auth / Profile
  static String loginApi = "user-signup";
  static String userLoginApi = "user-login";
  static String updateProfileApi = "update-profile";

  // Content / Listings
  static String getSliderApi = "get-slider";
  static String getCategoriesApi = "get-categories";
  static String getItemApi = "get-item";
  static String productPurchaseOptionsApi(int itemId) => "products/$itemId/purchase-options";
  static String itemAttributesApi(int itemId) => "items/$itemId/attributes";
  static String itemStockBulkSetApi(int itemId) => "admin/items/$itemId/stock/bulk-set";
  static String itemDiscountApi(int itemId) => "items/$itemId/discount";
  static String getMyItemApi = "my-items";
  static String getNotificationListApi = "get-notification-list";
  static String deleteUserApi = "delete-user";
  static String manageFavouriteApi = "manage-favourite";
  static String getPackageApi = "get-package";
  static String getLanguageApi = "get-languages";
  static String getPaymentSettingsApi = "get-payment-settings";
  static String getSystemSettingsApi = "get-system-settings";
  static String getFavoriteItemApi = "get-favourite-item";
  static String delegateSectionsApi = "delegates/sections";
  static String updateItemStatusApi = "update-item-status";
  static String getReportReasonsApi = "get-report-reasons";
  static String addReportsApi = "add-reports";
  static String getCustomFieldsApi = "get-customfields";
  static String getFeaturedSectionApi = "get-featured-section";
  static String updateItemApi = "update-item";
  static String addItemApi = "add-item";
  static String deleteItemApi = "delete-item";
  static String setItemTotalClickApi = "set-item-total-click";
  static String makeItemFeaturedApi = "make-item-featured";
  static String assignFreePackageApi = "assign-free-package";
  static String getLimitsOfPackageApi = "get-limits";
  static String getPaymentIntentApi = "payment-intent";
  static String inAppPurchaseApi = "in-app-purchase";
  static String getTipsApi = "tips";
  static String premiumSubscriptionStatusApi = getLimitsOfPackageApi;
  static String adsFeaturedCountApi = "ads/featured/count";
  static String unfeatureAdApi(int id) => "ads/$id/unfeature";
  static String walletSummaryApi = "wallet";
  static String walletTransactionsApi = "wallet/transactions";
  static String walletWithdrawalsApi = "wallet/withdrawals";
  static String walletWithdrawalOptionsApi = "wallet/withdrawals/options";
  static String walletTransfersApi = "wallet/transfers";
  static String manualPaymentRequestsApi = "manual-payment-requests";
  static String paymentsInitiateApi = "payments/initiate";
  static String submitManualPaymentApi = "payments/manual";
  static String paymentsConfirmApi = "payments/confirm";
  static String createOrderApi = "orders";

  static String getCountriesApi = "countries";
  static String getStatesApi = "states";
  static String getCitiesApi = "cities";
  static String getAreasApi = "areas";
  static String getBlogApi = "blogs";
  static String getServicesApi = "get-services";



  static String wifiNetworksApi = "wifi/networks";
  static String wifiNetworkPlansApi(int id) => "wifi/networks/$id/plans";
  static String wifiPaymentGatewaysApi = "wifi/payment-gateways";
  static String wifiPlanPurchaseApi(int planId) => "wifi/plans/$planId/purchase";
  static String wifiOrderCodeApi(int transactionId) => "wifi/orders/$transactionId/code";
  static String wifiPlanPurchaseWebhookApi = "wifi/plans/purchase/webhook";
  static String wifiPurchasesApi = "wifi/purchases";
  static String wifiCodeEventsApi(int codeId) => "wifi/codes/$codeId/events";



  static String serviceRequestsIndexApi = "service-requests";
  static String serviceRequestsCreateApi = "service-requests";
  static String serviceRequestsAlternativeCreateApi = "services/requests";

  static String myServicesApi = "my-services";
  static String myServiceManageApi(int id) => "my-services/$id";

  static String getCurrencyRatesApi = "currency-rates";
  static String getCurrencyHistoryApi = "currency-rates/history";
  static String getMetalRatesApi = "metal-rates";
  static String getFaqApi = "faq";
  static String challengesApi = "challenges";
  static String getItemBuyerListApi = "item-buyer-list";
  static String getSellerApi = "get-seller";
  static String addItemReviewApi = "add-item-review";
  static String serviceReviewsApi = "service-reviews";
  static String addServiceReviewApi = "add-service-review";


  static String getVerificationFieldApi = "verification-fields";
  static String sendVerificationRequestApi = "send-verification-request";
  static String getVerificationRequestApi = "verification-request";
  static String getMyReviewApi = "my-review";
  static String myServiceReviewsApi = "my-service-reviews";

  static String addReviewReportApi = "add-review-report";
  static String addServiceReviewReportApi = "add-service-review-report";

  static String renewItemApi = "renew-item";
  static String usersByAccountTypeApi = "users-by-account-type";
  static String userProfileStatsApi = "user-profile-stats";
  static String userPreferencesApi = "user/preferences";

  // OTP module apis
  static String sendOtpApi = "send-otp";
  static String verifyOtpApi = "verify-otp";




  // Common query parameters
  static const String filterQuery = "filter";
  static const String perPageQuery = "per_page";
  static const String pageQuery = "page";
  static String updatePasswordApi = "update-password";

  // Chat module apis
  static String sendMessageApi = "send-message";
  static String getChatListApi = "chat-list";
  static String itemOfferApi = "item-offer";
  static String chatMessagesApi = "chat-messages";
  static String markMessageDeliveredApi = "mark-message-delivered";
  static String markMessageReadApi = "mark-message-read";
  static String blockUserApi = "block-user";
  static String chatConversationTypingApi(String conversationId) =>
      "chat/conversations/$conversationId/typing";
  static String chatConversationPresenceApi(String conversationId) =>
      "chat/conversations/$conversationId/presence";
  static String unBlockUserApi = "unblock-user";
  static String blockedUsersListApi = "blocked-users";
  static String getPaymentDetailsApi = "manual-payment-requests";
  static String getCartApi = "cart";
  static String addToCartApi = "cart/items";
  static String updateCartApi = "cart/items/update";
  static String removeCartItemApi = "cart/items/remove";
  static String clearCartApi = "cart/clear";
  static String cartQuoteShippingApi = "cart/quote-shipping";

  static String getDeliveryPricesApi = "delivery-prices";
  static String userOrdersApi = "orders";




  // not used API List
  static String userPurchasePackageApi = "user-purchase-package";
  static String deleteInquiryApi = "delete-inquiry";
  static String setItemEnquiryApi = "set-item_-inquiry";
  static String getItemApiEnquiry = "get-item-inquiry";
  static String interestedUsersApi = "interested-users";
  static String storeAdvertisementApi = "store-advertisement";
  static String deleteAdvertisementApi = "delete-advertisement";
  static String deleteChatMessageApi = "delete-chat-message";

  // ==========================
  // ✅ إضافات الدفع اليدوي/البنوك
  // ==========================
  /// مصفوفة بمسارات الـ API المحتملة للحصول على الحسابات البنكية اليدوية
  static const List<String> _manualBankApiCandidates = <String>[
    'manual-banks',
    'manual-payments/banks',
    // متروكة في النهاية للتوافق مع الإصدارات القديمة من الـ API
    'banks',
  ];

  static const int _manualBankDefaultPerPage = 50;
  static const int _manualBankMaxLoops = 20;

  // =======================
  // مفاتيح عامة متداولة
  // =======================
  static String id = "id";
  static String itemId = "item_id";
  static String mobile = "mobile";
  static String type = "type";
  static String firebaseId = "firebase_id";
  static String profile = "profile";
  static String fcmId = "fcm_id";
  static String address = "address";
  static String clientAddress = "client_address";
  static String email = "email";
  static String name = "name";
  static String amount = "amount";
  static String error = "error";
  static String message = "message";
  static String loginType = "logintype";
  static String isActive = "isActive";
  static String image = "image";
  static String category = "category";
  static String typeids = "typeids";
  static String userid = "userid";
  static String measurement = "measurement";
  static String categoryId = "category_id";
  static String title = "title";
  static String carpetArea = "carpet_area";
  static String builtUpArea = "built_up_area";
  static String plotArea = "plot_area";
  static String hectaArea = "hecta_area";
  static String acre = "acre";
  static String locationLatitude = "location_latitude";
  static String locationLongitude = "location_longitude";
  static String unitType = "unit_type";
  static String description = "description";
  static String furnished = "furnished";
  static String houseType = "house_type";
  static String taluka = "taluka";
  static String village = "village";
  static String properyType = "propery_type";
  static String price = "price";
  static String titleImage = "title_image";
  static String postCreated = "post_created";
  static String galleryImages = "gallery_images";
  static String typeId = "type_id";
  static String itemType = "item_type";
  static String imageUrl = "image_url";
  static String gallery = "gallery";
  static String parameterTypes = "parameter_types";
  static String status = "status";
  static String totalView = "total_view";
  static String addedBy = "added_by";
  static String district = "district";
  static String state = "state";
  static String houseNo = "house_no";
  static String surveyNo = "survey_no";
  static String plotNo = "plot_no";
  static String city = "city";
  static String languageCode = "language_code";
  static String country = "country";

  static String bathroom = "bathroom";
  static String aboutUs = "about_us";
  static String termsAndConditions = "terms_conditions";
  static String privacyPolicy = "privacy_policy";
  static String currencySymbol = "currency_symbol";
  static String company = "company";
  static String data = "data";
  static String actionType = "action_type";
  static String customerId = "customer_id";
  static String itemsId = "items_id";
  static String customersId = "customers_id";
  static String enqStatus = "status";
  static String search = "search";
  static String createdAt = "created_at";
  static String sendType = "send_type";
  static String created = "created";
  static String compName = "company_name";
  static String compWebsite = "company_website";
  static String compEmail = "company_email";
  static String compAdrs = "company_address";
  static String tele1 = "company_tel1";
  static String tele2 = "company_tel2";
  static String maintenanceMode = "maintenance_mode";
  static String maxPrice = "max_price";
  static String minPrice = "min_price";
  static String postedSince = "posted_since";
  static String item = "item";
  static String page = "page";
  static String topRated = "top_rated";
  static String promoted = "promoted";
  static String packageId = "package_id";
  static String notification = "notification";
  static String v360degImage = "threeD_image";
  static String videoLink = "video_link";
  static String categoryIds = "category_ids";
  static String sortBy = "sort_by";
  static String stateId = "state_id";
  static String countryId = "country_id";
  static String cityId = "city_id";
  static String countryCode = "country_code";
  static String personalDetail = "show_personal_details";
  static String soldTo = "sold_to";
  static String ratings = "ratings";
  static String review = "review";
  static String platformType = "platform_type";
  static String sellerReviewId = "seller_review_id";
  static String reportReason = "report_reason";
  static String requestDeviceApi = "request-device";
  static String requestSupportApi = "contact-us";

  /// POST عام (يدعم multipart تلقائيًا عند وجود File)
  static Future<Map<String, dynamic>> post({
    required String url,
    dynamic parameter,
    Options? options,
    bool? useBaseUrl,
    Map<String, dynamic>? extraHeaders,

  }) async {
    try {
      if (_isSliderEndpoint(url)) {
        await HiveUtils.ensureSliderSessionId();
      }

      final Dio dio = (dioFactory ?? () => Dio())();

      dio.options.followRedirects = false;
      dio.options.validateStatus = (_) => true;




      dio.interceptors.add(NetworkRequestInterseptor());

      FormData formData;
      final bool parameterIsFormData = parameter is FormData;

      if (parameterIsFormData) {
        formData = parameter as FormData;
      } else if (parameter is Map<String, dynamic>) {
        final Map<String, dynamic> formMap = <String, dynamic>{};

        parameter.forEach((key, value) {
          if (value is File) {
            // ملف واحد → نحوله MultipartFile
            formMap[key] = MultipartFile.fromFileSync(
              value.path,
              filename: value.path.split('/').last,
            );
          } else if (value is List<File>) {
            // قائمة ملفات → نحول كل عنصر
            formMap[key] = value
                .map((file) => MultipartFile.fromFileSync(
              file.path,
              filename: file.path.split('/').last,
            ))
                .toList();
          } else {
            // قيم عادية
            formMap[key] = value;
          }
        });

        // إنشاء FormData قابل للإرسال
        formData = FormData.fromMap(
          formMap,
          ListFormat.multiCompatible,
        );
      } else if (parameter == null) {
        formData = FormData();
      } else {
        throw ArgumentError(
          'Invalid parameter type. Expected Map<String, dynamic> or FormData.',
        );
      }



      final Map<String, dynamic>? optionHeaders = options?.headers;
      final Map<String, dynamic> mergedHeaders = <String, dynamic>{
        ...headers(),
        if (optionHeaders != null) ...optionHeaders,
        if (extraHeaders != null) ...extraHeaders,
      };

      if (parameterIsFormData) {
        mergedHeaders.removeWhere(
              (String key, dynamic value) =>
          key.toLowerCase() == HttpHeaders.contentTypeHeader &&
              value?.toString().toLowerCase() ==
                  Headers.jsonContentType.toLowerCase(),
        );
      }

      _ensureSliderSessionHeaders(mergedHeaders);

      final bool requestBodyIsMultipart =
          parameterIsFormData || formData.files.isNotEmpty;

      String? explicitContentTypeHeaderKey;
      String? explicitContentTypeHeaderValue;

      mergedHeaders.forEach((String key, dynamic value) {
        if (key.toLowerCase() == HttpHeaders.contentTypeHeader) {
          explicitContentTypeHeaderKey ??= key;
          explicitContentTypeHeaderValue = value?.toString();
        }
      });



      String? normalizedHeaderContentType;
      if (explicitContentTypeHeaderValue != null) {
        final String candidate = explicitContentTypeHeaderValue!.trim();
        if (candidate.isNotEmpty) {
          normalizedHeaderContentType = candidate.toLowerCase();
        }
      }

      final Object? optionContentType = options?.contentType;
      String? normalizedOptionContentType;

      if (optionContentType != null) {
        final String candidate = optionContentType.toString().trim();
        if (candidate.isNotEmpty) {
          normalizedOptionContentType = candidate.toLowerCase();
        }
      }


      bool hasCustomContentTypeOption = false;
      if (normalizedOptionContentType != null) {
        final String normalized = normalizedOptionContentType;

        final String jsonContentType = Headers.jsonContentType.toLowerCase();
        final String formUrlEncodedContentType =
        Headers.formUrlEncodedContentType.toLowerCase();
        final bool isJsonDefault =
            normalized == jsonContentType ||
                normalized.startsWith('application/json');
        final bool isFormUrlEncoded = normalized == formUrlEncodedContentType;
        final bool isMultipart = normalized.startsWith('multipart/form-data');
        hasCustomContentTypeOption =
        !(isJsonDefault || isFormUrlEncoded || isMultipart);
      }

      bool hasCustomContentTypeHeader = false;
      if (normalizedHeaderContentType != null) {
        final String normalized = normalizedHeaderContentType!;
        final String jsonContentType = Headers.jsonContentType.toLowerCase();
        final String formUrlEncodedContentType =
        Headers.formUrlEncodedContentType.toLowerCase();
        final bool isJsonDefault =
            normalized == jsonContentType ||
                normalized.startsWith('application/json');
        final bool isFormUrlEncoded = normalized == formUrlEncodedContentType;
        final bool isMultipart = normalized.startsWith('multipart/form-data');
        hasCustomContentTypeHeader =
        !(isJsonDefault || isFormUrlEncoded || isMultipart);      }

      final bool shouldNullifyContentType = requestBodyIsMultipart &&
          !hasCustomContentTypeHeader &&
          !hasCustomContentTypeOption;

      if (shouldNullifyContentType && explicitContentTypeHeaderKey != null) {
        mergedHeaders.remove(explicitContentTypeHeaderKey);
      }

      if (shouldNullifyContentType) {
        dio.options.contentType = null;
      }


      final Object? resolvedContentType = parameterIsFormData
          ? null
          : shouldNullifyContentType
          ? null
          : (options?.contentType ?? _contentTypeNotSpecified);

      final Options requestOptions = _buildRequestOptions(
        base: options,
        headers: mergedHeaders,
        contentType: resolvedContentType,
        followRedirects: false,
      );


      final response = await dio.post(
        ((useBaseUrl ?? true) ? Constant.baseUrl : "") + url,
        data: formData,
        options: requestOptions,

      );

      final int statusCode = response.statusCode ?? 0;
      final dynamic rawBody = response.data;
      final Map<String, dynamic> resp = rawBody is Map<String, dynamic>
          ? Map<String, dynamic>.from(rawBody)
          : rawBody is Map
          ? rawBody.map((key, value) => MapEntry(key.toString(), value))
          : <String, dynamic>{'data': rawBody};

      if (statusCode >= 400) {
        throw ApiHttpException(
          errorMessage: resp['message']?.toString() ?? 'request-failed',
          statusCode: statusCode,
          payload: resp,
        );
      }
      if (resp['error'] == true) {
        throw ApiException(resp['message'].toString());
      }

      return resp;
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 401) {
        userExpired();
      }
      if (statusCode == 302 || statusCode == 307) {
        userExpired();
        throw ApiHttpException(
          errorMessage: 'unauthenticated',
          statusCode: 401,
          payload: e.response?.data,
          cause: e,
        );
      }

      if (statusCode == 503) {

        throw "server-not-available";
      }

      throw ApiHttpException(
        errorMessage: e.error is SocketException
            ? "no-internet"
            : "Something went wrong with error ${e.response?.statusCode}",
        statusCode: statusCode,
        payload: e.response?.data,
        cause: e,


      );


    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(e.toString());
    }
  }

  /// معالجة انتهاء صلاحية جلسة المستخدم
  static void userExpired() {
    HelperUtils.showSnackBarMessage(Constant.navigatorKey.currentContext!,
        "userIsDeactivated".translate(Constant.navigatorKey.currentContext!),
        messageDuration: 3);
    Future.delayed(const Duration(seconds: 2), () {
      HiveUtils.clear();
      Constant.favoriteItemList.clear();
      Constant
          .navigatorKey.currentContext!
          .read<UserDetailsCubit>()
          .clear();
      Constant
          .navigatorKey.currentContext!
          .read<FavoriteCubit>()
          .resetState();
      Constant
          .navigatorKey.currentContext!
          .read<UpdatedReportItemCubit>()
          .clearItem();
      Constant
          .navigatorKey.currentContext!
          .read<GetBuyerChatListCubit>()
          .resetState();
      Constant
          .navigatorKey.currentContext!
          .read<BlockedUsersListCubit>()
          .resetState();
      HiveUtils.logoutUser(
        Constant.navigatorKey.currentContext!,
        onLogout: () {},
      );
    });
  }

  /// DELETE عام
  static Future<Map<String, dynamic>> delete({
    required String url,
    Map<String, dynamic>? queryParameters,
    bool? useBaseUrl,
  }) async {
    try {
      if (_isSliderEndpoint(url)) {
        await HiveUtils.ensureSliderSessionId();
      }
      final Dio dio = Dio();

      dio.options.followRedirects = false;
      dio.options.validateStatus =
          (status) => status != null && status < 400;

      dio.interceptors.add(NetworkRequestInterseptor());

      final response = await dio.delete(
        ((useBaseUrl ?? true) ? Constant.baseUrl : "") + url,
        queryParameters: queryParameters,
        options: Options(
          headers: headers(),
          followRedirects: false,
        ),
      );

      if (response.data['error'] == true) {
        throw ApiException(response.data['message'].toString());
      }
      return Map.from(response.data);
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 401) {
        userExpired();
      }
      if (statusCode == 302 || statusCode == 307) {
        userExpired();
        throw ApiHttpException(
          errorMessage: 'unauthenticated',
          statusCode: 401,
          payload: e.response?.data,
          cause: e,
        );
      }
      if (statusCode == 503) {
        throw "server-not-available";
      }

      throw ApiHttpException(
        errorMessage: e.error is SocketException
            ? "no-internet"
            : "Something went wrong with error ${e.response?.statusCode}",
        statusCode: statusCode,
        payload: e.response?.data,
        cause: e,
      );
    } on ApiException {
      rethrow;


    } catch (e, st) {
      throw ApiException(st.toString());
    }
  }




  static Future<Map<String, dynamic>> requestJson({

    required String url,
    String method = 'POST',

    Map<String, dynamic>? data,
    Options? options,
    bool? useBaseUrl,
    Map<String, dynamic>? extraHeaders,
  }) async {
    final String resolvedMethod = method.toUpperCase();

    try {
      if (_isSliderEndpoint(url)) {
        await HiveUtils.ensureSliderSessionId();
      }
      final Dio dio = Dio();


      dio.options.followRedirects = false;
      dio.options.validateStatus =
          (status) => status != null && status < 400;

      dio.interceptors.add(NetworkRequestInterseptor());

      final Map<String, dynamic>? optionHeaders = options?.headers;
      final Map<String, dynamic> mergedHeaders = <String, dynamic>{

        ...headers(),
        if (optionHeaders != null) ...optionHeaders,
        if (extraHeaders != null) ...extraHeaders,
      };

      mergedHeaders['Accept'] = 'application/json';

      final bool hasJsonBody =
          resolvedMethod == 'POST' || resolvedMethod == 'PUT' || resolvedMethod == 'PATCH';
      final bool dataIsFormData = data is FormData;

      if (hasJsonBody) {
        if (dataIsFormData) {
          mergedHeaders.removeWhere(
                (String key, dynamic value) =>
            key.toLowerCase() == HttpHeaders.contentTypeHeader &&
                value?.toString().toLowerCase() ==
                    Headers.jsonContentType.toLowerCase(),
          );
        } else {
          mergedHeaders[Headers.contentTypeHeader] =
              options?.contentType ?? Headers.jsonContentType;
        }
      }

      _ensureSliderSessionHeaders(mergedHeaders);

      final Object? requestContentType;
      if (!hasJsonBody) {
        requestContentType = options?.contentType;
      } else {
        requestContentType = dataIsFormData
            ? null
            : (options?.contentType ?? Headers.jsonContentType);
      }

      final Options requestOptions = _buildRequestOptions(
        base: options,
        method: resolvedMethod,
        headers: mergedHeaders,
        contentType: requestContentType,

        followRedirects: false,

      );

      String? extractMessage(dynamic payload) {
        if (payload is Map<String, dynamic>) {
          for (final String key in const <String>['message', 'error']) {
            final dynamic candidate = payload[key];
            if (candidate is String) {
              final String trimmed = candidate.trim();
              if (trimmed.isNotEmpty) {
                return trimmed;
              }
            }
          }
        } else if (payload is Map) {
          final Map<String, dynamic> converted = Map<String, dynamic>.from(payload as Map);
          return extractMessage(converted);
        } else if (payload is String) {
          final String trimmed = payload.trim();
          if (trimmed.isNotEmpty) {
            return trimmed;
          }
        }
        return null;
      }

      Map<String, dynamic>? asMap(dynamic payload) {
        if (payload is Map<String, dynamic>) {
          return payload;
        }
        if (payload is Map) {
          return Map<String, dynamic>.from(payload as Map);
        }
        return null;
      }


      final response = await dio.request(
        ((useBaseUrl ?? true) ? Constant.baseUrl : "") + url,
        data: hasJsonBody ? (data ?? const <String, dynamic>{}) : data,
        options: requestOptions,
      );

      final int statusCode = response.statusCode ?? 0;
      final dynamic rawPayload = response.data;
      final Map<String, dynamic>? payloadMap = asMap(rawPayload);

      final bool redirectedToLogin = statusCode == 302 || statusCode == 307;
      final int normalizedStatus = redirectedToLogin ? 401 : statusCode;

      if (redirectedToLogin || normalizedStatus == 401 || normalizedStatus == 403) {
        userExpired();
      }
      if (normalizedStatus == 503) {
        throw "server-not-available";
      }

      if (normalizedStatus < 200 || normalizedStatus >= 300) {
        final dynamic errorPayload =
        payloadMap != null ? Map<String, dynamic>.from(payloadMap) : rawPayload;
        throw ApiHttpException(
          errorMessage: extractMessage(errorPayload) ?? 'request-failed',
          statusCode: normalizedStatus,
          payload: errorPayload,
        );
      }

      if (payloadMap != null) {
        return Map<String, dynamic>.from(payloadMap);


      }
      if (rawPayload == null) {
        return <String, dynamic>{};
      }
      return <String, dynamic>{'data': rawPayload};
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 401 || statusCode == 403) {
        userExpired();
      }
      if (statusCode == 302 || statusCode == 307) {
        userExpired();
        throw ApiHttpException(
          errorMessage: 'unauthenticated',
          statusCode: 401,
          payload: e.response?.data,
          cause: e,
        );
      }
      if (statusCode == 503) {
        throw "server-not-available";
      }

      throw ApiHttpException(
        errorMessage: e.error is SocketException
            ? "no-internet"
            : "Something went wrong with error ${e.response?.statusCode}",
        statusCode: statusCode,
        payload: e.response?.data,
        cause: e,
      );
    } on ApiException {
      rethrow;
    } catch (e, st) {
      throw ApiException(st.toString());
    }
  }


  /// POST helper that sends JSON body instead of multipart.
  static Future<Map<String, dynamic>> postJson({
    required String url,
    Map<String, dynamic>? data,
    Options? options,
    bool? useBaseUrl,
    Map<String, dynamic>? extraHeaders,
  }) {
    return requestJson(
      url: url,
      data: data,
      options: options,
      useBaseUrl: useBaseUrl,
      extraHeaders: extraHeaders,
    );
  }


  /// GET عام
  static Future<Map<String, dynamic>> get({
    required String url,
    Map<String, dynamic>? queryParameters,
    bool? useBaseUrl,
    bool enableEtagCache = false,

  }) async {
    try {
      if (_isSliderEndpoint(url)) {
        await HiveUtils.ensureSliderSessionId();
      }

      final Dio dio = Dio();

      dio.options.followRedirects = false;
      dio.options.validateStatus =
          (status) => status != null && status < 400;

      dio.interceptors.add(NetworkRequestInterseptor());

      final bool resolvedUseBaseUrl = useBaseUrl ?? true;
      final String requestUrl =
          (resolvedUseBaseUrl ? Constant.baseUrl : "") + url;

      final Map<String, dynamic> requestHeaders = headers();
      final _CachedApiResponse? cachedResponse = enableEtagCache
          ? _ApiResponseCache.get(requestUrl, queryParameters)
          : null;

      if (enableEtagCache && cachedResponse?.eTag != null) {
        requestHeaders['If-None-Match'] = cachedResponse!.eTag;
      }


      final response = await dio.get(
        requestUrl,
        queryParameters: queryParameters,
        options: Options(
          headers: requestHeaders,
          followRedirects: false,
        ),
      );

      final int statusCode = response.statusCode ?? 0;

      if (statusCode == 304) {
        if (enableEtagCache && cachedResponse != null) {
          return Map<String, dynamic>.from(cachedResponse.payload);
        }
        return <String, dynamic>{};
      }
      final dynamic responseData = response.data;
      final Map<String, dynamic> responseMap = responseData is Map
          ? Map<String, dynamic>.from(
        responseData as Map<dynamic, dynamic>,
      )
          : <String, dynamic>{'data': responseData};

      if (enableEtagCache && statusCode >= 200 && statusCode < 300) {
        final String? eTag = response.headers.value('etag');
        _ApiResponseCache.store(
          requestUrl,
          queryParameters,
          responseMap,
          eTag,
        );
      }

      if (responseMap['error'] == true) {
        throw ApiException(responseMap['message'].toString());
      }
      return responseMap;
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 401) {
        userExpired();
      }
      if (statusCode == 302 || statusCode == 307) {
        userExpired();
        throw ApiHttpException(
          errorMessage: 'unauthenticated',
          statusCode: 401,
          payload: e.response?.data,
          cause: e,
        );
      }
      if (statusCode == 503) {
        throw "server-not-available";
      }

      throw ApiHttpException(
        errorMessage: e.error is SocketException
            ? "no-internet"
            : "Something went wrong with error ${e.response?.statusCode}",
        statusCode: statusCode,
        payload: e.response?.data,
        cause: e,
      );
    } on ApiException {
      rethrow;

    } catch (e, st) {
      throw ApiException(st.toString());
    }
  }

  // =========================================
  // ✅ دوال الدفع اليدوي (البنوك) — إضافاتك
  // =========================================

  /// جلب قائمة الحسابات البنكية من السيرفر
  /// - الراوت في لاراڤيل: GET /api/banks
  /// - الدالة تدعم الرد بالشكل:
  ///   { "data": [ ... ] } أو [ ... ] مباشرة


  static Future<List<BankAccount>> fetchBanks() async {
    ApiHttpException? lastHttpError;

    for (final endpoint in _manualBankApiCandidates) {
      try {
        final List<BankAccount> collected = <BankAccount>[];
        int currentPage = 1;
        int loop = 0;

        while (true) {
          final Map<String, dynamic> response = await Api.get(
            url: endpoint,
            queryParameters: <String, dynamic>{
              'per_page': _manualBankDefaultPerPage,
              'page': currentPage,
            },
          );

          final _ManualBankPage page = _parseManualBankResponse(response);

          if (page.items.isEmpty && loop == 0) {
            break;
          }


          collected.addAll(page.items);


          final Map<String, dynamic>? meta = page.meta;
          final int? current = _manualBankAsInt(meta?['current_page']) ?? currentPage;
          final int? last = _manualBankAsInt(meta?['last_page']);
          final bool? metaHasMore = _manualBankAsBool(meta?['has_more_pages']);

          final bool canLoop = loop < _manualBankMaxLoops - 1;
          final bool hasMorePages = metaHasMore != null
              ? (metaHasMore && canLoop)
              : (last != null && current != null && current < last && canLoop);

          if (!hasMorePages || current == null) {

            break;
          }

          currentPage = current + 1;
          loop += 1;
        }

        if (collected.isNotEmpty) {
          return collected;
        }
      } on ApiHttpException catch (error) {
        lastHttpError = error;

        if (error.statusCode != 404 &&
            error.statusCode != 405 &&
            error.statusCode != 410) {
          throw error;
        }
      }
    }

    if (lastHttpError != null) {
      throw lastHttpError;
    }

    throw ApiException('فشل في جلب الحسابات البنكية اليدوية');
  }


  static _ManualBankPage _parseManualBankResponse(Map<String, dynamic> response) {
    final List<BankAccount> accounts = <BankAccount>[];
    Map<String, dynamic>? meta;

    final Set<int> visited = <int>{};

    void inspect(dynamic node) {
      if (node == null) {
        return;
      }

      if (node is Iterable) {
        for (final element in node) {
          inspect(element);
        }
        return;
      }

      final Map<String, dynamic>? map = _mapifyManualBank(node);
      if (map == null) {
        return;
      }

      meta ??= _mapifyManualBank(map['meta']) ?? meta;

      final int hash = identityHashCode(map);
      if (!visited.add(hash)) {
        return;
      }

      const containerKeys = <String>{
        'manual_payment_banks',
        'manualPaymentBanks',
        'manual_banks',
        'manualBanks',
        'banks',
        'data',
        'items',
        'records',
        'list',
        'payload',
      };

      bool drilled = false;

      for (final key in containerKeys) {
        if (!map.containsKey(key)) {
          continue;
        }
        drilled = true;
        inspect(map[key]);
      }

      if (drilled) {
        return;
      }

      if (_looksLikeManualBank(map)) {
        accounts.add(BankAccount.fromJson(map));
      }
    }

    inspect(response['data']);
    if (accounts.isEmpty) {
      inspect(response['banks']);
    }
    if (accounts.isEmpty) {
      inspect(response);
    }

    meta ??= _mapifyManualBank(response['meta']);

    return _ManualBankPage(items: accounts, meta: meta);
  }

  static Map<String, dynamic>? _mapifyManualBank(dynamic source) {
    if (source is Map<String, dynamic>) {
      return source;
    }

    if (source is Map) {
      final map = <String, dynamic>{};
      source.forEach((key, value) {
        if (key == null) {
          return;
        }
        map[key.toString()] = value;
      });
      return map;
    }

    return null;
  }

  static bool _looksLikeManualBank(Map<String, dynamic> map) {
    const possibleKeys = <String>{
      'bank_name',
      'beneficiary_name',
      'account_name',
      'account_number',
      'iban',
      'swift',
      'manual_bank_id',
    };

    for (final key in possibleKeys) {
      if (map.containsKey(key)) {
        return true;
      }
    }

    return false;
  }

  static int? _manualBankAsInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is double) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(value);
    }

    return null;
  }

  static bool? _manualBankAsBool(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    if (value is String) {
      final normalized = value.trim().toLowerCase();

      if (normalized.isEmpty) {
        return null;
      }

      if (<String>{'1', 'true', 'yes', 'on'}.contains(normalized)) {
        return true;
      }

      if (<String>{'0', 'false', 'no', 'off'}.contains(normalized)) {
        return false;
      }
    }

    return null;
  }

  // إرسال إثبات تحويل (رفع إيصال) للدفع اليدوي
  // - الراوت في لاراڤيل: POST /api/payments/manual (محمي بمصادقة Sanctum)
  // - يرسل Multipart يتضمن صورة الإيصال + بيانات التحويل
  // - الحقول الاختيارية تُرسَل فقط عند توفرها


  static Future<Map<String, dynamic>> submitManualPayment({
    required int bankAccountId,      // معرف الحساب البنكي من السيرفر
    required double amount,          // المبلغ المحوَّل
    String? currency,                // مثال: YER / SAR
    String? transferDate,            // بالتنسيق 'YYYY-MM-DD'
    String? reference,               // رقم مرجعي (اختياري)
    String? notes,                   // ملاحظات (اختياري)
    Map<String, dynamic>? contextData, // سياق ربط إضافي (اختياري) مثل {order_id:123}
    required File receiptImage,      // ملف صورة الإيصال
  }) async {
    final body = <String, dynamic>{
      'bank_account_id': bankAccountId,
      'amount': amount,
      if (currency != null) 'currency': currency,
      if (transferDate != null) 'transfer_date': transferDate,
      if (reference != null) 'reference': reference,
      if (notes != null) 'notes': notes,
      if (contextData != null) 'context': contextData,
      // Api.post سيحوّل File → MultipartFile تلقائيًا
      'receipt_image': receiptImage,
    };

    final res = await Api.post(
      url: submitManualPaymentApi,
      parameter: body,
      extraHeaders: <String, dynamic>{
        'Idempotency-Key': Api.generateIdempotencyKey(),
      },
    );

    return Map<String, dynamic>.from(res);
  }


  static String generateIdempotencyKey() {
    final String timestamp = DateTime.now().toUtc().toIso8601String();
    final String randomSuffix =
    Random().nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    return '$timestamp-$randomSuffix';
  }
}


class _ManualBankPage {
  const _ManualBankPage({
    required this.items,
    this.meta,
  });

  final List<BankAccount> items;
  final Map<String, dynamic>? meta;
}