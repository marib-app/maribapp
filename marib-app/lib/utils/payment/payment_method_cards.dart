import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ألوان مطابقة
const Color _secondaryColor = Color(0xFFFF8000); // برتقالي
const Color _accentColor = Color(0xFFE0E0E0); // رمادي فاتح

/// نموذج بسيط للبنوك (نفس المفاتيح المستخدمة في الواجهة الأصلية)
class BankInfo {
  final String name; // الاسم الظاهر
  final String logo; // مسار الأيقونة/الشعار
  final String? accountName; // رقم الحساب أو الاسم القابل للنسخ (اختياري)
  final String? phone; // رقم هاتف (اختياري)
  final String? amount; // مبلغ/وصف إضافي (اختياري)

  const BankInfo({
    required this.name,
    required this.logo,
    this.accountName,
    this.phone,
    this.amount,
  });
}

/// قائمة افتراضية مطابقة للأصل قدر الإمكان (عدّل أو مرّر قائمتك)
const List<BankInfo> kDefaultBanks = [
  BankInfo(
    name: "الدفع بواسطة بنك الشرق اليمني",
    logo: "assets/svg/Logo/بنك الشرق اليمني.png",
  ),
  BankInfo(
    name: "نقطة إيزي كاش",
    accountName: "482409949",
    logo: "assets/svg/Logo/نقطة إيزي كاش.png",
  ),
  BankInfo(
    name: "بنك التضامن الاسلامي",
    accountName: "00109215",
    logo: "assets/svg/Logo/بنك التضامن الاسلامي.png",
  ),
  // ... يمكنك استكمال بقية البنوك بنفس النمط
  BankInfo(
    name: "بنك الكريمي",
    accountName: "25209709",
    logo: "assets/svg/Logo/بنك الكريمي.png",
  ),
  BankInfo(
    name: "شركة صدام إكسبرس",
    accountName: "2313991",
    logo: "assets/svg/Logo/شركة صدام إكسبرس.png",
  ),
  BankInfo(
    name: "الشبكة ( الحولات الداخلية )",
    accountName: "حوالة ب اسم / مأرب بين يديك للخدمات الإلكترونية",
    logo: "assets/svg/Logo/الشبكة.png",
  ),
];

/// ويدجت قائمة بطاقات الدفع (UI فقط)
class PaymentMethodsSection extends StatefulWidget {
  final List<BankInfo> banks;

  /// حدث اختيار بنك
  final ValueChanged<BankInfo>? onSelect; // TODO: اربط الاختيار بمنطقك

  const PaymentMethodsSection({
    Key? key,
    this.banks = kDefaultBanks,
    this.onSelect,
  }) : super(key: key);

  @override
  State<PaymentMethodsSection> createState() => _PaymentMethodsSectionState();
}

