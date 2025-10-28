import 'package:marib/utils/helper_utils.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:marib/utils/payment/bank_account.dart';
import 'package:marib/utils/payment/east_yemen_bank_config.dart';

/// Configure your app from here
/// Most of basic configuration will be from here
/// For theme colors go to [lib/Ui/Theme/theme.dart]
///
///

enum PaymentGatewayType { wallet, manualBank, eastYemenBank }

class PaymentGateway {
  const PaymentGateway({
    required this.id,
    required this.name,
    required this.type,
    this.enabled = true,
    this.metadata = const <String, dynamic>{},
  });

  final String id;
  final String name;
  final PaymentGatewayType type;
  final bool enabled;
  final Map<String, dynamic> metadata;

  bool get isEnabled => enabled;
}

class AppSettings {
  /// Basic Settings
  static const String applicationName = 'مارب بين يديك';
  static const String andoidPackageName = 'com.marib.app';
  static const String shareAppText = "Share this App";

  // static const String hostUrl =  "https://maribsrv.com";

  static const String hostUrl = "http://192.168.1.25:8000";

  ///API Setting

  static const int apiDataLoadLimit = 20;
  static const int sectionItemsPageSize = 6;
  static const int maxCategoryShowLengthInHomeScreen = 5;

  /// Enable verbose network logging in non-production builds.
  ///
  /// Keep this `false` by default to avoid dumping large payloads during normal
  /// development sessions. Developers who need to troubleshoot specific calls
  /// can either flip this flag locally or use [setNetworkLoggingOverride] at
  /// runtime when running a debug/profile build.
  static const bool enableNetworkLogging = bool.fromEnvironment(
    'MARIB_ENABLE_NETWORK_LOGGING',
    defaultValue: false,
  );

  static bool _networkLoggingOverride = false;

  /// Whether network logging should currently be active (ignoring build mode).
  static bool get isNetworkLoggingEnabled =>
      enableNetworkLogging || _networkLoggingOverride;

  /// Allows temporarily enabling or disabling verbose network logging at
  /// runtime for debugging sessions without touching the default setting.
  static void setNetworkLoggingOverride(bool enabled) {
    _networkLoggingOverride = enabled;
  }

  /// Enable the custom performance monitor in debug/profile builds.
  /// Keep this `false` in production unless troubleshooting locally.
  static const bool enablePerfLogging = bool.fromEnvironment(
    'MARIB_ENABLE_PERF_LOGGING',
    defaultValue: false,
  );

  static bool _performanceLoggingOverride = false;


  /// Returns whether performance logging has been enabled explicitly.
  ///
  /// This combines the compile-time flag with the runtime override to make
  /// it easy to toggle metrics collection for diagnostics when needed.
  static bool get isPerformanceLoggingEnabled =>
      enablePerfLogging || _performanceLoggingOverride;

  /// Allows manual enabling of the performance monitor at runtime.
  ///
  /// This is useful for local diagnostics without flipping the default flag
  /// for all developers.
  static void setPerformanceLoggingOverride(bool enabled) {
    _performanceLoggingOverride = enabled;
  }



  static final String baseUrl =
      "${HelperUtils.checkHost(hostUrl)}api/"; //don't change this

  static const int hiddenAPIProcessDelay = 1;

  /* this is for load data when open app if old data is already available so
it will call API in background without showing the process and when data available it will replace it with new data */

  ///Google ADMOB
  ///Please make sure to add app ids into the platform files. for the android you have to add into AndroidManifest.xml and for the ios you will have to add it in the info.plist file.

  ///Set type here
  static const DeepLinkType deepLinkingType = DeepLinkType.native;

  static const String shareNavigationWebUrl = "maribsrv.com";

  /// You will find this prefix from firebase console in dynamic link section
  static const String deepLinkPrefix =
      "https://maribsrv.page.link"; //demo.page.link

  //set anything you want
  static const String deepLinkName = "maribsrv.com"; //deeplink demo.com

  static const MapType googleMapType =
      MapType.satellite; //none , normal , satellite , terrain , hybrid

  ///Firebase authentication OTP timer.
  static const int otpResendSecond = 60 * 2;
  static const int otpTimeOutSecond = 60 * 2;

  ///This code will show on login screen [Note: don't add  + symbol]
  static const String defaultCountryCode = "967";
  static const bool disableCountrySelection = false;

  ///Lottie animation
  ///Put your loading json file in [lib/assets/lottie/] folder
  static const String successLoadingLottieFile = "loading_success.json";
  static const String successCheckLottieFile = "success_check.json";
  static const String progressLottieFileWhite =
      "loading_white.json"; //When there is dark background and you want to show progress so it will be used

  static const String maintenanceModeLottieFile = "maintenancemode.json";

  static const bool useLottieProgress =
      true; //if you don't want to use lottie progress then set it to false'

  ///Other settings
  static const String notificationChannel = "basic_channel"; //
  static int uploadImageQuality = 50; //0 to 100th
  static const Set additionalRTLlanguages =
      {}; //Add language code in brackat  {"ab","bc"}

/////Advance settings
//This file is located in assets/riveAnimations
  // static const String riveAnimationFile = "rive_animation.riv";

  static const Map<String, dynamic> riveAnimationConfigurations = {
    // "add_button": {
    //   "artboard_name": "Add",
    //   "state_machine": "click",
    //   "boolean_name": "isReverse",
    //   "boolean_initial_value": true,
    //   "add_button_shape_name": "shape",
    // },
  };

  static List<PaymentGateway> paymentGateways = const <PaymentGateway>[];
  static bool walletEnabled = true;
  static List<BankAccount> manualPaymentBanks = const <BankAccount>[];
  static EastYemenBankConfig? eastYemenBankConfig;

  static void updatePaymentGateways({
    bool wallet = true,
    List<BankAccount>? manualBanks,
    EastYemenBankConfig? eastYemenBank,
  }) {
    walletEnabled = wallet;
    manualPaymentBanks = manualBanks == null
        ? const <BankAccount>[]
        : List<BankAccount>.unmodifiable(manualBanks);
    eastYemenBankConfig = eastYemenBank;

    final List<PaymentGateway> configured = <PaymentGateway>[
      PaymentGateway(
        id: 'wallet',
        name: 'المحفظة',
        type: PaymentGatewayType.wallet,
        enabled: wallet,
      ),
    ];

    if (eastYemenBank != null) {
      configured.add(
        PaymentGateway(
          id: 'east_yemen_bank',
          name: eastYemenBank.displayName,
          type: PaymentGatewayType.eastYemenBank,
          enabled: eastYemenBank.isEnabled,
          metadata: <String, dynamic>{
            'note': eastYemenBank.note,
            'logo_url': eastYemenBank.logoUrl,
            'currency_code': eastYemenBank.currencyCode,
            'raw': eastYemenBank.raw,
          },
        ),
      );
    }

    if (manualPaymentBanks.isNotEmpty) {
      configured.add(
        const PaymentGateway(
          id: 'manual_bank',
          name: 'تحويل بنكي',
          type: PaymentGatewayType.manualBank,
        ),
      );
    }

    paymentGateways = configured;
  }

  static List<PaymentGateway> getEnabledPaymentGateways() {
    return paymentGateways
        .where((gateway) => gateway.isEnabled)
        .toList(growable: false);
  }
}

enum DeepLinkType { native }
