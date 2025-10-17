import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:shimmer/shimmer.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/utils/responsiveSize.dart';

import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/ui_utils.dart';
import 'dart:ui' as ui;







import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';

// أدوات وامتدادات مشروعك (نفس المستخدمة في صفحاتك)
import 'package:marib/utils/ui_utils.dart'; // UiUtils + HelperUtils
import 'package:marib/utils/extensions/extensions.dart';    // ألوان وخطوط
import 'package:marib/utils/responsiveSize.dart';           // .rh و .rw للأحجام المتجاوبة







class PaymentStandalonePage extends StatefulWidget {
  // إجمالي المبلغ (اختياري للعرض فقط في الشريط السفلي)
  final double? amount;

  const PaymentStandalonePage({super.key, this.amount});

  static Route<bool> route({double? amount}) =>
      MaterialPageRoute(builder: (_) => PaymentStandalonePage(amount: amount));

  @override
  State<PaymentStandalonePage> createState() => _PaymentStandalonePageState();
}

class _PaymentStandalonePageState extends State<PaymentStandalonePage> {
  // مؤشر الوسيلة المختارة (مطابق لمنطقك الأصلي)
  int? selectedBankIndex;
  String? selectedPaymentMethod;

  // حالة تحميل للشريط السفلي (shimmer)
  bool _loading = false;

  // تفعيل زر الإكمال: في الشاشة المستقلة نكتفي باختيار وسيلة الدفع
  bool get isButtonEnabled => selectedBankIndex != null;

  // قائمة الوسائل مطابقة لصفحتك الأصلية (الأسماء + الشعارات + الحسابات عند الحاجة)
  final List<Map<String, String>> banks = const [
    {
      "name": "الدفع بواسطة بنك الشرق اليمني",
      "logo": "assets/svg/Logo/بنك الشرق اليمني.png",
      "accountName": "",
      "accountNumber": "100101",
    },
    {
      "name": "نقطة إيزي كاش",
      "logo": "assets/svg/Logo/نقطة إيزي كاش.png",
      "accountName": "",
      "accountNumber": "712226666",
    },
    {
      "name": "بنك التضامن الاسلامي",
      "logo": "assets/svg/Logo/بنك التضامن الاسلامي.png",
      "accountName": "00109215",
      "accountNumber": "00109215",
    },
    {
      "name": "محفظتي - بنك التضامن",
      "logo": "assets/svg/Logo/محفظتي - بنك التضامن.png",
      "accountName": "00109215",
      "accountNumber": "00109215",
    },
    {
      "name": "بنك الكريمي",
      "logo": "assets/svg/Logo/بنك الكريمي.png",
      "accountName": "25209709",
      "accountNumber": "25209709",
    },
    {
      "name": "شركة صدام إكسبرس",
      "logo": "assets/svg/Logo/شركة صدام إكسبرس.png",
      "accountName": "2313991",
      "accountNumber": "2313991",
    },
    {
      "name": "الشبكة ( الحولات الداخلية )",
      "logo": "assets/svg/Logo/الشبكة.png",
      "accountName": "مأرب بين يديك للخدمات الإلكترونية",
      "accountNumber": "مأرب بين يديك للخدمات الألكترونية",
    },
  ];

