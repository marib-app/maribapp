import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:marib/data/model/item/item_model.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:marib/data/helper/custom_exception.dart';
import 'package:marib/settings.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:marib/settings.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:marib/utils/constant.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';



enum MessageType {
  success(successMessageColor),
  warning(warningMessageColor),
  error(errorMessageColor);

  final Color value;

  const MessageType(this.value);
}

extension StringCasingExtension on String {
  String toCapitalized() =>
      length > 0 ? '${this[0].toUpperCase()}${substring(1).toLowerCase()}' : '';

  String toTitleCase() => replaceAll(RegExp(' +'), ' ')
      .split(' ')
      .map((str) => str.toCapitalized())
      .join(' ');
}



class HelperUtils {

  static final List<_SoftSnackBarController> _activeSoftSnackbars =
  <_SoftSnackBarController>[];

  static void _reindexActiveSoftSnackbars() {
    for (var i = 0; i < _activeSoftSnackbars.length; i++) {
      if (i == 0) {
        _activeSoftSnackbars[i].promote();
      } else {
        _activeSoftSnackbars[i].demote(i);
      }
    }
  }


  static String absoluteImage(String? path) {
    final String value = (path ?? '').trim();
    if (value.isEmpty) {
      return '';
    }

    final Uri? parsed = Uri.tryParse(value);
    final bool hasScheme = parsed?.hasScheme ?? false;
    if (hasScheme) {

      return value;
    }


    final Uri? hostOrigin = _resolveHostOrigin();

    if (value.startsWith('//')) {
      if (hostOrigin != null) {
        return '${hostOrigin.scheme}:$value';
      }
      return 'https:$value';
    }

    final bool isStoragePath =
        value.startsWith('storage/') || value.startsWith('/storage/');
    final bool isRelativePath = !hasScheme;

    if (hostOrigin != null && (isStoragePath || isRelativePath)) {
      return hostOrigin.resolve(value).toString();
    }



    final String base = Constant.baseUrl;
    if (base.isEmpty) {
      return value;
    }

    final Uri? fallbackBase = Uri.tryParse(base);
    if (fallbackBase != null && fallbackBase.hasAuthority && fallbackBase.hasScheme) {
      final Uri normalized = fallbackBase.replace(path: '/', query: null, fragment: null);
      return normalized.resolve(value).toString();
    }


    if (base.endsWith('/') && value.startsWith('/')) {
      return base.substring(0, base.length - 1) + value;
    }

    if (!base.endsWith('/') && !value.startsWith('/')) {

      return '$base/$value';
    }

    return '$base$value';
  }

  static Uri? _resolveHostOrigin() {
    Uri? parseAndNormalize(String? candidate) {
      final String raw = (candidate ?? '').trim();
      if (raw.isEmpty) {
        return null;
      }

      final Uri? uri = Uri.tryParse(raw);
      if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
        return null;
      }

      if (uri.scheme != 'http' && uri.scheme != 'https') {
        return null;
      }

      return uri.replace(path: '/', query: null, fragment: null);
    }

    final Uri? host = parseAndNormalize(AppSettings.hostUrl);
    if (host != null) {
      return host;
    }

    final Uri? base = parseAndNormalize(Constant.baseUrl);
    if (base != null) {
      return base;
    }

