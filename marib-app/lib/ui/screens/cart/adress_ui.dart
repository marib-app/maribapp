import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shimmer/shimmer.dart';

import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/app_icon.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/responsiveSize.dart';
import 'package:marib/utils/ui_utils.dart';

class AdressUI extends StatelessWidget {
  // مدخلات العرض فقط
  final bool isLoading;
  final List<Map<String, dynamic>> addressList;
  final int selectedIndex;

  // أحداث يوفّرها المنطق
  final VoidCallback onAddNew;
  final void Function(int index) onSelect;
  final void Function(int index) onEdit;
  final void Function(int index) onDelete;
  final void Function(int index) onSetDefault;
  final void Function(int index) onAddLocation;
  final VoidCallback? onBackPress;

  const AdressUI({
    super.key,
    required this.isLoading,
    required this.addressList,
    required this.selectedIndex,
    required this.onAddNew,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
    required this.onSetDefault,
    required this.onAddLocation,
    this.onBackPress,

  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.color.primaryColor,
      appBar: UiUtils.buildAppBar(
        context,
        title: "عناوين التوصيل",
        bottomHeight: 20,
        showBackButton: true,
        onBackPress: onBackPress,

      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: UiUtils.buildButton(
          context,
          buttonTitle: 'رجوع الى معلومات الشحن',
          onPressed: onBackPress ?? () {},
          height: 52,
          radius: 14,
          disabled: onBackPress == null,
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildAddressForm(context),
            const Divider(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: onAddNew,
          icon: SvgPicture.asset(
            AppIcons.locationIcon,
            width: 22,
            height: 22,
            color: context.color.territoryColor,
          ),
          label: Text(
            "أضف عنوان جديد",
            style: TextStyle(color: context.color.territoryColor),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: context.color.territoryColor),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        const SizedBox(height: 16),

        if (isLoading)
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 2,
            itemBuilder: (_, __) => _buildShimmerCard(context),
          )
        else if (addressList.isNotEmpty)
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: addressList.length,
            itemBuilder: (context, index) {
              final address = addressList[index];
              final isSelected = selectedIndex == index;
              final bool isDefault = address['is_default'] == true ||
                  address['isDefault'] == true ||
                  address['default'] == true;
              return _buildAddressCard(
                context,
                address: address,
                isSelected: isSelected,
                isDefault: isDefault,
                onTap: () => onSelect(index),
                onEdit: () => onEdit(index),
                onDelete: () => onDelete(index),
                onSetDefault: () => onSetDefault(index),
                onAddLocation: () => onAddLocation(index),
              );
            },
          )
        else
        // TODO: أظهر عنصر "لا توجد عناوين" الخاص بك هنا إن لزم
          const SizedBox.shrink(),
      ],
    );
  }

  // ====== بطاقات العناوين ======

