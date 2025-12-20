import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:marib/utils/app_icon.dart';

import 'delivery_address_section.dart';

/// تبويب يعرض عنوان التوصيل داخل عنصر قابل للتمدد مع الأيقونة المناسبة.
class CartDeliveryAddressTab extends StatelessWidget {
  const CartDeliveryAddressTab({
    super.key,
    required this.loading,
    required this.address,
    required this.onManageAddresses,
    this.initiallyExpanded = true,
  });

  /// حالة التحميل الحالية لعرض واجهة مؤقتة عند الحاجة.
  final bool loading;

  /// بيانات العنوان المختار لإظهاره للمستخدم.
  final Map<String, dynamic>? address;

  /// أمر إدارة العناوين الذي يتم استدعاؤه عند الضغط على زر التعديل.
  final VoidCallback onManageAddresses;

  /// تحديد ما إذا كان التبويب مفتوحًا افتراضيًا أم لا.
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color accent = Theme.of(context).colorScheme.primary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F4F6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 6,
              offset: const Offset(0, 5),
            ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: SvgPicture.asset(
            AppIcons.locationIcon,
            width: 24,
            height: 24,
            colorFilter: ColorFilter.mode(accent, BlendMode.srcIn),
          ),
          title: const Text(
            'العنوان',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          children: [
            DeliveryAddressSection(
              loading: loading,
              address: address,
              onManageAddresses: onManageAddresses,
            ),
          ],
        ),
      ),
    );
  }
}