    return null;
  }



  static String formatPhoneNumber(String fullNumber, String countryCode) {
    countryCode = countryCode.replaceAll('+', '');
    fullNumber = fullNumber.replaceAll('+', '');

    if (!fullNumber.startsWith(countryCode)) {
      fullNumber = countryCode + fullNumber;
    }

    return '+' + fullNumber;
  }

  static final NumberFormat _priceGroupingFormatter = NumberFormat("#,###", "en");

  /// تنسيق الأرقام الكبيرة إلى صيغة مختصرة بالعربية مع دعم حتى «ديسيليون».
  /// - الأرقام الأقل من 10000 تُعرض كما هي مع فواصل آلاف.
  /// - عند تجاوز ذلك يتم التقسيم على 1000 تدريجيًا واختيار الوحدة المناسبة.
  /// - يتم التخلص من الأصفار العشرية غير اللازمة.
  /// - إذا كانت القيمة `null` يتم إرجاع سلسلة فارغة ليُتَعامل معها خارجيًا.



  static String formatPrice(num? price) {
    if (price == null) {
      return '';
    }

    final double absoluteValue = price.abs().toDouble();
    if (absoluteValue == 0) {
      return '0';
    }
    const List<String> units = <String>[
      '',
      'ألف',
      'مليون',
      'مليار',
      'تريليون',
      'كوادريليون',
      'كوينتيليون',
      'سكستيليون',
      'سبتيليون',
      'أوكتيليون',
      'نونيليون',
      'ديسيليون',
    ];

    if (absoluteValue < 10000) {
      final String formatted = _priceGroupingFormatter.format(absoluteValue);
      return price.isNegative ? '-$formatted' : formatted;



    }
    int unitIndex = 0;
    double displayValue = absoluteValue;
    while (displayValue >= 1000 && unitIndex < units.length - 1) {
      displayValue /= 1000;
      unitIndex++;
    }

    String formattedValue;
    if (displayValue == displayValue.roundToDouble()) {
      formattedValue = displayValue.toInt().toString();
    } else {
      formattedValue = displayValue.toStringAsFixed(1);
      if (formattedValue.endsWith('.0')) {
        formattedValue = formattedValue.substring(0, formattedValue.length - 2);
      }
    }

    final String unitLabel = units[unitIndex];
    final String valueWithUnit = unitLabel.isEmpty
        ? formattedValue
        : '$formattedValue $unitLabel';

    return price.isNegative ? '-$valueWithUnit' : valueWithUnit;
  }


  static String nativeDeepLinkUrlOfItem(String itemSlug) {
    return "https://${AppSettings.shareNavigationWebUrl}/product-details/$itemSlug?share=true";
  }



  static Future<void> shareImageAndText(String imageUrl, String text) async {
    try {
      // تحميل الصورة من الانترنت
      final response = await http.get(Uri.parse(imageUrl));
      final bytes = response.bodyBytes;

      // حفظ الصورة مؤقتاً
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/shared_image.jpg');
      await file.writeAsBytes(bytes);

      // مشاركة الصورة مع النص
      await Share.shareXFiles(
        [XFile(file.path)],
        text: text,
      );
    } catch (e) {
      print("خطأ في مشاركة الصورة: $e");
    }
  }

  static Future<void> shareWithImage(
      BuildContext context,
      String itemSlug, {
        required ItemModel model,
      }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String deepLink = HelperUtils.nativeDeepLinkUrlOfItem(itemSlug);

    // تجهيز نص المشاركة (مثل ما شرحنا قبل)
    String shareMessage = "..."; // جهز نص المشاركة

    // جلب رابط الصورة من الإعلان تلقائي
    String imageUrl = model.image ?? (model.galleryImages?.isNotEmpty == true ? model.galleryImages!.first.image! : "");

    if (imageUrl.isNotEmpty) {
      await shareImageAndText(imageUrl, shareMessage);
    } else {
      // مشاركة نص فقط لو ما في صورة
      await Share.share(shareMessage);
    }
  }



  ////////////    دالة زر المشاركة للاعلانات

  static Future<void> share(
      BuildContext context,

      String itemSlug, {
        required ItemModel model,
      }) async {

    final isDark = Theme.of(context).brightness == Brightness.dark;
    String deepLink = HelperUtils.nativeDeepLinkUrlOfItem(itemSlug);




    // اختيار الإيموجي حسب اسم الفئة (تقدر تضيف فئات أكثر)
    String emoji = "📢";
    String categoryName = model.category?.name?.toLowerCase() ?? "";
    if (categoryName.contains("عقار") || categoryName.contains("شقة") || categoryName.contains("منزل")) {
      emoji = "🏠";
    } else if (categoryName.contains("سيارة") || categoryName.contains("مركبة")) {
      emoji = "🚗";
    } else if (categoryName.contains("وظيفة") || categoryName.contains("عمل")) {
      emoji = "💼";
    } else if (categoryName.contains("عرض") || categoryName.contains("تخفيض") || categoryName.contains("خصم")) {
      emoji = "🎉";
    } else if (categoryName.contains("منتج") || categoryName.contains("سلعة")) {
      emoji = "🛍";
    }

    // تجهيز السعر مع التنسيق والعملة
    String priceText = "";
    if (model.price != null && model.price! > 0) {
      priceText = "${formatPrice(model.price!)} ${model.currency ?? ''}".trim();
    }

    // تجهيز الموقع (المدينة + الولاية إذا موجودة)
    String locationText = "";
    if (model.city != null && model.city!.isNotEmpty) {
      locationText = model.city!;
      if (model.state != null && model.state!.isNotEmpty) {
        locationText += " - ${model.state}";
      }
    }

    // صياغة الرسالة النهائية المشاركة مع إيموجي، عنوان، وصف، سعر، موقع، ورابط
    String shareMessage = """
$emoji ${model.name ?? "إعلان جديد"}

${model.description ?? "شاهد التفاصيل الآن"}

${priceText.isNotEmpty ? "💰 السعر: $priceText" : ""}
${locationText.isNotEmpty ? "📍 الموقع: $locationText" : ""}

🔗 الرابط: $deepLink
""";

    // عرض نافذة المشاركة مع أنيميشن هادئ
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // مؤشر السحب العلوي
                    Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[700] : Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // العنوان والوصف
                    Text(
                      "شارك الإعلان",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge!.color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "اختر طريقة المشاركة المفضلة لديك",
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).textTheme.bodySmall!.color,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // شبكة أيقونات المشاركة
                    GridView.count(
                      shrinkWrap: true,
                      crossAxisCount: 4,
                      childAspectRatio: 0.8,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        // واتساب
                        _buildShareTile(
                          context: context,
                          icon: FontAwesomeIcons.whatsapp,
                          label: "واتساب",
                          color: const Color(0xFF25D366),
                          onTap: () async {
                            final url = Uri.parse("https://wa.me/?text=${Uri.encodeComponent(shareMessage)}");
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url, mode: LaunchMode.externalApplication);
                            }
                          },
                        ),
                        // تيليجرام
                        _buildShareTile(
                          context: context,
                          icon: FontAwesomeIcons.telegram,
                          label: "تيليجرام",
                          color: const Color(0xFF0088CC),
                          onTap: () async {
                            final url = Uri.parse("https://t.me/share/url?url=${Uri.encodeComponent(shareMessage)}");
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url, mode: LaunchMode.externalApplication);
                            }
                          },
                        ),
                        // إنستقرام
                        _buildShareTile(
                          context: context,
                          icon: FontAwesomeIcons.instagram,
                          label: "انستقرام",
                          color: const Color(0xFFE1306C),
                          onTap: () async {
                            final url = Uri.parse("https://www.instagram.com/?url=${Uri.encodeComponent(deepLink)}");
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url, mode: LaunchMode.externalApplication);
                            }
                          },
                        ),
                        // فيسبوك
                        _buildShareTile(
                          context: context,
                          icon: FontAwesomeIcons.facebook,
                          label: "فيسبوك",
                          color: const Color(0xFF1877F2),
                          onTap: () async {
                            final url = Uri.parse("https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(deepLink)}&quote=${Uri.encodeComponent(shareMessage)}");
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url, mode: LaunchMode.externalApplication);
                            }
                          },
                        ),
                        // نسخ الرابط
                        _buildShareTile(
                          context: context,
                          icon: Icons.copy,
                          label: "نسخ",
                          color: const Color(0xFFFFA726),
                          onTap: () async {
                            await Clipboard.setData(ClipboardData(text: shareMessage));
                            Navigator.pop(context);
                            HelperUtils.showSnackBarMessage(context, "تم نسخ الرابط");
                          },
                        ),
                        // المزيد
                        _buildShareTile(
                          context: context,
                          icon: Icons.more_horiz,
                          label: "أكثر",
                          color: isDark ? Colors.grey[600]! : Colors.grey[500]!,
                          onTap: () {
                            Navigator.pop(context);
                            final box = context.findRenderObject() as RenderBox?;
                            Share.share(
                              shareMessage,
                              sharePositionOrigin: box != null
                                  ? box.localToGlobal(Offset.zero) & box.size
                                  : const Rect.fromLTWH(0, 0, 0, 0),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOut)),
            child: child,
          ),
        );
      },
    );
  }



  // ويدجت لبناء أيقونة المشاركة مع اسمها ولونها
  static Widget _buildShareTile({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              padding: const EdgeInsets.all(8), // خفف البادينج قليلاً لو تحب
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(16),
              ),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: Icon(icon, color: color, size: 44),
                ),
              ),
            ),

            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodyMedium!.color,
              ),
            ),
          ],
        ),
      ),
    );
  }




