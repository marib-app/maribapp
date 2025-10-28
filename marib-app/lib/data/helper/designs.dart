import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:marib/ui/widgets/shimmer/shimmer_box.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/ui/widgets/placeholders/image_error_placeholder.dart';


const double defaultPadding = 20;

Widget setNetworkImg(String? mainUrl,
    {double? height,
    double? width,
    Color? imgColor,
    BoxFit boxFit = BoxFit.contain,
    BoxFit? placeboxfit}) {
  String url = mainUrl ??= "";
  return CachedNetworkImage(
    imageUrl: url,
    width: width,
    height: height,
    fit: boxFit,
    memCacheHeight: 500,
    memCacheWidth: 500,
    placeholder: (context, url) => ShimmerBox(
      width: width,
      height: height,
      borderRadius: BorderRadius.circular(12),
    ),
    errorWidget: (context, url, error) => ImageErrorPlaceholder(
      width: width,
      height: height,

    ),
  );
}

Widget setSVGImage(String imageName,
    {double? height,
    double? width,
    Color? imgColor,
    BoxFit boxFit = BoxFit.contain}) {
  String path = "$svgPath$imageName.svg";
  return SvgPicture.asset(
    path,
    height: height,
    width: width,
    colorFilter:
        imgColor != null ? ColorFilter.mode(imgColor, BlendMode.srcIn) : null,
    fit: boxFit,
  );
}
