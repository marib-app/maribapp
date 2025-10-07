import 'package:flutter/material.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:shimmer/shimmer.dart';
import 'package:marib/ui/theme/theme.dart';

import 'package:marib/ui/screens/cart/components/delivery_and_payment/shared_widgets.dart';

/// ويدجت يعرض معلومات عنوان التوصيل وإدارة العناوين للمستخدم.
class DeliveryAddressSection extends StatelessWidget {
  final bool loading;
  final Map<String, dynamic>? address;
  final VoidCallback onManageAddresses;

  const DeliveryAddressSection({
    super.key,
    required this.loading,
    required this.address,
    required this.onManageAddresses,
  });

  @override
  Widget build(BuildContext context) {
    double? parseCoordinate(dynamic value, {required bool isLat}) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      if (value is String) {
        final String trimmed = value.trim();
        if (trimmed.isEmpty) return null;
        return double.tryParse(trimmed);
      }

      if (value is Map) {
        final Map<String, dynamic> map = value is Map<String, dynamic>
            ? value
            : Map<String, dynamic>.from(value);
        final Iterable<String> keys = isLat
            ? const <String>['lat', 'latitude', 'geo_lat']
            : const <String>['lng', 'longitude', 'geo_lng'];
        for (final String key in keys) {
          final double? candidate = parseCoordinate(map[key], isLat: isLat);
          if (candidate != null) {
            return candidate;
          }
        }
        return null;
      }

      return null;
    }

    Map<String, dynamic>? asMap(dynamic value) {
      if (value is Map<String, dynamic>) {
        return value;
      }
      if (value is Map) {
        return Map<String, dynamic>.from(value);
      }
      return null;
    }

    final Map<String, dynamic>? coordinatesMap =
        asMap(address?['coordinates']) ??
            asMap(address?['location']) ??
            asMap(address?['geo']);

    final double? lat = parseCoordinate(
      address?['lat'] ??
          address?['latitude'] ??
          coordinatesMap?['lat'] ??
          coordinatesMap?['latitude'] ??
          coordinatesMap?['geo_lat'],
      isLat: true,
    );
    final double? lng = parseCoordinate(
      address?['lng'] ??
          address?['longitude'] ??
          coordinatesMap?['lng'] ??
          coordinatesMap?['longitude'] ??
          coordinatesMap?['geo_lng'],
      isLat: false,
    );
    final bool hasId = (address?['id']) != null;
    final bool hasLatLng = lat != null && lng != null;
    final String baseLabel =
        (address?['label'] ?? address?['address'] ?? '').toString().trim();
    final String formattedLabel =
        (address?['formatted_address'] ?? '').toString().trim();
    final String locationText =
        formattedLabel.isNotEmpty ? formattedLabel : baseLabel;
    final String region =
        (address?['area'] ?? address?['city'] ?? '').toString().trim();
    final String note =
        (address?['note'] ?? address?['description'] ?? '').toString().trim();
    final String name = (address?['name'] ?? '').toString().trim();
    final String phone = (address?['phone'] ?? '').toString().trim();
    final bool readyForShipping = hasId && hasLatLng;
    final bool hasAnyAddress = hasId ||
        locationText.isNotEmpty ||
        region.isNotEmpty ||
        phone.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        loading
            ? buildShimmerLine(context, width: double.infinity, height: 48)
            : FilledButton.icon(
                onPressed: onManageAddresses,
                icon: Icon(
                  hasAnyAddress
                      ? Icons.edit_location_alt
                      : Icons.add_location_alt_outlined,
                ),
                label: Text(hasAnyAddress ? 'إدارة العناوين' : 'أضف عنوانًا'),
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor:
                      context.color.secondaryColor.withOpacity(0.1),
                  foregroundColor: context.color.territoryColor,
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: context.color.territoryColor),
                  ),
                ),
              ),
        if (!loading && !hasAnyAddress) ...[
          const SizedBox(height: 12),
          Text(
            'يرجى اختيار عنوان لعرض ملخص الطلب وخيارات التوصيل والدفع.',
            style: TextStyle(
              fontSize: 12.5,
              color: context.color.textColorDark.withOpacity(0.75),
            ),
          ),
        ],
        const SizedBox(height: 20),
        if (loading)
          _buildAddressShimmerCard(context)
        else if (hasAnyAddress)
          Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF2C2C2E)
                      : const Color(0xFFF9F9F9),
                  border: Border.all(
                    color: context.color.secondaryColor,
                    width: 1.8,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: Offset(0, 2)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (name.isNotEmpty) ...[
                      _addressRow(
                        context,
                        Icons.person,
                        'الاسم',
                        name,
                      ),
                      const SizedBox(height: 10),
                    ],
                    _addressRow(
                      context,
                      Icons.location_on,
                      'العنوان',
                      locationText.isNotEmpty ? locationText : 'غير محدد',
                    ),
                    if (region.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _addressRow(
                        context,
                        Icons.map_outlined,
                        'المنطقة',
                        region,
                      ),
                    ],
                    if (phone.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _addressRow(
                        context,
                        Icons.phone,
                        'رقم التواصل',
                        phone,
                      ),
                    ],
                    if (note.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _addressRow(
                        context,
                        Icons.sticky_note_2_outlined,
                        'ملاحظات',
                        note,
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          readyForShipping
                              ? Icons.check_circle_outline
                              : Icons.warning_amber_rounded,
                          size: 18,
                          color:
                              readyForShipping ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            readyForShipping
                                ? 'العنوان جاهز للتوصيل مع موقع محدد على الخريطة.'
                                : 'أضف الموقع الجغرافي لهذا العنوان لضمان إتمام التوصيل.',
                            style: TextStyle(
                              fontSize: 13,
                              color: readyForShipping
                                  ? Colors.green
                                  : Colors.orange,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (readyForShipping)
                const Positioned(
                  top: 8,
                  left: 8,
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: Color(0xFF4CAF50),
                    child: Icon(Icons.check, color: Colors.white, size: 16),
                  ),
                ),
            ],
          )
        else
          _buildAddAddressPlaceholder(context),
      ],
    );
  }

  Widget _addressRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Icon(icon,
            size: 18, color: context.color.textColorDark.withOpacity(0.7)),
        const SizedBox(width: 6),
        Text(
          '$label:',
          style: TextStyle(
            color: context.color.textColorDark,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildAddressShimmerCard(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
      highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade800 : Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(
            4,
            (_) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Container(
                height: 14,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddAddressPlaceholder(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.color.secondaryColor.withOpacity(0.5),
          width: 1.4,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'لم يتم إضافة عنوان توصيل بعد.',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'أضف عنوانًا يحتوي على الإحداثيات الجغرافية لمتابعة اختيار التوصيل والدفع.',
            style: TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }
}