/////////////////








  static String createAdUrl(String slugOrId) {
    return "https://yourdomain.com/ad/$slugOrId";
  }



  static void copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("تم نسخ الرابط")),
    );
  }



  static String decryptString(String encryptedText) {
    try {
      final encrypter = encrypt.Encrypter(encrypt.AES(
          encrypt.Key.fromUtf8("0123456789123456"),
          mode: encrypt.AESMode.cbc));

      final encryptedValue = encrypt.Encrypted.fromBase64(encryptedText);
      final ivBytes = encrypt.IV.fromUtf8("DFGDxdfdfEREfgvC");

      final decrypted = encrypter.decrypt(encryptedValue, iv: ivBytes);

      return decrypted;
    } catch (e) {
      return encryptedText;
    }
  }








  static Future<bool> checkInternet() async {
    final r = await Connectivity().checkConnectivity();
    return r == ConnectivityResult.mobile || r == ConnectivityResult.wifi;
  }




  static String checkHost(String url) {
    if (url.endsWith("/")) {
      return url;
    } else {
      return "$url/";
    }
  }

  static Future<void> precacheSVG(List<String> urls) async {
    for (String imageUrl in urls) {
      var loader = SvgAssetLoader(imageUrl);
      await svg.cache
          .putIfAbsent(loader.cacheKey(null), () => loader.loadBytes(null));
    }
  }

  static int comparableVersion(String version) {
    //removing dot from version and parsing it into int
    String plain = version.replaceAll(".", "");

    return int.parse(plain);
  }



  static void unfocus() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  static bool checkIsUserInfoFilled({String name = "", String email = ""}) {
    String chkname = name;
    if (name.trim().isEmpty) {
      // chkname = Constant.session.getStringData(Session.keyUserName);
    }
    return chkname.trim().isNotEmpty;
  }

  static String mobileNumberWithoutCountryCode() {
    String? mobile = HiveUtils.getUserDetails().mobile;

    String? countryCode = HiveUtils.getCountryCode();

    int countryCodeLength = (countryCode?.length ?? 0);

    String mobileNumber = mobile!.substring(countryCodeLength, mobile.length);

    return mobileNumber;
  }




  static showSnackBarMessage(
      BuildContext? context,
      String message, {
        int messageDuration = 3,
        MessageType? type,
        bool? isFloating,
        VoidCallback? onClose,
      }) {
    if (context == null) return;

    final overlay = Overlay.of(context);

    if (overlay == null) {
      return;
    }

    final theme = Theme.of(context);

    for (var i = 0; i < _activeSoftSnackbars.length; i++) {
      _activeSoftSnackbars[i].demote(i + 1);
    }

    final ValueNotifier<double> offsetNotifier = ValueNotifier<double>(80.0);
    final ValueNotifier<double> focusNotifier = ValueNotifier<double>(0.9);

    late OverlayEntry entry;

    late final _SoftSnackBarController controller;
    bool removed = false;

    void handleFinish() {
      if (removed) return;
      removed = true;

      final int index = _activeSoftSnackbars.indexOf(controller);
      if (index != -1) {
        _activeSoftSnackbars.removeAt(index);
      }

      entry.remove();
      controller.dispose();

      _reindexActiveSoftSnackbars();

      onClose?.call();
    }

    final widget = _SoftSnackBarWidget(
      message: message,
      iconPath: 'assets/image/showSoftSnackBar.png',
      duration: Duration(seconds: messageDuration),
      backgroundColor: type?.value ??
          (theme.brightness == Brightness.dark
              ? Colors.grey[800]
              : Colors.grey[900])!,

      textColor: Colors.white,
      fontSize: 15,
      fontWeight: FontWeight.w500,
      offsetListenable: offsetNotifier,
      focusOpacityListenable: focusNotifier,
      onFinish: handleFinish,
    );

    entry = OverlayEntry(builder: (_) => widget);

    controller = _SoftSnackBarController(
      entry: entry,
      offsetNotifier: offsetNotifier,
      focusNotifier: focusNotifier,
    );

    _activeSoftSnackbars.insert(0, controller);

    _reindexActiveSoftSnackbars();

    overlay.insert(entry);
  }

  static bool isConnectivityOrServerError(dynamic error) {
    if (error == null) return false;

    final message = error.toString().toLowerCase();
    if (message.isEmpty) return false;

    return message.contains('no-internet') ||
        message.contains('no internet') ||
        message.contains('internet connection') ||
        message.contains('server-not-available') ||
        message.contains('server not available') ||
        message.contains('socketexception') ||
        message.contains('timed out') ||
        message.contains('timeout');
  }


  static bool isPackageLimitError(dynamic error) {
    if (error == null) return false;

    final message = error.toString().toLowerCase();
    if (message.isEmpty) return false;

    const directMatches = <String>[
      'no package',
      'no-package',
      'without package',
      'package not available',
      'package_not_available',
      'package not assigned',
      'package_not_assigned',
      'package not valid',
      'package_not_valid',
      'package not for item',
      'package_not_for_item',
      'package not allowed',
      'package_not_allowed',
      'package inactive',
      'package is inactive',
      'package expired',
      'package is expired',
      'package plan required',
      'package purchase required',
      'package required',
      'package limit',
      'limit of package',
      'limit-exhausted',
      'limit exhausted',
      'limit-exceeded',
      'limit exceeded',
      'limit reached',
      'limit has been reached',
      'quota exhausted',
      'quota-exhausted',
      'no quota',
      'no-quota',
      'no credits',
      'credit exhausted',
      'subscription expired',
      'plan expired',
      'please subscribe to any packages',
      'please subscribe to package',
      'subscribe to any packages',
      'subscribe to package',
    ];

    if (directMatches.any(message.contains)) {
      return true;
    }

    if (message.contains('package')) {
      final relatedTokens = <String>[
        'limit',
        'quota',
        'subscribe',
        'subscription',
        'expired',
        'inactive',
        'not active',
        'not valid',
        'not available',
        'not assigned',
        'not for item',
        'not allowed',
        'no ',
        'without',
        'purchase',
        'buy',
      ];

      return relatedTokens.any(message.contains);
    }

    return false;
  }

  static String readableErrorMessage(BuildContext context, dynamic error) {
    final rawMessage = (error ?? '').toString().trim();
    if (rawMessage.isEmpty) {
      return 'somethingWentWrong'.translate(context);
    }

    final normalized = rawMessage.toLowerCase();
    if (normalized == 'somethingwentwrong' ||
        normalized == 'something went wrong') {
      return 'somethingWentWrong'.translate(context);
    }

    final hasWhitespace = rawMessage.contains(RegExp(r'\s'));

    if (!hasWhitespace) {
      final translated = rawMessage.translate(context);
      if (translated != rawMessage) {
        return translated;
      }
    }

    final humanized = rawMessage
        .replaceAll(RegExp(r'[_]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (!hasWhitespace && humanized != rawMessage && humanized.isNotEmpty) {
      return humanized[0].toUpperCase() + humanized.substring(1);
    }

    return rawMessage;
  }




  static Future<String> getJsonResponse(BuildContext context,
      {bool isfromfile = false,
        StreamedResponse? streamedResponse,
        Response? response}) async {
    int code;
    if (isfromfile) {
      code = streamedResponse!.statusCode;
    } else {
      code = response!.statusCode;
    }
    switch (code) {
      case 200:
        if (isfromfile) {
          var responseData = await streamedResponse!.stream.toBytes();
          return String.fromCharCodes(responseData);
        } else {
          return response!.body;
        }

      case 400:
        throw BadRequestException(response!.body.toString());
      case 401:
        Map getdata = {};
        if (isfromfile) {
          var responseData = await streamedResponse!.stream.toBytes();
          getdata = json.decode(String.fromCharCodes(responseData));
        } else {
          getdata = json.decode(response!.body);
        }

        Future.delayed(
          Duration.zero,
              () {
            showSnackBarMessage(context, getdata[Api.message]);
          },
        );
        throw UnauthorisedException(getdata[Api.message]);
      case 403:
        throw UnauthorisedException(response!.body.toString());
      case 500:
      default:
        throw FetchDataException(
            'Error occurred while Communication with Server with StatusCode: $code');
    }
  }




  static String getFileSizeString({required int bytes, int decimals = 0}) {
    const suffixes = ["b", "kb", "mb", "gb", "tb"];
    if (bytes == 0) return '0${suffixes[0]}';
    var i = (log(bytes) / log(1024)).floor();
    return ((bytes / pow(1024, i)).toStringAsFixed(decimals)) + suffixes[i];
  }

  static killPreviousPages(BuildContext context, var nextpage, var args) {
    Navigator.of(context)
        .pushNamedAndRemoveUntil(nextpage, (route) => false, arguments: args);
  }

  static goToNextPage(var nextpage, BuildContext bcontext, bool isreplace,
      {Map? args}) {
    if (isreplace) {
      Navigator.of(bcontext).pushReplacementNamed(nextpage, arguments: args);
    } else {
      Navigator.of(bcontext).pushNamed(nextpage, arguments: args);
    }
  }

  static String setFirstLetterUppercase(String value) {
    if (value.isNotEmpty) value = value.replaceAll("_", ' ');
    return value.toTitleCase();
  }

  static Widget checkVideoType(String url,
      {required Widget Function() onYoutubeVideo,
        required Widget Function() onOtherVideo}) {
    List youtubeDomains = ["youtu.be", "youtube.com"];

    Uri uri = Uri.parse(url);
    var host = uri.host.toString().replaceAll("www.", "");
    if (youtubeDomains.contains(host)) {
      return onYoutubeVideo.call();
    } else {
      return onOtherVideo.call();
    }
  }



  static bool isYoutubeVideo(String url) {
    List youtubeDomains = ["youtu.be", "youtube.com"];

    Uri uri = Uri.parse(url);
    var host = uri.host.toString().replaceAll("www.", "");
    if (youtubeDomains.contains(host)) {
      return true;
    } else {
      return false;
    }
  }

/*
  static Future<File?> compressImageFile(File file) async {
    try {
      //final compressedFile = await FlutterNativeImage.compressImage(file.path,quality: Constant.imgQuality,targetWidth: Constant.maxImgWidth,targetHeight: Constant.maxImgHeight);
      final compressedFile = await FlutterNativeImage.compressImage(
        file.path,
        quality: Constant.uploadImageQuality,
      );
      return File(compressedFile.path);
    } catch (e) {
      return null; //If any error occurs during compression, the process is stopped.
    }
  }
*/

  static Future<File> compressImageFile(File file) async {
    try {
      final int fileSize = await file.length();

      if (fileSize <= Constant.maxSizeInBytes) {
        // No need to compress if already within size limit
        return file;
      }

      final filePath = file.absolute.path;
      final lastIndex = filePath.lastIndexOf(RegExp(r'.png|.jp'));
      final splitted = filePath.substring(0, (lastIndex));
      final outPath = "${splitted}_out${filePath.substring(lastIndex)}";

      XFile? result = await FlutterImageCompress.compressAndGetFile(
        filePath,
        outPath,
        quality: Constant.uploadImageQuality,
      );

      return File(result!.path);
    } catch (e) {
      throw Exception("Error compressing image: $e");
    }
  }

  static void launchPathURL({
    required bool isTelephone,
    required bool isSMS,
    required bool isMail,
    required String value,
    required BuildContext context,
  }) async {
    late Uri redirectUri;

    if (isTelephone) {
      redirectUri = Uri.parse("tel:$value");
    } else if (isMail) {
      redirectUri = Uri(
        scheme: 'mailto',
        path: value,
        query:
        'subject=${Constant.appName}&body=${"mailMsgLbl".translate(context)}',
      );
    } else {
      redirectUri = Uri.parse("sms:$value");
    }

    if (await canLaunchUrl(redirectUri)) {
      await launchUrl(redirectUri);
    } else {
      throw 'Could not launch $redirectUri';
    }
  }
}


