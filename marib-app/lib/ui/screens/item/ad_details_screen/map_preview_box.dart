// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:timeago/timeago.dart' as timeago;

import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/utils/responsiveSize.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'dart:ui' as ui;
import 'package:marib/ui/screens/widgets/shimmerLoadingContainer.dart';


/// ✅ هذا الويجت يعرض خريطة ثابتة مع زر تفاعلي فوقها.
/// يتم استخدامه في صفحة تفاصيل الإعلان لعرض موقع الإعلان بشكل مختصر.


class MapPreviewBox extends StatelessWidget {
  final double latitude;
  final double longitude;
  final bool isDarkMode;
  final Widget addressWidget;
  final VoidCallback onTap;

  const MapPreviewBox({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.addressWidget,
    required this.onTap,
    this.isDarkMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDarkMode
        ? Colors.white.withOpacity(0.95)
        : Colors.grey.shade800;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("📍 موقع الإعلان")
            .bold()
            .size(context.font.large)
            .color(textColor),

        addressWidget,

        const SizedBox(height: 8),

        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                height: 200.rh(context),
                width: double.infinity,
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(latitude, longitude),
                    zoom: 13,
                  ),
                  zoomControlsEnabled: false,
                  zoomGesturesEnabled: false,
                  mapType: MapType.hybrid,
                  markers: {
                    Marker(
                      markerId: const MarkerId('currentPosition'),
                      position: LatLng(latitude, longitude),
                    ),
                  },
                  myLocationButtonEnabled: false,
                  compassEnabled: false,
                  onTap: (_) => onTap(),
                ),
              ),
            ),

            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: Container(
                    color: Colors.black.withOpacity(0.2),
                  ),
                ),
              ),
            ),

            Positioned.fill(
              child: Center(
                child: ElevatedButton.icon(
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.9),
                    foregroundColor: isDarkMode
                        ? Colors.grey.shade900
                        : Colors.grey.shade800,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 50, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  icon: const Icon(Icons.map_outlined),
                  label: Text("انقر لعرض موقع الإعلان")
                      .bold()
                      .size(context.font.small),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}



class MapPreviewBoxShimmer extends StatelessWidget {
  const MapPreviewBoxShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CustomShimmer(height: 16, width: 140, borderRadius: 6),
        const SizedBox(height: 8),
        const CustomShimmer(height: 14, width: 200, borderRadius: 6),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: 200.rh(context),
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: const [
                CustomShimmer(borderRadius: 18),
                Positioned.fill(
                  child: Center(
                    child: CustomShimmer(
                      height: 44,
                      width: 200,
                      borderRadius: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}