  @override
  Widget build(BuildContext context) {
    // قيم متجاوبة حسب الشاشة
    final media = MediaQuery.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final horizontal = (16.0).rw(context).clamp(12.0, 24.0);
    final vertical = (16.0).rh(context).clamp(12.0, 24.0);
    final radius = (12.0).rw(context).clamp(10.0, 16.0);

    return AnnotatedRegion(
      value: UiUtils.getSystemUiOverlayStyle(
        context: context,
        statusBarColor: context.color.secondaryColor,
      ),
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF0F2F4),
        appBar: UiUtils.buildAppBar(
          context,
          title: "بيانات التوصيل والدفع",
          bottomHeight: 20,
          showBackButton: true,
        ),
        // الشريط السفلي (مطابق بصريًا)
        bottomNavigationBar: buildBottomCheckoutBar(
          context,
          (widget.amount ?? 0),
          "—",                   // رسوم التوصيل كنص (مطابق لحالة عدم التحديد)
          _onConfirmPayment,      // متابعة الإكمال
          isButtonEnabled,        // تفعيل/تعطيل الزر
          _loading,               // shimmer
          radius: radius,
          horizontal: horizontal,
          vertical: vertical,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(horizontal, vertical, horizontal, (media.viewPadding.bottom + 1).clamp(8.0, 24.0)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSection(
                  context,
                  title: "الدفع",
                  leading: const Icon(Icons.payment), // مرن: يمكن استبداله بـ SvgPicture.asset
                  initiallyExpanded: true,
                  child: buildBank(context, radius: radius),
                  radius: radius,
                ),
                SizedBox(height: (6.0).rh(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ====== قسم "الدفع" (مطابق بصريًا + متجاوب) ======
  Widget buildBank(BuildContext context, {required double radius}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color secondaryColor = const Color(0xFFFF8000); // برتقالي
    final Color accentColor = const Color(0xFFE0E0E0);     // رمادي فاتح
    final Color lightBackground = isDark ? Colors.grey.shade800 : const Color(0xFFF9F9F9);
    final Color textColor = isDark ? Colors.white : const Color(0xFF222222);
    final Color backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final Color borderColor = isDark ? Colors.grey.shade600 : accentColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(banks.length, (index) {
        final bank = banks[index];
        final isSelected = selectedBankIndex == index;

        return Padding(
          padding: EdgeInsets.symmetric(vertical: (6.0).rh(context)),
          child: Material(
            color: isSelected ? lightBackground : backgroundColor,
            borderRadius: BorderRadius.circular(radius),
            child: InkWell(
              borderRadius: BorderRadius.circular(radius),
              onTap: () {
                setState(() {
                  selectedBankIndex = index;
                  selectedPaymentMethod = bank["name"];
                });
              },
              child: Container(
                padding: EdgeInsets.all((12.0).rw(context)),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isSelected ? secondaryColor : borderColor,
                    width: (1.4).rw(context),
                  ),
                  borderRadius: BorderRadius.circular(radius),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // شعار الوسيلة (صورة من الأصول)
                    ClipRRect(
                      borderRadius: BorderRadius.circular((10.0).rw(context)),
                      child: Image.asset(
                        bank["logo"]!,
                        width: (45.0).rw(context).clamp(34.0, 52.0),
                        height: (45.0).rw(context).clamp(34.0, 52.0),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.account_balance_wallet),
                      ),
                    ),
                    SizedBox(width: (12.0).rw(context)),

                    // الاسم + زر نسخ رقم/اسم الحساب إن وُجد
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bank["name"]!,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: Theme.of(context).textTheme.titleSmall?.fontSize ?? 15,
                              color: textColor,
                            ),
                          ),
                          SizedBox(height: (8.0).rh(context)),
                          if ((bank["accountName"] ?? "").isNotEmpty)
                            Material(
                              color: accentColor.withOpacity(isDark ? 0.1 : 0.5),
                              borderRadius: BorderRadius.circular((8.0).rw(context)),
                              child: InkWell(
                                borderRadius: BorderRadius.circular((8.0).rw(context)),
                                onTap: () {
                                  setState(() {
                                    selectedBankIndex = index;
                                    selectedPaymentMethod = bank["name"];
                                  });
                                  // نسخ رقم/اسم الحساب + تنبيه مخصص
                                  Clipboard.setData(ClipboardData(text: bank["accountName"]!));
                                  HelperUtils.showSnackBarMessage(context, "تم نسخ رقم الحساب");
                                },
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: (12.0).rw(context),
                                    vertical: (8.0).rh(context),
                                  ),
                                  child: Text(
                                    bank["accountName"]!,
                                    style: TextStyle(
                                      fontSize: Theme.of(context).textTheme.bodyMedium?.fontSize ?? 14,
                                      color: textColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    if (isSelected)
                      Icon(Icons.check_circle, color: const Color(0xFFFF8000), size: (20.0).rw(context).clamp(18.0, 22.0)),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  // ====== حوار كود الشراء (مطابق بصريًا + تنبيهات مخصصة) ======
  Future<void> _showPurchaseCodeDialog({required VoidCallback onConfirm}) async {
    final TextEditingController codeController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final fieldColor = isDark ? Colors.grey.shade800 : const Color(0xFFF5F5F5);
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular((16.0).rw(context))),
          backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
          title: const Text("🧾 كود الشراء"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: codeController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "رمز الشراء *",
                  filled: true,
                  fillColor: fieldColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular((10.0).rw(context))),
                ),
              ),
              SizedBox(height: (8.0).rh(context)),
              const Text("أدخل رمز الشراء الذي حصلت عليه لإتمام العملية", style: TextStyle(fontSize: 12)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("إلغاء")),
            FilledButton(
              onPressed: () {
                if (codeController.text.trim().isEmpty) {
                  HelperUtils.showSnackBarMessage(context, "يرجى إدخال كود الشراء");
                  return;
                }
                Navigator.pop(ctx);
                onConfirm();
              },
              child: const Text("تأكيد"),
            ),
          ],
        );
      },
    );
  }

  // ====== حوار الحوالة المصرفية (مطابق بصريًا + متجاوب + تنبيهات مخصصة) ======
  Future<void> _showBankTransferDialog({
    required String paymentMethodName,
    required String accountName,
    required String accountNumber,
    required VoidCallback onConfirm,
  }) async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController transferCodeController = TextEditingController();
    final ValueNotifier<bool> isUploading = ValueNotifier(false);
    final ValueNotifier<File?> receiptImage = ValueNotifier(null);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color fieldColor = isDark ? Colors.grey.shade800 : const Color(0xFFF5F5F5);
    final Color mainColor = const Color(0xFFFF8000);

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular((16.0).rw(context))),
          backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
          title: const Text("💳 الدفع عن طريق حوالة مصرفية"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // اسم الوسيلة
                Text(paymentMethodName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: mainColor)),
                SizedBox(height: (6.0).rh(context)),

                // رقم الحساب مع النسخ
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: accountNumber));
                    HelperUtils.showSnackBarMessage(context, "✅ تم نسخ رقم الحساب");
                  },
                  borderRadius: BorderRadius.circular((10.0).rw(context)),
                  child: Container(
                    padding: EdgeInsets.all((10.0).rw(context)),
                    margin: EdgeInsets.only(bottom: (16.0).rh(context)),
                    decoration: BoxDecoration(color: fieldColor, borderRadius: BorderRadius.circular((10.0).rw(context))),
                    child: Text(accountNumber, style: const TextStyle(fontSize: 14)),
                  ),
                ),

                // الاسم
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: "الاسم *",
                    filled: true,
                    fillColor: fieldColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular((10.0).rw(context))),
                  ),
                ),
                SizedBox(height: (12.0).rh(context)),

                // رقم الحوالة
                TextField(
                  controller: transferCodeController,
                  decoration: InputDecoration(
                    labelText: "رقم الحوالة *",
                    filled: true,
                    fillColor: fieldColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular((10.0).rw(context))),
                  ),
                ),
                SizedBox(height: (16.0).rh(context)),

                // رفع صورة الإشعار (اختياري)
                ValueListenableBuilder<File?>(
                  valueListenable: receiptImage,
                  builder: (_, file, __) {
                    return Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: mainColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular((10.0).rw(context)),
                              ),
                            ),
                            onPressed: () async {
                              final picker = ImagePicker();
                              final XFile? picked = await picker.pickImage(source: ImageSource.gallery);
                              if (picked != null) {
                                isUploading.value = true;
                                // هنا يمكن رفع الصورة لسيرفرك، ثم:
                                await Future.delayed(const Duration(milliseconds: 750));
                                receiptImage.value = File(picked.path);
                                isUploading.value = false;
                                HelperUtils.showSnackBarMessage(context, "تم إرفاق صورة الإيصال");
                              }
                            },
                            icon: const Icon(Icons.attachment),
                            label: const Text("إرفاق صورة الإيصال"),
                          ),
                        ),
                        SizedBox(width: (8.0).rw(context)),
                        ValueListenableBuilder<bool>(
                          valueListenable: isUploading,
                          builder: (_, uploading, __) {
                            if (uploading) {
                              return const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2));
                            }
                            if (file != null) {
                              return const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [Icon(Icons.check_circle, color: Colors.green, size: 20), SizedBox(width: 4), Text("مرفق", style: TextStyle(fontSize: 12, color: Colors.green))],
                              );
                            }
                            return const Text("لم يتم الإرفاق", style: TextStyle(color: Colors.grey));
                          },
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("إلغاء")),
            FilledButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) {
                  HelperUtils.showSnackBarMessage(context, "يرجى إدخال الاسم");
                  return;
                }
                if (transferCodeController.text.trim().isEmpty) {
                  HelperUtils.showSnackBarMessage(context, "يرجى إدخال رقم الحوالة");
                  return;
                }
                Navigator.pop(ctx);
                onConfirm();
              },
              child: const Text("تأكيد"),
            ),
          ],
        );
      },
    );
  }

  // ====== شريط أسفل الشاشة (ملخص + زر) — مطابق بصريًا ومتجاوب ======
  Widget buildBottomCheckoutBar(
      BuildContext context,
      double subtotal,
      String deliveryFee,
      VoidCallback? onConfirm,
      bool isButtonEnabled,
      bool loading, {
        required double radius,
        required double horizontal,
        required double vertical,
      }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final highlightColor = isDark ? Colors.grey.shade600 : Colors.grey.shade100;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: (10.0).rh(context),
        left: horizontal,
        right: horizontal,
        bottom: (vertical + 8.0).clamp(16.0, 32.0),
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.4),
        borderRadius: BorderRadius.vertical(top: Radius.circular((18.0).rw(context))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          loading
              ? Shimmer.fromColors(
            baseColor: baseColor,
            highlightColor: highlightColor,
            child: Container(
              width: double.infinity,
              height: (90.0).rh(context).clamp(70.0, 110.0),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Colors.white,
                borderRadius: BorderRadius.circular((10.0).rw(context)),
              ),
            ),
          )
              : Container(
            padding: EdgeInsets.symmetric(horizontal: (12.0).rw(context), vertical: (10.0).rh(context)),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade900 : Colors.white,
              borderRadius: BorderRadius.circular((10.0).rw(context)),
              border: Border.all(
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                width: (1.0).rw(context),
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
                  blurRadius: (6.0).rw(context),
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildPriceRow("💰 المبلغ الإجمالي", "للتاجر", "${subtotal.toStringAsFixed(0)}", context, loading),
                SizedBox(height: (8.0).rh(context)),
                _buildPriceRow("🚚 رسوم التوصيل", "للسائق عند الاستلام", deliveryFee, context, loading),
              ],
            ),
          ),
          SizedBox(height: (16.0).rh(context)),
          Center(
            child: UiUtils.buildButton(
              context,
              onPressed: () {
                if (!isButtonEnabled) return; // نفس شرط التفعيل

                if (selectedPaymentMethod == "الدفع بواسطة بنك الشرق اليمني") {
                  _showPurchaseCodeDialog(onConfirm: onConfirm ?? () {});
                } else {
                  // استخراج بيانات الوسيلة المختارة لتمريرها للحوار
                  final selectedBank = banks.firstWhere(
                        (b) => b['name'] == selectedPaymentMethod,
                    orElse: () => const {},
                  );

                  if (selectedBank.isNotEmpty) {
                    _showBankTransferDialog(
                      paymentMethodName: selectedBank["name"] ?? "",
                      accountName: selectedBank["accountName"] ?? "",
                      accountNumber: selectedBank["accountNumber"] ?? "",
                      onConfirm: onConfirm ?? () {},
                    );
                  } else {
                    onConfirm?.call();
                  }
                }
              },
              buttonTitle: "إكمال الدفع",
              radius: radius,
              width: (380.0).rw(context).clamp(240.0, 480.0),
              height: (56.0).rh(context).clamp(44.0, 64.0),
            ),
          ),
        ],
      ),
    );
  }

  // ====== عناصر مساعدة "مطابقة" ======
  Widget _buildSection(
      BuildContext context, {
        required String title,
        required Widget leading, // مرونة (Icon أو Svg)
        required Widget child,
        bool initiallyExpanded = false,
        required double radius,
      }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F4F6),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: (6.0).rw(context),
              offset: const Offset(0, 5),
            ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: EdgeInsets.symmetric(horizontal: (16.0).rw(context)),
          title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          leading: leading,
          childrenPadding: EdgeInsets.symmetric(horizontal: (16.0).rw(context), vertical: (10.0).rh(context)),
          children: [child],
        ),
      ),
    );
  }

  Widget _buildPriceRow(String title, String note, String value, BuildContext context, bool loading) {
    final titleStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold);
    final noteStyle = Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600);
    final valueStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Text(title, style: titleStyle),
              SizedBox(width: (4.0).rw(context)),
              Text(note, style: noteStyle),
            ],
          ),
        ),
        loading
            ? _buildShimmerLine(context, width: (60.0).rw(context), height: (14.0).rh(context))
            : Text(value, style: valueStyle),
      ],
    );
  }

  Widget _buildShimmerLine(BuildContext context, {double height = 12, double width = 120}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
      highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
          borderRadius: BorderRadius.circular((8.0).rw(context)),
        ),
      ),
    );
  }

  // ====== إنهاء العملية — يرجع true للمستدعي ======
  void _finishPayment() {
    Navigator.of(context).maybePop(true);
    HelperUtils.showSnackBarMessage(context, "تم تسجيل بيانات الدفع بنجاح");
  }

  // يستدعي الحوارات حسب الوسيلة المختارة ثم ينهي العملية
  void _onConfirmPayment() {
    if (!isButtonEnabled) return;

    if (selectedPaymentMethod == "الدفع بواسطة بنك الشرق اليمني") {
      _showPurchaseCodeDialog(onConfirm: _finishPayment);
    } else {
      final selectedBank = banks.firstWhere(
            (bank) => bank['name'] == selectedPaymentMethod,
        orElse: () => const {},
      );

      if (selectedBank.isNotEmpty) {
        _showBankTransferDialog(
          paymentMethodName: selectedBank["name"] ?? "",
          accountName: selectedBank["accountName"] ?? "",
          accountNumber: selectedBank["accountNumber"] ?? "",
          onConfirm: _finishPayment,
        );
      } else {
        _finishPayment();
      }
    }
  }
}



//          child: Padding(
//           padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
//           child: UiUtils.buildButton(
//             context,
//             onPressed: () {
//               Navigator.pushNamed(
//                 context,
//                 Routes.addItemDetails,
//                 arguments: <String, dynamic>{
//                   "breadCrumbItems": [category],
//                   "isEdit": false,
//                 },
//               );
//             },
//             buttonTitle: "createServiceContinue".translate(context),
//             radius: 12,
//             height: 54,
//             buttonColor: context.color.territoryColor,
//             textColor: Colors.white,
//           ),
//         ),