class _SoftSnackBarController {
  _SoftSnackBarController({
    required this.entry,
    required this.offsetNotifier,
    required this.focusNotifier,
  });

  final OverlayEntry entry;
  final ValueNotifier<double> offsetNotifier;
  final ValueNotifier<double> focusNotifier;

  void promote() {
    offsetNotifier.value = 80.0;
    focusNotifier.value = 0.9;
  }

  void demote(int index) {
    offsetNotifier.value = (80 + index * 64).toDouble();
    focusNotifier.value = 0.6;
  }

  void dispose() {
    offsetNotifier.dispose();
    focusNotifier.dispose();
  }
}


class _SoftSnackBarWidget extends StatefulWidget {
  final String message;
  final String iconPath;
  final Duration duration;
  final Color backgroundColor;
  final Color textColor;
  final double fontSize;
  final FontWeight fontWeight;
  final VoidCallback onFinish;
  final ValueListenable<double> offsetListenable;
  final ValueListenable<double> focusOpacityListenable;


  const _SoftSnackBarWidget({
    required this.message,
    required this.iconPath,
    required this.duration,
    required this.backgroundColor,
    required this.textColor,
    required this.fontSize,
    required this.fontWeight,
    required this.onFinish,
    required this.offsetListenable,
    required this.focusOpacityListenable,
  });