  Widget _buildAddressCard(
      BuildContext context, {
        required Map<String, dynamic> address,
        required bool isSelected,
        required bool isDefault,
        required VoidCallback onTap,
        required VoidCallback onEdit,
        required VoidCallback onDelete,
        required VoidCallback onSetDefault,
        required VoidCallback onAddLocation,
      }) {
    final double? lat = _parseCoordinate(address['lat'] ?? address['latitude']);
    final double? lng = _parseCoordinate(address['lng'] ?? address['longitude']);
    final bool hasLocation = lat != null && lng != null;
    final String locationLabel = hasLocation ? _locationLabel(address) : 'غير محدد';


    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 16),
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF2C2C2E)
                  : const Color(0xFFF9F9F9),
              border: Border.all(
                color: isSelected
                    ? context.color.territoryColor
                    : context.color.secondaryColor.withOpacity(0.5),
                width: 1.8,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildAddressRow(
                        context,
                        Icons.person,
                        'الاسم',
                        address['name'] ?? '',
                      ),
                    ),
                    if (isDefault)
                      Container(
                        padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: context.color.territoryColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'العنوان الافتراضي',
                          style: TextStyle(
                            color: context.color.territoryColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 10),

                _buildAddressRow(
                  context,
                  Icons.home_outlined,
                  'العنوان',
                  address['address'] ?? address['label'] ?? '',
                ),
                const SizedBox(height: 10),

                _buildAddressRow(
                  context,
                  Icons.location_on,
                  'الموقع الجغرافي',
                  locationLabel,
                ),
                const SizedBox(height: 10),
                _buildAddressRow(context, Icons.phone, 'رقم التواصل', address['phone'] ?? ''),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.start,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: isDefault ? null : onSetDefault,
                      icon: const Icon(Icons.verified_user_outlined, size: 20),
                      label: const Text("افتراضي"),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      label: const Text("تعديل"),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline, size: 20),
                      label: const Text("حذف"),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: onAddLocation,
                      icon: const Icon(Icons.add_location_alt_outlined, size: 20),
                      label: const Text("أضف الموقع"),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
                if (!hasLocation)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      '⚠️ لم يتم تحديد الموقع الجغرافي لهذا العنوان',
                      style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
          if (isSelected && hasLocation)
            const Positioned(
              top: 10,
              left: 10,
              child: CircleAvatar(
                radius: 14,
                backgroundColor: Color(0xFF4CAF50),
                child: Icon(Icons.check, color: Colors.white, size: 16),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAddressRow(BuildContext context, IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: context.color.territoryColor),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              text: "$label: ",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: context.color.textColorDark,
              ),
              children: [
                TextSpan(
                  text: value.isEmpty ? '—' : value,
                  style: TextStyle(
                    fontWeight: FontWeight.normal,
                    color: context.color.textDefaultColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }


  double? _parseCoordinate(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  String _locationLabel(Map<String, dynamic> address) {
    final List<String> parts = <String>[
      for (final String key in const <String>['area', 'city', 'state', 'country'])
        if ((address[key]?.toString().trim().isNotEmpty ?? false))
          address[key].toString().trim(),
    ];
    if (parts.isEmpty) {
      return 'تم تحديد الإحداثيات';
    }
    return parts.join('، ');
  }




  // ====== شيمر البطاقة ======
  Widget _buildShimmerCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
      highlightColor: isDark ? Colors.grey.shade600 : Colors.grey.shade100,
      child: Container(
        height: 160,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade900 : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

// مكوّن واجهي مستقل يمكن استخدامه عند الحاجة
class CustomExpansionTile extends StatefulWidget {
  final String title;
  final String svgImagePath;
  final bool? isSwitchBox;
  final Widget Function(BuildContext context)? buildChildren;

  const CustomExpansionTile({
    super.key,
    required this.title,
    required this.svgImagePath,
    this.isSwitchBox,
    this.buildChildren,
  });

  @override
  State<CustomExpansionTile> createState() => _CustomExpansionTileState();
}

class _CustomExpansionTileState extends State<CustomExpansionTile> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = context.color.secondaryColor;
    final borderColor = context.color.secondaryColor;
    final cornerRadius = BorderRadius.circular(8);

    return Stack(
      children: [
        Container(
          height: 59,
          margin: const EdgeInsets.only(top: 1, bottom: 3),
          decoration: BoxDecoration(color: backgroundColor, borderRadius: cornerRadius),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            width: 10,
            height: 60,
            decoration: BoxDecoration(
              color: context.color.territoryColor,
              borderRadius: const BorderRadius.only(topRight: Radius.circular(8), bottomRight: Radius.circular(8)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13.0),
          child: Container(
            decoration: BoxDecoration(
              color: backgroundColor,
              border: Border.all(color: borderColor, width: 1),
              borderRadius: cornerRadius,
            ),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 10),
              title: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: context.color.territoryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: FittedBox(
                      fit: BoxFit.none,
                      child: UiUtils.getSvg(
                        widget.svgImagePath,
                        height: 24,
                        width: 24,
                        color: context.color.territoryColor,
                      ),
                    ),
                  ),
                  SizedBox(width: 25.rw(context)),
                  Expanded(
                    flex: 3,
                    child: Text(widget.title).bold(weight: FontWeight.w700).color(context.color.textColorDark),
                  ),
                  const Spacer(),
                ],
              ),
              trailing: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
              onExpansionChanged: (bool expanding) => setState(() => _isExpanded = expanding),
              children: [if (widget.buildChildren != null) widget.buildChildren!(context)],
            ),
          ),
        ),
      ],
    );
  }
}
