import 'package:flutter/material.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/ui_utils.dart';

class MinimalMapAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onBack;

  const MinimalMapAppBar({
    super.key,
    required this.title,
    this.onBack,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AppBar(
      backgroundColor: context.color.secondaryColor,
      elevation: 0,
      centerTitle: false,
      // شريط الحالة (Status Bar) متوافق مع الثيمين
      systemOverlayStyle: UiUtils.getSystemUiOverlayStyle(
        context: context,
        statusBarColor: context.color.secondaryColor,
      ),
      // زر الرجوع
      leading: IconButton(
        tooltip: 'رجوع',
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          color: context.color.territoryColor,
        ),
        onPressed: onBack ??
            () {
              if (Navigator.of(context).canPop()) Navigator.of(context).pop();
            },
      ),
      // عنوان القسم
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: context.color.territoryColor,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
      // بدون أي Actions/Bottom إضافية
    );
  }
}

// ============== AdsGoogleMap (نسخة محسّنة) ==============

class MapFilterPanel extends StatelessWidget {
  final String selectedCategory;
  final List<String> categories;
  final ValueChanged<String> onChanged;
  final String currentAddress;

  const MapFilterPanel({
    super.key,
    required this.selectedCategory,
    required this.categories,
    required this.onChanged,
    required this.currentAddress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      height: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('تصفية حسب الفئة:',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButton<String>(
            value: selectedCategory,
            isExpanded: true,
            items: categories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
          const SizedBox(height: 12),
          if (currentAddress.isNotEmpty)
            Text('موقعي: $currentAddress',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}