  @override
  State<_SoftSnackBarWidget> createState() => _SoftSnackBarWidgetState();
}

class _SoftSnackBarWidgetState extends State<_SoftSnackBarWidget>
    with SingleTickerProviderStateMixin {
  double opacity = 0.0;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) setState(() => opacity = 1);
    });
    Future.delayed(widget.duration, () {
      if (mounted) {
        setState(() => opacity = 0);
        Future.delayed(const Duration(milliseconds: 300), widget.onFinish);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 80,
      left: 0,
      right: 0,
        child: ValueListenableBuilder<double>(
            valueListenable: widget.offsetListenable,
            builder: (BuildContext context, double offset, Widget? child) {
              return AnimatedPadding(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.only(bottom: offset),
                child: child,
              );
            },
            child: Center(
                child: ValueListenableBuilder<double>(
                    valueListenable: widget.focusOpacityListenable,
                    builder: (BuildContext context, double focusOpacity, Widget? child) {
                      final double clampedFocus =
                      focusOpacity.clamp(0.0, 1.0).toDouble();
                      final double combinedOpacity =
                      (opacity * clampedFocus).clamp(0.0, 1.0).toDouble();
                      final double slideOffset = opacity == 1
                          ? (1 - clampedFocus) * 0.05
                          : 0.1;
                      final Color background =
                      widget.backgroundColor.withOpacity(clampedFocus);
                      final Color textColor =
                      widget.textColor.withOpacity(clampedFocus);

                      return AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        opacity: combinedOpacity,
                        child: AnimatedSlide(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          offset: Offset(0, slideOffset),
                          child: Material(
                            color: Colors.transparent,
                            child: IntrinsicWidth(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: background,
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(100),
                                      child: Image.asset(
                                        widget.iconPath,
                                        width: 30,
                                        height: 30,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Flexible(
                                      child: Text(
                                        widget.message,
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: widget.fontSize,
                                          fontWeight: widget.fontWeight,
                                        ),
                                        textAlign: TextAlign.start,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                        ),

                      ),
                    ),
                 ),
                ),
               );
            },
          ),
        ),
      ),
    );
  }
}