class _PaymentMethodsSectionState extends State<PaymentMethodsSection> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color lightBackground =
        isDark ? Colors.grey.shade800 : const Color(0xFFF9F9F9);
    final Color textColor = isDark ? Colors.white : const Color(0xFF222222);
    final Color backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final Color borderColor = isDark ? Colors.grey.shade600 : _accentColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(widget.banks.length, (index) {
        final bank = widget.banks[index];
        final isSelected = _selectedIndex == index;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Material(
            color: isSelected ? lightBackground : backgroundColor,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                setState(() => _selectedIndex = index);
                widget.onSelect?.call(bank); // TODO: اربط الاختيار بمنطقك
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isSelected ? _secondaryColor : borderColor,
                    width: 1.4,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        bank.logo, // تأكد من وجود الأصل داخل مشروعك
                        width: 45,
                        height: 45,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bank.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // شريحة قابلة للنقر لنسخ رقم/اسم الحساب إن وُجد
                          if (bank.accountName != null &&
                              bank.accountName!.trim().isNotEmpty)
                            Material(
                              color:
                                  _accentColor.withOpacity(isDark ? 0.1 : 0.5),
                              borderRadius: BorderRadius.circular(8),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () {
                                  // TODO: يمكنك إبقاء النسخ أو إزالته حسب رغبتك
                                  Clipboard.setData(
                                      ClipboardData(text: bank.accountName!));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("✅ تم نسخ رقم الحساب"),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                  setState(() => _selectedIndex = index);
                                  widget.onSelect
                                      ?.call(bank); // TODO: ربط إضافي عند النسخ
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  child: Text(
                                    bank.accountName!,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: textColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                          const SizedBox(height: 4),
                          if (bank.phone != null)
                            SelectableText(
                              "📞 ${bank.phone!}",
                              style: TextStyle(fontSize: 13, color: textColor),
                            ),
                          if (bank.amount != null)
                            SelectableText(
                              "💰 ${bank.amount!}",
                              style: TextStyle(fontSize: 13, color: textColor),
                            ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      const Icon(Icons.check_circle, color: _secondaryColor),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// نافذة إدخال "كود الشراء" لبنك الشرق (UI فقط)

Future<String?> showPurchaseCodeDialog(BuildContext context,
    {VoidCallback? onShowGuide}) async {
  final result = await showDialog<String?>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      return _PurchaseCodeDialog(
        onShowGuide: onShowGuide,
      );
    },
  );
  return result?.trim();
}

class _PurchaseCodeDialog extends StatefulWidget {
  const _PurchaseCodeDialog({this.onShowGuide});

  final VoidCallback? onShowGuide;

  @override
  State<_PurchaseCodeDialog> createState() => _PurchaseCodeDialogState();
}

class _PurchaseCodeDialogState extends State<_PurchaseCodeDialog> {
  late final TextEditingController _codeController;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  bool get _hasValue => _codeController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
      titlePadding: const EdgeInsetsDirectional.fromSTEB(20, 20, 12, 0),
      contentPadding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 4),
      actionsPadding: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 12),
      title: Row(
        children: [
          const Expanded(
            child: Text(
              '🧾 كود الشراء',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          if (widget.onShowGuide != null)
            IconButton(
              tooltip: 'عرض تعليمات الدفع',
              onPressed: widget.onShowGuide,
              icon: Icon(
                Icons.priority_high_rounded,
                color: isDark ? Colors.orange.shade200 : _secondaryColor,
              ),
            ),
        ],
      ),
      content: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: bottomInset > 0 ? bottomInset : 0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'يرجى إدخال كود الشراء المرسل من البنك لإتمام العملية.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _codeController,
                autofocus: true,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: 'أدخل كود الشراء المكوّن من الأرقام',
                  filled: true,
                  fillColor:
                      isDark ? Colors.grey.shade800 : const Color(0xFFF3F3F3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: _secondaryColor,
                      width: 1.6,
                    ),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '🔒 يتم مراجعة الكود من قبل النظام قبل إتمام الطلب.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _secondaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _hasValue
              ? () => Navigator.of(context).pop(_codeController.text.trim())
              : null,
          child: const Text('تأكيد'),
        ),
      ],
    );
  }
}

/// مثال استعمال بسيط داخل شاشة (اختياري للمعاينة)
class PaymentUIExample extends StatelessWidget {
  const PaymentUIExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("طرق الدفع")),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: PaymentMethodsSection(
            banks: kDefaultBanks,
            onSelect: (bank) {
              // مثال: عند اختيار بنك الشرق افتح نافذة كود الشراء
              if (bank.name.contains("بنك الشرق")) {
                showPurchaseCodeDialog(context).then((code) {
                  if (code == null) return;

                  // TODO: مكان منطق التحقق وإكمال العملية
                });
              }
            },
          ),
        ),
      ),
    );
  }
}

/// لتجربة الواجهة بشكل مستقل (اختياري)
void main() {
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: const PaymentUIExample(),
    theme: ThemeData(
      useMaterial3: true,
      colorSchemeSeed: _secondaryColor,
    ),
  ));
}
