import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import 'package:marib/ui/screens/item/add_item_screen/add_item_details/add_item_details_model.dart';
import 'package:marib/ui/screens/item/add_item_screen/shein_grabber_page.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/app/navigation/app_page_route.dart';
import 'package:marib/app/navigation/motion/route_motion.dart';

class AddItemDetailsSheinService {
  AddItemDetailsSheinService({
    required this.model,
    required this.refresh,
  });

  final AddItemDetailsModel model;
  final VoidCallback refresh;

  Future<void> fetchSheinData(BuildContext context) async {
    final String url = model.adProductLinkController.text.trim();
    if (url.isEmpty) {
      HelperUtils.showSnackBarMessage(context, 'أدخل رابط المنتج أولاً');
      return;
    }

    final Uri? uri = Uri.tryParse(url);
    if (uri == null ||
        !(uri.host.contains('shein.com') || uri.host.contains('sheinapp.com'))) {
      HelperUtils.showSnackBarMessage(context, 'يرجى إدخال رابط صالح من شي إن');
      return;
    }

    if (model.isFetchingShein) {
      return;
    }
    model.isFetchingShein = true;
    refresh();

    try {
      final Map<String, dynamic>? data = await Navigator.push(
        context,
        AppPageRoute.build<Map<String, dynamic>>(
          builder: (_) => SheinGrabberPage(startUrl: url),
          motionPattern: AppMotionPattern.glide,
        ),
      );

      if (data == null) {
        HelperUtils.showSnackBarMessage(context, 'تم الإلغاء، لم يتم جلب بيانات');
        return;
      }

      final String? title = (data['title'] as String?)?.trim();
      final String? priceRaw = (data['price'] as String?)?.trim();
      final String? currency = (data['currency'] as String?)?.trim();
      final List<String> images =
          (data['images'] as List<dynamic>?)?.cast<String>() ?? const <String>[];

      if (title != null && title.isNotEmpty) {
        model.adTitleController.text = title;
      }

      if (priceRaw != null && priceRaw.isNotEmpty) {
        final String? normalized =
        RegExp(r'[\d\.,]+').firstMatch(priceRaw)?.group(0)?.replaceAll(',', '');
        if (normalized != null) {
          model.adPriceController.text = normalized;
        }
      }

      if (currency != null && currency.isNotEmpty) {
        model.selectedCurrency = currency.toUpperCase();
      }

      if (images.isNotEmpty) {
        final List<Map<String, dynamic>> materialized =
        await _materializeRemoteImages(images);
        if (materialized.isNotEmpty) {
          final Map<String, dynamic> first = materialized.first;
          first['isMain'] = true;
          model.galleryItems
            ..clear()
            ..addAll(materialized);
        }
      }

      refresh();
      HelperUtils.showSnackBarMessage(context, 'تم جلب البيانات بنجاح');
    } catch (error) {
      HelperUtils.showSnackBarMessage(
        context,
        'تعذر الجلب: ${error.toString()}',
      );
    } finally {
      model.isFetchingShein = false;
      refresh();
    }
  }

  Future<List<Map<String, dynamic>>> _materializeRemoteImages(
      List<String> urls) async {
    if (urls.isEmpty) {
      return const <Map<String, dynamic>>[];
    }

    final Directory tempDir = await getTemporaryDirectory();
    final List<Map<String, dynamic>> resolved = <Map<String, dynamic>>[];

    for (final String url in urls) {
      if (url.isEmpty) {
        continue;
      }
      try {
        final Uri? uri = Uri.tryParse(url);
        if (uri == null) {
          continue;
        }
        final http.Response response = await http.get(uri);
        if (response.statusCode != 200) {
          continue;
        }

        final Set<String> allowed = <String>{'jpg', 'jpeg', 'png'};
        final String contentType = response.headers['content-type'] ?? '';
        String? headerExtension;
        if (contentType.contains('/')) {
          final List<String> parts = contentType.split('/');
          if (parts.length == 2) {
            headerExtension = parts[1];
          }
        }

        String? extensionFromUrl;
        if (uri.pathSegments.isNotEmpty) {
          final String segment = uri.pathSegments.last;
          final int dotIndex = segment.lastIndexOf('.');
          if (dotIndex != -1 && dotIndex < segment.length - 1) {
            final String candidate = segment.substring(dotIndex + 1).toLowerCase();
            if (candidate.length <= 5) {
              extensionFromUrl = candidate;
            }
          }
        }

        String resolvedExtension =
        (extensionFromUrl ?? headerExtension ?? 'jpg').toLowerCase();

        bool requiresTranscode =
            !allowed.contains(resolvedExtension) ||
                (headerExtension != null && !allowed.contains(headerExtension));

        List<int> bytes = response.bodyBytes;
        if (requiresTranscode) {
          final img.Image? decoded = img.decodeImage(Uint8List.fromList(bytes));
          if (decoded == null) {
            continue;
          }
          bytes = img.encodeJpg(decoded);
          resolvedExtension = 'jpg';
        }

        final String fileName =
            'remote_${DateTime.now().microsecondsSinceEpoch}_${resolved.length}.$resolvedExtension';
        final File file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(bytes);

        resolved.add(<String, dynamic>{'file': file, 'url': url});
      } catch (_) {
        continue;
      }
    }

    return resolved;
  }
}


