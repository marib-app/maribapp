import 'package:dio/dio.dart';
import 'package:marib/utils/hive_keys.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';

class NetworkToLocalSvg {
  Dio dio = Dio();
  static final Map<String, Future<String?>> _inFlightRequests = {};

  Future<String?> convert(String url) async {
    try {
      if (kDebugMode) {
        debugPrint('NetworkToLocalSvg.fetch -> $url');
      }

      Response response = await dio.get(url);

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw "Error while load svg";
      }
    } catch (e) {
      rethrow;
    }
  }

  Widget svg(String url, {Color? color, double? width, double? height}) {
    final box = Hive.box(HiveKeys.svgBox);
    final cachedSvg = box.get(url) as String?;

    if (cachedSvg != null) {
      return _buildSvgPicture(
        cachedSvg,
        color: color,
        width: width,
        height: height,
      );
    }

    final future = _inFlightRequests[url] ?? _createRequest(url, box);
    return FutureBuilder<String?>(
      future: future,
      builder: (context, AsyncSnapshot<String?> snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData &&
            snapshot.data != null) {
          return _buildSvgPicture(
            snapshot.data!,
            color: color,
            width: width,
            height: height,
          );
        }

        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }

        return Container();
      },
    );
  }

  Future<String?> _createRequest(String url, Box box) {
    final future = convert(url).then((data) {
      if (data != null) {
        box.put(url, data);
      }
      return data;
    });

    _inFlightRequests[url] = future;

    future.whenComplete(() {
      _inFlightRequests.remove(url);
    });

    return future;
  }

  Widget _buildSvgPicture(
    String data, {
    Color? color,
    double? width,
    double? height,
  }) {
    return SvgPicture.string(
      data,
      colorFilter:
          color != null ? ColorFilter.mode(color, BlendMode.srcIn) : null,
      width: width,
      height: height,
    );
  }
}
