import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:marib/app/app_localization.dart';
import 'package:marib/app/app_theme.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/app/navigation/app_page_route.dart';
import 'package:marib/app/navigation/motion/route_motion.dart';
import 'package:marib/data/cubits/system/app_theme_cubit.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/constant.dart';
import 'hive_utils.dart';
import 'package:timeago/timeago.dart' as timeago_ar show setLocaleMessages;
import 'package:marib/ui/widgets/shimmer/shimmer_box.dart';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:mime_type/mime_type.dart';
import 'package:marib/ui/screens/widgets/blurred_dialoge_box.dart';
import 'package:marib/ui/screens/widgets/full_screen_image_view.dart';
import 'package:marib/ui/screens/widgets/gallery_view.dart';
import 'package:marib/data/cubits/home/fetch_home_all_items_cubit.dart';
import 'package:marib/data/cubits/home/fetch_home_screen_cubit.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:intl/intl.dart';
import 'helper_utils.dart';
import 'package:marib/utils/network_to_localsvg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:marib/data/model/subscription_package_limit.dart';

import 'dart:ui' show ImageFilter;
import 'package:flutter/gestures.dart';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:marib/ui/widgets/standard_bottom_sheet_scaffold.dart';

class _AdaptiveNetworkImage extends StatefulWidget {
  const _AdaptiveNetworkImage({
    required this.urls,
    required this.width,
    required this.height,
    required this.fit,
    required this.cacheWidth,
    required this.cacheHeight,
  });

  final List<String> urls;
  final double? width;
  final double? height;
  final BoxFit fit;
  final int cacheWidth;
  final int cacheHeight;

  @override
  State<_AdaptiveNetworkImage> createState() => _AdaptiveNetworkImageState();
}

class _AdaptiveNetworkImageState extends State<_AdaptiveNetworkImage> {
  int _currentIndex = 0;

  @override
  void didUpdateWidget(covariant _AdaptiveNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.urls, widget.urls)) {
      _currentIndex = 0;
    } else if (widget.urls.isNotEmpty && _currentIndex >= widget.urls.length) {
      _currentIndex = widget.urls.length - 1;
    } else if (widget.urls.isEmpty) {
      _currentIndex = 0;
    }
  }

  void _scheduleNextCandidate() {
    if (_currentIndex >= widget.urls.length - 1) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _currentIndex += 1;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.urls.isEmpty) {
      return UiUtils._buildImageError(context, widget.width, widget.height);
    }

    final int index = (_currentIndex >= widget.urls.length)
        ? widget.urls.length - 1
        : _currentIndex;
    final String url = widget.urls[index];

    return CachedNetworkImage(
      key: ValueKey('cached_network_image_${url.hashCode}'),
      imageUrl: url,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      memCacheWidth: widget.cacheWidth,
      memCacheHeight: widget.cacheHeight,
      maxWidthDiskCache: widget.cacheWidth,
      maxHeightDiskCache: widget.cacheHeight,
      placeholder: (context, _) => UiUtils._buildImagePlaceholder(
        context,
        widget.width,
        widget.height,
      ),
      errorWidget: (context, _, __) {
        if (_currentIndex < widget.urls.length - 1) {
          _scheduleNextCandidate();
          return UiUtils._buildImagePlaceholder(
            context,
            widget.width,
            widget.height,
          );
        }
        return UiUtils._buildImageError(context, widget.width, widget.height);
      },
    );
  }
}

class _UiSmartButton extends StatefulWidget {
  const _UiSmartButton({
    this.height,
    this.width,
    this.border,
    this.titleWhenProgress,
    this.isInProgress,
    this.isSuccess,
    this.isError,
    this.fontSize,
    this.radius,
    this.autoWidth,
    this.prefixWidget,
    this.padding,
    required this.onPressed,
    required this.buttonTitle,
    this.showProgressTitle,
    this.progressWidth,
    this.progressHeight,
    this.showElevation,
    this.textColor,
    this.buttonColor,
    this.outerPadding,
    this.disabledColor,
    this.disabledTextColor,
    this.onTapDisabledButton,
    this.disabled,
    required this.autoManageState,
    required this.autoDisableWhenInvalid,
    this.requiredTextControllers,
    this.enableConditions,
  });

  final double? height;
  final double? width;
  final BorderSide? border;
  final String? titleWhenProgress;
  final bool? isInProgress;
  final bool? isSuccess;
  final bool? isError;
  final double? fontSize;
  final double? radius;
  final bool? autoWidth;
  final Widget? prefixWidget;
  final EdgeInsetsGeometry? padding;
  final FutureOr<void> Function() onPressed;
  final String buttonTitle;
  final bool? showProgressTitle;
  final double? progressWidth;
  final double? progressHeight;
  final bool? showElevation;
  final Color? textColor;
  final Color? buttonColor;
  final EdgeInsets? outerPadding;
  final Color? disabledColor;
  final Color? disabledTextColor;
  final VoidCallback? onTapDisabledButton;
  final bool? disabled;
  final bool autoManageState;
  final bool autoDisableWhenInvalid;
  final List<TextEditingController>? requiredTextControllers;
  final List<ValueListenable<bool>>? enableConditions;

  @override
  State<_UiSmartButton> createState() => _UiSmartButtonState();
}

class _UiSmartButtonState extends State<_UiSmartButton> {
  bool _autoBusy = false;
  bool _pressGuardActive = false;
  bool _requirementsDisabled = false;
  final Set<Listenable> _requirementListeners = <Listenable>{};

  @override
  void initState() {
    super.initState();
    _syncRequirementListeners();
    if (widget.autoDisableWhenInvalid) {
      _requirementsDisabled = _computeRequirementDisabled();
    }
  }

  @override
  void didUpdateWidget(covariant _UiSmartButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    final bool requirementsChanged =
        !listEquals(oldWidget.requiredTextControllers, widget.requiredTextControllers) ||
        !listEquals(oldWidget.enableConditions, widget.enableConditions) ||
        oldWidget.autoDisableWhenInvalid != widget.autoDisableWhenInvalid;

    if (requirementsChanged) {
      _syncRequirementListeners();
      final bool disabledNow =
          widget.autoDisableWhenInvalid ? _computeRequirementDisabled() : false;
      if (disabledNow != _requirementsDisabled) {
        setState(() {
          _requirementsDisabled = disabledNow;
        });
      }
    }

    if (!_shouldAutoManage && _autoBusy) {
      _autoBusy = false;
    }
  }

  @override
  void dispose() {
    _detachRequirementListeners();
    super.dispose();
  }

  void _syncRequirementListeners() {
    _detachRequirementListeners();
    if (!widget.autoDisableWhenInvalid) {
      return;
    }

    final List<TextEditingController>? controllers =
        widget.requiredTextControllers;
    if (controllers != null) {
      for (final TextEditingController controller in controllers) {
        controller.addListener(_handleRequirementChanged);
        _requirementListeners.add(controller);
      }
    }

    final List<ValueListenable<bool>>? conditions = widget.enableConditions;
    if (conditions != null) {
      for (final ValueListenable<bool> condition in conditions) {
        condition.addListener(_handleRequirementChanged);
        _requirementListeners.add(condition);
      }
    }
  }

  void _detachRequirementListeners() {
    for (final Listenable listenable in _requirementListeners) {
      listenable.removeListener(_handleRequirementChanged);
    }
    _requirementListeners.clear();
  }

  void _handleRequirementChanged() {
    if (!widget.autoDisableWhenInvalid || !mounted) {
      return;
    }
    final bool disabledNow = _computeRequirementDisabled();
    if (disabledNow != _requirementsDisabled) {
      setState(() {
        _requirementsDisabled = disabledNow;
      });
    }
  }

  bool _computeRequirementDisabled() {
    bool missing = false;
    final List<TextEditingController>? controllers =
        widget.requiredTextControllers;
    if (controllers != null && controllers.isNotEmpty) {
      for (final TextEditingController controller in controllers) {
        if (controller.text.trim().isEmpty) {
          missing = true;
          break;
        }
      }
    }

    if (!missing) {
      final List<ValueListenable<bool>>? conditions = widget.enableConditions;
      if (conditions != null && conditions.isNotEmpty) {
        for (final ValueListenable<bool> condition in conditions) {
          if (!condition.value) {
            missing = true;
            break;
          }
        }
      }
    }

    return missing;
  }

  bool get _shouldAutoManage =>
      widget.autoManageState &&
      widget.isInProgress == null &&
      widget.isSuccess == null &&
      widget.isError == null;

  bool get _isBusy =>
      (widget.isInProgress ?? false) ||
      (_shouldAutoManage ? _autoBusy : false);

  bool get _isDisabled =>
      (widget.disabled ?? false) ||
      (widget.autoDisableWhenInvalid && _requirementsDisabled);

  bool get _showDisabledVisuals => _isDisabled || _isBusy;

  bool get _blockInput => _isDisabled || _isBusy || _pressGuardActive;

  Future<void> _handlePressed() async {
    if (_blockInput) {
      return;
    }

    HelperUtils.unfocus();

    final bool manageInternally = _shouldAutoManage;
    setState(() {
      _pressGuardActive = true;
      if (manageInternally) {
        _autoBusy = true;
      }
    });

    Object? error;
    StackTrace? stackTrace;

    try {
      final Object? result = widget.onPressed();
      if (result is Future<void>) {
        await result;
      } else if (result is Future) {
        await result;
      }
    } catch (err, st) {
      error = err;
      stackTrace = st;
    } finally {
      if (!mounted) {
        _pressGuardActive = false;
        _autoBusy = false;
      } else {
        setState(() {
          _pressGuardActive = false;
          if (manageInternally) {
            _autoBusy = false;
          }
        });
      }
    }

    if (error != null) {
      Error.throwWithStackTrace(error, stackTrace ?? StackTrace.current);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Size screenSize = MediaQuery.of(context).size;
    final bool isNarrow = screenSize.width < 360;

    final double effectiveHeight =
        widget.height ?? (isNarrow ? 42.0 : 46.0);
    final double effectiveRadius =
        widget.radius ?? (isNarrow ? 12.0 : 16.0);
    final double resolvedFontSize = widget.fontSize ??
        (isNarrow ? context.font.normal : context.font.large);
    final double horizontalPadding = isNarrow ? 12.0 : 16.0;
    final double contentGap = isNarrow ? 6.0 : 8.0;

    final bool isBusy = _isBusy;
    final bool isSuccess = widget.isSuccess == true;
    final bool isError = widget.isError == true;

    final Color baseButtonColor =
        widget.buttonColor ?? context.color.territoryColor;
    final Color fallbackDisabledBackground = Colors.grey.shade400;
    final Color disabledBackgroundColor =
        widget.disabledColor ?? fallbackDisabledBackground;

    final bool showDisabledVisuals = _showDisabledVisuals;
    final Color bg =
        showDisabledVisuals ? disabledBackgroundColor : baseButtonColor;

    final Color fg =
        widget.textColor ?? context.color.textAutoAdapt(bg);
    final Color disabledForeground = widget.disabledTextColor ??
        theme.colorScheme.onSurface.withOpacity(0.6);

    final Color contentColor =
        showDisabledVisuals ? disabledForeground : fg;

    final bool useWhiteProgress = bg.computeLuminance() < 0.5;
    final Color progressColor =
        useWhiteProgress ? Colors.white : contentColor;
    final String title = isBusy
        ? (widget.titleWhenProgress ?? widget.buttonTitle)
        : widget.buttonTitle;

    final double resolvedProgressWidth =
        widget.progressWidth ?? (isNarrow ? 20.0 : 22.0);
    final double resolvedProgressHeight =
        widget.progressHeight ?? (isNarrow ? 20.0 : 22.0);
    final bool showStatusIcon = isBusy || isSuccess || isError;
    final double statusGap = showStatusIcon
        ? (isBusy
            ? (max(resolvedProgressWidth, resolvedProgressHeight) >= 22
                ? contentGap + 2
                : contentGap)
            : contentGap)
        : 0;

    Widget buildText(String t, Color c) => Flexible(
          child: Text(
            t,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: resolvedFontSize,
              fontWeight: FontWeight.bold,
              height: 1.1,
              color: c,
            ),
          ),
        );

    final bool allowDisabledTap =
        widget.onTapDisabledButton != null && _isDisabled;

    final List<Widget> rowChildren = <Widget>[];

    if (isBusy) {
      rowChildren.add(
        UiUtils.progress(
          width: resolvedProgressWidth,
          height: resolvedProgressHeight,
          showWhite: useWhiteProgress,
          normalProgressColor: progressColor,
        ),
      );
    }

    if (isSuccess) {
      rowChildren.add(
        Icon(Icons.check_circle,
            color: contentColor, size: isNarrow ? 20 : 22),
      );
    }

    if (isError) {
      rowChildren.add(
        Icon(Icons.error_outline,
            color: contentColor, size: isNarrow ? 20 : 22),
      );
    }

    if (showStatusIcon && rowChildren.isNotEmpty) {
      rowChildren.add(SizedBox(width: statusGap));
    }

    if (isBusy) {
      if (widget.showProgressTitle ?? false) {
        rowChildren.add(buildText(title, contentColor));
      }
    } else if (!isSuccess && !isError) {
      if (widget.prefixWidget != null) {
        rowChildren.add(
          IconTheme.merge(
            data: IconThemeData(color: contentColor),
            child: widget.prefixWidget!,
          ),
        );
        rowChildren.add(SizedBox(width: contentGap));
      }
      rowChildren.add(buildText(title, contentColor));
    }

    return Padding(
      padding: widget.outerPadding ?? EdgeInsets.zero,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: (showDisabledVisuals && allowDisabledTap)
            ? widget.onTapDisabledButton
            : null,
        child: IgnorePointer(
          ignoring: _blockInput,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              elevation: (widget.showElevation ?? false) ? 1 : 0,
              backgroundColor: bg,
              foregroundColor: fg,
              disabledBackgroundColor: disabledBackgroundColor,
              disabledForegroundColor: disabledForeground,
              minimumSize: Size(
                widget.autoWidth == true ? 0 : (widget.width ?? double.infinity),
                effectiveHeight,
              ),
              padding: widget.padding ??
                  EdgeInsets.symmetric(horizontal: horizontalPadding),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(effectiveRadius),
                side: widget.border ?? BorderSide.none,
              ),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            onPressed: _blockInput ? null : _handlePressed,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: Row(
                key: ValueKey('${isBusy}-${isSuccess}-${isError}-$title'),
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: rowChildren,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class UiUtils {
  static final Map<OverlayState, _SoftSnackBarHandle> _activeSoftSnackBars =
      <OverlayState, _SoftSnackBarHandle>{};

  // دالة التحكم في عرض الوقت والتاريخ

  static String formatSmartTime(String? dateString) {
    if (dateString == null || dateString.isEmpty) return "";

    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();

      final difference = now.difference(date);

      if (difference.inDays >= 1) {
        // أكثر من يوم = نعرض التاريخ الكامل
        return DateFormat('d  MMM   yyyy  -  h:mm a', 'ar').format(date);
      } else {
        // أقل من يوم = نعرض "قبل دقائق" أو "الآن"
        return timeago.format(date, locale: 'ar'); // ✅ هذا أهم شيء
      }
    } catch (e) {
      return "";
    }
  }

  static String formatDate(String? dateString,
      {String pattern = 'd MMM yyyy - h:mm a'}) {
    if (dateString == null || dateString.isEmpty) return "";
    try {
      final date = DateTime.parse(dateString).toLocal();
      return DateFormat(pattern, 'ar').format(date);
    } catch (e) {
      return "";
    }
  }

  static String? subscriptionLimitSummary(
    BuildContext context,
    SubscriptionPackageLimit limit, {
    bool includeExpiry = true,
  }) {
    final bool isUnlimited = limit.isUnlimited;
    String? summary;

    if (isUnlimited) {
      summary = getTranslatedLabel(context, 'subscriptionLimitUnlimited');
    } else {
      final template =
          getTranslatedLabel(context, 'subscriptionLimitRemaining');
      final remainingText = (limit.remaining ?? 0).toString();
      final totalValue = limit.total;
      final totalText = totalValue != null ? totalValue.toString() : '—';
      summary = template
          .replaceAll('{remaining}', remainingText)
          .replaceAll('{total}', totalText);
    }

    if ((summary ?? '').trim().isEmpty) {
      summary = null;
    }

    if (summary == null) {
      return null;
    }

    if (!includeExpiry) {
      return summary;
    }

    final expiry = subscriptionLimitExpiry(context, limit);
    if (expiry == null || expiry.isEmpty) {
      return summary;
    }

    return '$summary · $expiry';
  }

  static String? subscriptionLimitExpiry(
      BuildContext context, SubscriptionPackageLimit limit) {
    final expiresAt = limit.expiresAt;
    if (expiresAt == null) {
      return null;
    }

    final template = getTranslatedLabel(context, 'subscriptionLimitExpiresOn');
    if (template.trim().isEmpty) {
      return null;
    }

    final formatted = _formatLimitDate(context, expiresAt.toLocal());
    if (formatted.isEmpty) {
      return null;
    }

    return template.replaceAll('{date}', formatted);
  }

  static String _formatLimitDate(BuildContext context, DateTime date) {
    final locale = Localizations.maybeLocaleOf(context);
    final languageCode = locale?.languageCode;
    final countryCode = locale?.countryCode;
    final localeName = (languageCode == null || languageCode.isEmpty)
        ? null
        : countryCode == null || countryCode.isEmpty
            ? languageCode
            : '${languageCode}_$countryCode';

    try {
      if (localeName != null) {
        return DateFormat('d MMM yyyy', localeName).format(date);
      }
      return DateFormat('d MMM yyyy').format(date);
    } catch (_) {
      return DateFormat('d MMM yyyy').format(date);
    }
  }

  // ✅ إرجاع أيقونة SVG من المسار المحدد
  static SvgPicture getSvg(String path,
      {Color? color, BoxFit? fit, double? width, double? height}) {
    return SvgPicture.asset(
      path,
      colorFilter:
          color != null ? ColorFilter.mode(color, BlendMode.srcIn) : null,
      fit: fit ?? BoxFit.contain,
      width: width,
      height: height,
    );
  }

  static Future<void> launchURL(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      throw 'لا يمكن فتح الرابط: $url';
    }
  }

  static void showLoadingDialog(BuildContext context,
      {String title = "جاري التحميل..."}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Expanded(child: Text(title)),
          ],
        ),
      ),
    );
  }

  static void showSoftSnackBar(
    BuildContext context, {
    required String message,
    String iconPath = 'assets/image/showSoftSnackBar.png',
    Duration duration = const Duration(seconds: 2),
    Color? backgroundColor,
    double backgroundOpacity = 0.9,
    Color textColor = Colors.white,
    double fontSize = 15,
    FontWeight fontWeight = FontWeight.w500,
    VoidCallback? onClosed,
  }) {
    final overlay = Overlay.of(context);
    if (overlay == null) return;

    final OverlayState overlayState = overlay;

    final ThemeData theme = Theme.of(context);

    void insertSnackBar() {
      final GlobalKey<_SoftSnackBarWidgetState> key =
          GlobalKey<_SoftSnackBarWidgetState>();
      late OverlayEntry entry;

      final Color baseColor = backgroundColor ??
          (theme.brightness == Brightness.dark
              ? Colors.grey[800]
              : Colors.grey[900])!;
      final Color resolvedBackgroundColor = backgroundColor != null
          ? baseColor
          : baseColor.withOpacity(backgroundOpacity);

      entry = OverlayEntry(
        builder: (_) => _SoftSnackBarWidget(
          key: key,
          message: message,
          iconPath: iconPath,
          duration: duration,
          backgroundColor: resolvedBackgroundColor,
          textColor: textColor,
          fontSize: fontSize,
          fontWeight: fontWeight,
          onFinish: () {
            if (entry.mounted) {
              entry.remove();
            }
            final _SoftSnackBarHandle? activeHandle =
                _activeSoftSnackBars[overlayState];
            if (activeHandle != null && identical(activeHandle.entry, entry)) {
              _activeSoftSnackBars.remove(overlayState);
            }
            onClosed?.call();
          },
        ),
      );

      _activeSoftSnackBars[overlayState] =
          _SoftSnackBarHandle(entry: entry, key: key);

      overlayState.insert(entry);
    }

    final _SoftSnackBarHandle? active = _activeSoftSnackBars[overlayState];
    if (active != null) {
      final _SoftSnackBarWidgetState? state = active.key.currentState;
      if (state != null) {
        state.dismiss().whenComplete(insertSnackBar);
        return;
      }

      if (active.entry.mounted) {
        active.entry.remove();
      }
      _activeSoftSnackBars.remove(overlayState);
    }

    insertSnackBar();
  }

  static PreferredSizeWidget buildAppBar(
    BuildContext context, {
    String? title,
    Widget? titleWidget,
    String? subtitle,
    Widget? subtitleWidget,
    bool showBackButton = false,
    Widget? leading,
    List<Widget>? actions,
    List<Widget>? bottom,
    double? bottomHeight,
    bool? hideTopBorder,
    VoidCallback? onBackPress,
    Color? backgroundColor,
    Color? foregroundColor,
    Color? borderColor,
    Color? statusBarColor,
    Color? backButtonBackgroundColor,
    EdgeInsetsGeometry? contentPadding,
    bool centerTitle = true,
    double? height,
    double borderRadius = 18,
    double borderStrokeWidth = 1.0,
  }) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool shouldHideTopBorder = hideTopBorder ?? true;
    final double toolbarHeight = height ?? kToolbarHeight;

    final String? normalizedTitle =
        title != null && title.trim().isNotEmpty ? title.trim() : null;
    final String? normalizedSubtitle =
        subtitle != null && subtitle.trim().isNotEmpty ? subtitle.trim() : null;

    final Color resolvedBackgroundColor =
        backgroundColor ?? colorScheme.secondaryColor;
    final Color resolvedBorderColor = borderColor ?? colorScheme.borderColor;
    final Color resolvedForegroundColor =
        foregroundColor ?? colorScheme.textAutoAdapt(resolvedBackgroundColor);
    final bool hasBottom = bottom != null && bottom.isNotEmpty;
    final bool hasLeading = leading != null || showBackButton;

    final EdgeInsetsGeometry resolvedPadding = contentPadding ??
        EdgeInsetsDirectional.only(
          start: hasLeading ? 16 : 24,
          end: actions?.isNotEmpty == true ? 16 : 24,
          top: 8,
          bottom: 8,
        );

    final double? resolvedBottomHeight = hasBottom
        ? (bottomHeight != null && bottomHeight > 0 ? bottomHeight : null)
        : null;

    Widget? resolvedLeading;
    if (leading != null) {
      resolvedLeading = leading;
    } else if (showBackButton) {
    final ui.TextDirection textDirection = Directionality.of(context);
      resolvedLeading = _AppBarBackButton(
        onPressed: onBackPress ?? () => Navigator.of(context).maybePop(),
        foregroundColor: resolvedForegroundColor,
        backgroundColor: backButtonBackgroundColor,
        isRtl: textDirection == ui.TextDirection.rtl,
      );
    }

    final List<Widget>? trailingActions = actions?.isNotEmpty == true
        ? _withSpacing(actions!, const SizedBox(width: 12))
        : null;

    final TextStyle defaultTitleStyle = theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: actions?.isNotEmpty == true ? 17 : 21,
          letterSpacing: 0.2,
          color: resolvedForegroundColor,
        ) ??
        TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: actions?.isNotEmpty == true ? 17 : 21,
          letterSpacing: 0.2,
          color: resolvedForegroundColor,
        );

    final TextStyle subtitleTextStyle = theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w400,
          fontSize: 13,
          letterSpacing: 0.15,
          color: resolvedForegroundColor.withOpacity(0.7),
        ) ??
        TextStyle(
          fontWeight: FontWeight.w400,
          fontSize: 13,
          letterSpacing: 0.15,
          color: resolvedForegroundColor.withOpacity(0.7),
        );

    final Widget? subtitleContent = subtitleWidget ??
        (normalizedSubtitle != null
            ? Text(
                normalizedSubtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null);

    final Widget? resolvedSubtitle = subtitleContent != null
        ? DefaultTextStyle.merge(
            style: subtitleTextStyle,
            child: subtitleContent,
          )
        : null;

    Widget? resolvedTitle;
    if (titleWidget != null) {
      resolvedTitle = titleWidget;
    } else if (normalizedTitle != null || resolvedSubtitle != null) {
      resolvedTitle = _AppBarTitleSection(
        title: normalizedTitle,
        subtitle: resolvedSubtitle,
        center: centerTitle,
      );
    }

    final BorderRadius borderRadiusShape = BorderRadius.only(
      topLeft:
          shouldHideTopBorder ? Radius.zero : Radius.circular(borderRadius),
      topRight:
          shouldHideTopBorder ? Radius.zero : Radius.circular(borderRadius),
      bottomLeft: Radius.circular(borderRadius),
      bottomRight: Radius.circular(borderRadius),
    );

    final BorderSide defaultBorderSide = BorderSide(
      color: resolvedBorderColor.withOpacity(0.85),
      width: borderStrokeWidth,
    );

    final Border border = Border(
      top: shouldHideTopBorder ? BorderSide.none : defaultBorderSide,
      left: defaultBorderSide,
      right: defaultBorderSide,
      bottom: defaultBorderSide,
    );

    final bool isDarkMode = theme.brightness == Brightness.dark;
    final Color accentColor = colorScheme.headingAccentColor;
    final Color gradientEnd =
        Color.lerp(resolvedBackgroundColor, accentColor, isDarkMode ? 0.18 : 0.28) ??
            resolvedBackgroundColor;

    final LinearGradient backgroundGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        resolvedBackgroundColor.withOpacity(isDarkMode ? 0.88 : 0.96),
        gradientEnd.withOpacity(isDarkMode ? 0.72 : 0.86),
      ],
    );

    final Color resolvedStatusBarColor =
        statusBarColor ?? backgroundGradient.colors.first;
    final SystemUiOverlayStyle statusBarStyle = getSystemUiOverlayStyle(
      context: context,
      statusBarColor: resolvedStatusBarColor,
    );

    final Color shadowColor =
        (isDarkMode ? Colors.black : Colors.black.withOpacity(0.35))
            .withOpacity(isDarkMode ? 0.32 : 0.16);

    final double topPadding = MediaQuery.of(context).padding.top;
    final double totalHeight =
        toolbarHeight + (resolvedBottomHeight ?? 0.0) + topPadding;

    return PreferredSize(
      preferredSize: Size.fromHeight(totalHeight),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: statusBarStyle,
        sized: true,
        child: SizedBox(
        height: totalHeight,
        child: Material(
          color: Colors.transparent,
          child: SafeArea(
            top: true,
            bottom: false,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: borderRadiusShape,
                boxShadow: [
                  BoxShadow(
                    color: shadowColor,
                    blurRadius: 26,
                    offset: const Offset(0, 14),
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: borderRadiusShape,
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: backgroundGradient,
                      border: border,
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withOpacity(
                                      isDarkMode ? 0.02 : 0.14),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            height: 2,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  accentColor.withOpacity(
                                      isDarkMode ? 0.28 : 0.18),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                        IconTheme.merge(
                          data: IconThemeData(
                            color: resolvedForegroundColor,
                            size: 22,
                          ),
                          child: DefaultTextStyle(
                            style: defaultTitleStyle,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  height: toolbarHeight,
                                  child: Padding(
                                    padding: resolvedPadding,
                                    child: NavigationToolbar(
                                      leading: resolvedLeading != null
                                          ? Padding(
                                              padding:
                                                  const EdgeInsetsDirectional
                                                      .only(end: 12),
                                              child: resolvedLeading,
                                            )
                                          : null,
                                      middle: resolvedTitle,
                                      trailing: trailingActions != null
                                          ? Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: trailingActions,
                                            )
                                          : null,
                                      centerMiddle: centerTitle,
                                    ),
                                  ),
                                ),
                                if (hasBottom) ...[
                                  Divider(
                                    height: 1,
                                    thickness: 1,
                                    indent: 20,
                                    endIndent: 20,
                                    color: resolvedBorderColor
                                        .withOpacity(isDarkMode ? 0.28 : 0.15),
                                  ),
                                  _AppBarBottomSection(
                                    children: bottom!,
                                    height: resolvedBottomHeight,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }

  static List<Widget> _withSpacing(List<Widget> widgets, Widget spacer) {
    if (widgets.length <= 1) {
      return List<Widget>.from(widgets);
    }

    final List<Widget> spaced = [];
    for (var i = 0; i < widgets.length; i++) {
      if (i > 0) {
        spaced.add(spacer);
      }
      spaced.add(widgets[i]);
    }
    return spaced;
  }

  /// ويدجت عام لتطبيق تأثير الضغط المائي (Ripple Effect) في جميع أنحاء التطبيق.
  ///
  /// ✅ يستخدم `InkWell` داخل `Material` لتوفير تأثير الضغط.
  /// ✅ مناسب للأزرار أو أي عنصر قابل للنقر.
  ///
  /// [child]: الودجت الداخلي.
  /// [onTap]: الدالة التي يتم تنفيذها عند النقر.
  /// [borderRadius]: لتحديد شكل الحواف (اختياري).
  /// [splashColor]: لتغيير لون تأثير الضغط (اختياري).

  static Widget ripple({
    required Widget child,
    required VoidCallback? onTap,
    BorderRadius? borderRadius,
    Color? splashColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: splashColor,
        borderRadius: borderRadius ?? BorderRadius.circular(12),
        child: child,
      ),
    );
  }

  static checkUser(
      {required Function() onNotGuest, required BuildContext context}) {
    if (!HiveUtils.isUserAuthenticated()) {
      _loginBox(context);
    } else {
      onNotGuest.call();
    }
  }

  // رسالة الزائر
  // تعرض Bottom Sheet (نافذة منبثقة من أسفل الشاشة).
  // تخبر المستخدم أن تسجيل الدخول ضروري للوصول لبعض الميزات

  static void _loginBox(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // لعمل خلفية شفافة مع زوايا مدورة
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 24,
            left: 24,
            right: 24,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "loginIsRequiredForAccessingThisFeatures".translate(context),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              SizedBox(height: 8),
              Text(
                "tapOnLoginToAuthorize".translate(context),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(
                      context,
                      Routes.login,
                      arguments: {"popToCurrent": true},
                    );
                  },
                  child: Text(
                    "loginNow".translate(context),
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  static String getTranslatedLabel(BuildContext context, String labelKey) {
    return (AppLocalization.of(context)!.getTranslatedValues(labelKey) ??
            labelKey)
        .trim();
  }

  static Map<String, double> getWidgetInfo(
      BuildContext context, GlobalKey key) {
    final RenderBox renderBox =
        key.currentContext?.findRenderObject() as RenderBox;

    final Size size = renderBox.size; // or _widgetKey.currentContext?.size

    final Offset offset = renderBox.localToGlobal(Offset.zero);

    return {
      "x": (offset.dx),
      "y": (offset.dy),
      "width": size.width,
      "height": size.height,
      "offX": offset.dx,
      "offY": offset.dy
    };
  }

  static Locale getLocaleFromLanguageCode(String languageCode) {
    List<String> result = languageCode.split("-");
    return result.length == 1
        ? Locale(result.first)
        : Locale(result.first, result.last);
  }

  static Widget getDivider() {
    return const Divider(
      endIndent: 0,
      indent: 0,
    );
  }

  static Widget getSvgImage(String url,
      {double? width,
      double? height,
      BoxFit? fit,
      String? blurHash,
      bool? showFullScreenImage,
      Color? color}) {
    return SvgPicture.network(
      url,
      colorFilter:
          color != null ? ColorFilter.mode(color, BlendMode.srcIn) : null,
      width: width,
      height: height,
      fit: fit!,
      placeholderBuilder: (context) {
        return ShimmerBox(
          width: width,
          height: height,
          borderRadius: BorderRadius.circular(12),
        );
      },
    );
  }

  static const int _defaultCacheDimension = 200;
  static const int _minCacheDimension = 160;
  static const int _maxCacheDimension = 240;
  static final RegExp _preferredThumbnailExtension =
      RegExp(r'\.(avif|webp)(?:\?|#|\b)', caseSensitive: false);

  static Widget getImage(
    String url, {
    double? width,
    double? height,
    BoxFit? fit,
    String? blurHash,
    bool? showFullScreenImage,
    String? fallbackUrl,
    List<String>? alternateUrls,
    int? cacheWidth,
    int? cacheHeight,
  }) {
    final List<String> candidates = _prepareImageCandidates(
      primary: url,
      alternates: alternateUrls,
      fallback: fallbackUrl,
    );

    final int resolvedCacheWidth = _resolveCacheDimension(cacheWidth);
    final int resolvedCacheHeight = _resolveCacheDimension(cacheHeight);

    return _AdaptiveNetworkImage(
      urls: candidates,
      width: width,
      height: height,
      fit: fit ?? BoxFit.cover,
      cacheWidth: resolvedCacheWidth,
      cacheHeight: resolvedCacheHeight,
    );
  }

  static List<String> _prepareImageCandidates({
    String? primary,
    List<String>? alternates,
    String? fallback,
  }) {
    final ordered = <String?>[primary, ...?alternates, fallback];
    final filtered = ordered
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();

    final LinkedHashSet<String> deduplicated =
        LinkedHashSet<String>.from(filtered);
    final List<String> urls = deduplicated.toList();
    if (urls.length <= 1) {
      return urls;
    }

    final List<String> preferred = [];
    final List<String> others = [];
    for (final url in urls) {
      if (_isPreferredThumbnailFormat(url)) {
        preferred.add(url);
      } else {
        others.add(url);
      }
    }
    return [...preferred, ...others];
  }

  static bool _isPreferredThumbnailFormat(String url) {
    return _preferredThumbnailExtension.hasMatch(url);
  }

  static int _resolveCacheDimension(int? dimension) {
    final int resolved = dimension ?? _defaultCacheDimension;
    if (resolved < _minCacheDimension) return _minCacheDimension;
    if (resolved > _maxCacheDimension) return _maxCacheDimension;
    return resolved;
  }

  static Widget _buildImagePlaceholder(
    BuildContext context,
    double? width,
    double? height, {
    BorderRadius? borderRadius,
    bool animate = true,
  }) {
    return ShimmerBox(
      width: width,
      height: height,
      borderRadius: borderRadius ?? BorderRadius.circular(12),
      animate: animate,
    );
  }

  static Widget _buildImageError(
      BuildContext context, double? width, double? height) {
    return _buildImagePlaceholder(
      context,
      width,
      height,
      animate: false,
    );
  }

  static Widget progress({
    double? width,
    double? height,
    Color? normalProgressColor,
    bool? showWhite,
  }) {
    if (Constant.useLottieProgress) {
      return LottieBuilder.asset(
        "assets/lottie/${showWhite == true ? Constant.progressLottieFileWhite : Constant.loadingSuccessLottieFile}",
        width: width ?? 70,
        height: height ?? 70,
        delegates: const LottieDelegates(values: []),
      );
    } else {
      const double defaultDimension = 36;
      final double resolvedWidth = width ?? defaultDimension;
      final double resolvedHeight = height ?? defaultDimension;
      final double indicatorSize = max(0.0, min(resolvedWidth, resolvedHeight));
      final double resolvedStrokeWidth =
          indicatorSize >= defaultDimension ? 4.0 : max(2.0, indicatorSize / 6);

      return SizedBox(
        width: resolvedWidth,
        height: resolvedHeight,
        child: Center(
          child: SizedBox(
            width: indicatorSize,
            height: indicatorSize,
            child: CircularProgressIndicator(
              strokeWidth: resolvedStrokeWidth,
              valueColor: normalProgressColor != null
                  ? AlwaysStoppedAnimation<Color?>(normalProgressColor)
                  : null,
            ),
          ),
        ),
      );
    }
  }

  ///Divider / Container

  static SystemUiOverlayStyle getSystemUiOverlayStyle(
      {required BuildContext context, required Color statusBarColor}) {
    return SystemUiOverlayStyle(
        systemNavigationBarDividerColor: Colors.transparent,
        // systemNavigationBarColor: Theme.of(context).colorScheme.secondaryColor,
        systemNavigationBarIconBrightness:
            context.watch<AppThemeCubit>().state.appTheme == AppTheme.dark
                ? Brightness.light
                : Brightness.dark,
        //
        statusBarColor: statusBarColor,
        statusBarBrightness:
            context.watch<AppThemeCubit>().state.appTheme == AppTheme.dark
                ? Brightness.dark
                : Brightness.light,
        statusBarIconBrightness:
            context.watch<AppThemeCubit>().state.appTheme == AppTheme.dark
                ? Brightness.light
                : Brightness.dark);
  }

  static setDefaultLocationValue(
      {required bool isCurrent,
      required bool isHomeUpdate,
      required BuildContext context}) {
    if (isCurrent) {
      HiveUtils.setCurrentLocation(
          area: null,
          city: "",
          state: "",
          country: "Yemen",
          latitude: 15.3694,
          longitude: 44.1910);
    } else {
      HiveUtils.setCurrentLocation(
          area: null,
          city: "",
          state: "",
          country: "Yemen",
          latitude: 15.3694,
          longitude: 44.1910);
    }
    if (isHomeUpdate) {
      Future.delayed(
        Duration.zero,
        () {
          context.read<FetchHomeScreenCubit>().fetch(
                city: "Bhuj",
              );
          context
              .read<FetchHomeAllItemsCubit>()
              .fetch(city: "Bhuj", radius: HiveUtils.getNearbyRadius());
        },
      );
    }
  }

  static Color makeColorDark(Color color) {
    Color color0 = color;

    int red = color0.red - 10;
    int green = color0.green - 10;
    int blue = color0.blue - 10;

    return Color.fromARGB(color0.alpha, red.clamp(0, 255), green.clamp(0, 255),
        blue.clamp(0, 255));
  }

  static Color makeColorLight(Color color) {
    Color color0 = color;

    int red = color0.red + 10;
    int green = color0.green + 10;
    int blue = color0.blue + 10;

    return Color.fromARGB(color0.alpha, red.clamp(0, 255), green.clamp(0, 255),
        blue.clamp(0, 255));
  }

  static Widget buildButton(
    BuildContext context, {
    double? height,
    double? width,
    BorderSide? border,
    String? titleWhenProgress,
    bool? isInProgress,
    bool? isSuccess,
    bool? isError,
    double? fontSize,
    double? radius,
    bool? autoWidth,
    Widget? prefixWidget,
    EdgeInsetsGeometry? padding,
    required FutureOr<void> Function() onPressed,
    required String buttonTitle,
    bool? showProgressTitle,
    double? progressWidth,
    double? progressHeight,
    bool? showElevation,
    Color? textColor,
    Color? buttonColor,
    EdgeInsets? outerPadding,
    Color? disabledColor,
    Color? disabledTextColor,
    VoidCallback? onTapDisabledButton,
    bool? disabled,
    bool autoManageState = true,
    bool autoDisableWhenInvalid = true,
    List<TextEditingController>? requiredTextControllers,
    List<ValueListenable<bool>>? enableConditions,
  }) {
    assert(() {
      debugPrint('UiUtils.buildButton v4');
      return true;
    }());

    return _UiSmartButton(
      height: height,
      width: width,
      border: border,
      titleWhenProgress: titleWhenProgress,
      isInProgress: isInProgress,
      isSuccess: isSuccess,
      isError: isError,
      fontSize: fontSize,
      radius: radius,
      autoWidth: autoWidth,
      prefixWidget: prefixWidget,
      padding: padding,
      onPressed: onPressed,
      buttonTitle: buttonTitle,
      showProgressTitle: showProgressTitle,
      progressWidth: progressWidth,
      progressHeight: progressHeight,
      showElevation: showElevation,
      textColor: textColor,
      buttonColor: buttonColor,
      outerPadding: outerPadding,
      disabledColor: disabledColor,
      disabledTextColor: disabledTextColor,
      onTapDisabledButton: onTapDisabledButton,
      disabled: disabled,
      autoManageState: autoManageState,
      autoDisableWhenInvalid: autoDisableWhenInvalid,
      requiredTextControllers: requiredTextControllers,
      enableConditions: enableConditions,
    );
  }

  static NetworkToLocalSvg networkToLocalSvg = NetworkToLocalSvg();

  static Widget imageType(String url,
      {double? width, double? height, BoxFit? fit, Color? color}) {
    String? extension = mime(url);

    if (extension == "image/svg+xml") {
      return getSvgImage(
        url,
        fit: fit,
        height: height,
        width: width,
        color: color,
      );
    } else {
      return getImage(
        url,
        fit: fit,
        height: height,
        width: width,
      );
    }
  }

  static void showFullScreenImage(BuildContext context,
      {required ImageProvider provider, VoidCallback? then}) {
    Navigator.of(context)
        .push(AppPageRoute.build(
          builder: (BuildContext context) => FullScreenImageView(
            provider: provider,
          ),
          barrierDismissible: true,
          barrierColor: Colors.black.withOpacity(0.3),
          motionPattern: AppMotionPattern.glide,
        ))
        .then((value) {
      then?.call();
    });
  }

  static Future<T?> openBottomSheet<T>({
    required BuildContext context,
    Widget? body,
    WidgetBuilder? bodyBuilder,
    Widget? footer,
    WidgetBuilder? footerBuilder,
    WidgetBuilder? headerBuilder,
    String? title,
    TextStyle? titleStyle,
    String? subtitle,
    TextStyle? subtitleStyle,
    String? description,
    TextStyle? descriptionStyle,
    bool showHandle = true,
    bool showCloseButton = true,
    bool enableDrag = true,
    bool isDismissible = true,
    bool useSafeArea = true,
    bool expandBody = false,
    bool showDivider = true,
    double borderRadius = 28,
    Color? backgroundColor,
    EdgeInsetsGeometry headerPadding =
        const EdgeInsets.fromLTRB(20, 16, 20, 12),
    EdgeInsetsGeometry safeAreaMinimum = EdgeInsets.zero,
    VoidCallback? onClosePressed,
    String closeTooltip = 'إغلاق',
    Widget? closeIcon,
    Color? closeButtonBackgroundColor,
    Color? closeIconColor,
    Color? handleColor,
  }) {
    assert(body != null || bodyBuilder != null,
        'Either body or bodyBuilder must be provided.');

    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: useSafeArea,
      backgroundColor: Colors.transparent,
      enableDrag: enableDrag,
      isDismissible: isDismissible,
      builder: (sheetContext) {
        final resolvedBody = bodyBuilder?.call(sheetContext) ?? body!;
        final resolvedFooter = footerBuilder?.call(sheetContext) ?? footer;

        Widget headerContent;
        if (headerBuilder != null) {
          headerContent = headerBuilder(sheetContext);
        } else {
          headerContent = _buildDefaultBottomSheetHeaderContent(
            sheetContext: sheetContext,
            title: title,
            titleStyle: titleStyle,
            subtitle: subtitle,
            subtitleStyle: subtitleStyle,
            description: description,
            descriptionStyle: descriptionStyle,
          );
        }

        final closeAction = showCloseButton
            ? (onClosePressed ?? () => Navigator.of(sheetContext).maybePop())
            : null;

        return StandardBottomSheetScaffold(
          header: StandardBottomSheetHeader(
            showHandle: showHandle,
            showCloseButton: showCloseButton,
            onClosePressed: closeAction,
            closeTooltip: closeTooltip,
            closeIcon: closeIcon,
            closeButtonBackgroundColor: closeButtonBackgroundColor,
            closeIconColor: closeIconColor,
            handleColor: handleColor,
            padding: headerPadding,
            content: headerContent,
          ),
          body: resolvedBody,
          footer: resolvedFooter,
          backgroundColor: backgroundColor,
          borderRadius: borderRadius,
          showDivider: showDivider,
          expandBody: expandBody,
          useSafeArea: useSafeArea,
          safeAreaMinimum: safeAreaMinimum,
        );
      },
    );
  }

  static Widget _buildDefaultBottomSheetHeaderContent({
    required BuildContext sheetContext,
    String? title,
    TextStyle? titleStyle,
    String? subtitle,
    TextStyle? subtitleStyle,
    String? description,
    TextStyle? descriptionStyle,
  }) {
    final theme = Theme.of(sheetContext);
    final onSurface = theme.colorScheme.onSurface;

    final resolvedTitleStyle = titleStyle ??
        TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: onSurface,
        );

    final resolvedSubtitleStyle = subtitleStyle ??
        TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: onSurface.withOpacity(.7),
        );

    final resolvedDescriptionStyle = descriptionStyle ??
        TextStyle(
          fontSize: 12,
          height: 1.4,
          color: onSurface.withOpacity(.6),
        );

    final contentChildren = <Widget>[];

    if (title != null && title.trim().isNotEmpty) {
      contentChildren.add(Text(title, style: resolvedTitleStyle));
    }

    if (subtitle != null && subtitle.trim().isNotEmpty) {
      if (contentChildren.isNotEmpty) {
        contentChildren.add(const SizedBox(height: 6));
      }
      contentChildren.add(Text(subtitle, style: resolvedSubtitleStyle));
    }

    if (description != null && description.trim().isNotEmpty) {
      if (contentChildren.isNotEmpty) {
        contentChildren.add(const SizedBox(height: 4));
      }
      contentChildren.add(Text(description, style: resolvedDescriptionStyle));
    }

    if (contentChildren.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: contentChildren,
    );
  }

  // عرض نافذة حوار (Dialog) منبثقة للمستخدم في حال عدم وجود باقة متاحة (مثل اشتراك أو خطة).

  static void noPackageAvailableDialog(
    BuildContext context, {
    SubscriptionPackageLimit? limit,
  }) async {
    UiUtils.showBlurredDialoge(
      context,
      dialoge: BlurredDialogBox(
        title: 'noPackage'.translate(context),
        acceptButtonName: 'subscribe'.translate(context),
        cancelButtonName: 'cancelLbl'.translate(context),
        acceptButtonColor: context.color.territoryColor,
        acceptTextColor: context.color.secondaryColor,
        content: StatefulBuilder(builder: (context, update) {
          final theme = Theme.of(context);
          final textTheme = theme.textTheme;
          final children = <Widget>[
            Text('plsSubscribe'.translate(context)),
          ];

          if (limit != null) {
            final blockedLabel =
                getTranslatedLabel(context, 'subscriptionLimitActionBlocked');
            if (blockedLabel.trim().isNotEmpty) {
              children.add(const SizedBox(height: 12));
              children.add(
                Text(
                  blockedLabel,
                  style: textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }

            final summary =
                subscriptionLimitSummary(context, limit, includeExpiry: false);
            if (summary != null && summary.isNotEmpty) {
              children.add(const SizedBox(height: 8));
              children.add(
                Text(
                  summary,
                  style: textTheme.bodyMedium,
                ),
              );
            }

            final expiry = subscriptionLimitExpiry(context, limit);
            if (expiry != null && expiry.isNotEmpty) {
              children.add(const SizedBox(height: 4));
              children.add(
                Text(
                  expiry,
                  style: textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              );
            }
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          );
        }),
        isAcceptContainesPush: false,
        onAccept: () async {
          Future.delayed(Duration(seconds: 1), () {
            Navigator.pushNamed(context, Routes.subscriptionPackageListRoute);
          });
        },
      ),
    );
  }

  static void imageGallaryView(BuildContext context,
      {required List images, VoidCallback? then, required int initalIndex}) {
    Navigator.push(
      context,
      AppPageRoute.build(
        builder: (context) => GalleryView(
          images: images.cast<String>(), // ✅ تحويل القائمة لنوع String
          initialIndex: initalIndex,
        ),
        motionPattern: AppMotionPattern.glide,
      ),
    );
  }

// وظيفتها عرض نافذة حوار (Dialog) مع تأثير ضبابي (Blur) خلفها،

  static Future showBlurredDialoge(
    BuildContext context, {
    required BlurDialoge dialoge,
    AxisDirection? axisDirection,
    Offset? entryOffset,
    double? barrierOpacity,
  }) async {
    return await Navigator.push(
      context,
      AppPageRoute.build(
        builder: (context) {
          if (dialoge is Widget) return dialoge as Widget;
          return const SizedBox.shrink();
        },
        barrierDismissible: true,
        barrierColor: Colors.black.withOpacity(barrierOpacity ?? 0.2),
        motionPattern: AppMotionPattern.glide,
      ),
    );
  }

//AAA is color theory's point it means if color is AAA then it will be perfect for your app
  static bool isColorMatchAAA(Color textColor, Color background) {
    double contrastRatio = (textColor.computeLuminance() + 0.05) /
        (background.computeLuminance() + 0.05);
    if (contrastRatio < 4.5) {
      return false;
    } else {
      return true;
    }
  }

  static double getRadiansFromDegree(double radians) {
    return radians * 180 / pi;
  }

  static Color getAdaptiveTextColor(Color color) {
    int d = 0;

// Counting the perceptive luminance - human eye favors green color...
    double luminance =
        (0.299 * color.red + 0.587 * color.green + 0.114 * color.blue) / 255;

    if (luminance > 0.5) {
      d = 0;
    } else {
      d = 255;
    } // dark colors - white font

    return Color.fromARGB(color.alpha, d, d, d);
  }

  static String formatTimeWithDateTime(DateTime dateTime, {bool is24 = true}) {
    if (is24) {
      return DateFormat("kk:mm").format(dateTime);
    } else {
      return DateFormat("hh:mm a").format(dateTime);
    }
  }

  static String time24to12hour(String time24) {
    DateTime tempDate = DateFormat("hh:mm").parse(time24);
    var dateFormat = DateFormat("h:mm a");
    return dateFormat.format(tempDate);
  }

  static String monthYearDate(String date) {
    DateTime dateTime = DateTime.parse(date);

    // Format the date into "MMMM yyyy" (i.e., April 2024)
    return DateFormat('MMMM yyyy').format(dateTime);
  }
}

class _AppBarBackButton extends StatelessWidget {
  const _AppBarBackButton({
    required this.onPressed,
    required this.foregroundColor,
    this.backgroundColor,
    required this.isRtl,
  });

  final VoidCallback onPressed;
  final Color foregroundColor;
  final Color? backgroundColor;
  final bool isRtl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final BorderRadius radius = BorderRadius.circular(12);
    final IconData icon = isRtl
        ? Icons.arrow_forward_ios_rounded
        : Icons.arrow_back_ios_new_rounded;
    final String tooltip = MaterialLocalizations.of(context).backButtonTooltip;
    final Color resolvedBackgroundColor =
        backgroundColor ?? theme.colorScheme.surfaceVariant;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: InkWell(
          onTap: onPressed,
          borderRadius: radius,
          child: Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: resolvedBackgroundColor,
              borderRadius: radius,
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              color: foregroundColor,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

class _AppBarTitleSection extends StatelessWidget {
  const _AppBarTitleSection({
    required this.title,
    required this.subtitle,
    required this.center,
  });

  final String? title;
  final Widget? subtitle;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = [];

    if (title != null) {
      children.add(
        Text(
          title!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    if (subtitle != null) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: 4));
      }
      children.add(
        AnimatedOpacity(
          opacity: 1,
          duration: const Duration(milliseconds: 220),
          child: subtitle!,
        ),
      );
    }

    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: center
          ? Alignment.center
          : AlignmentDirectional.centerStart,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

///Format string
extension FormatAmount on String {
  String formatAmount({bool prefix = false}) {
    return (prefix)
        ? "${Constant.currencySymbol}${toString()}"
        : "${toString()}${Constant.currencySymbol}"; // \u{20B9}"; //currencySymbol
  }

  String formatPercentage() {
    return "${toString()} %";
  }

  String formatId() {
    return " # ${toString()} "; // \u{20B9}"; //currencySymbol
  }

  String firstUpperCase() {
    String upperCase = "";
    var suffix = "";
    if (isNotEmpty) {
      upperCase = this[0].toUpperCase();
      suffix = substring(1, length);
    }
    return (upperCase + suffix);
  }
}

// دالة اخرى للتحكم في الوقت والتاريخ

// دالة موحّدة: إن مرّرت format تستخدمه، وإلا ترجع صيغة عربية ذكية "قبل X ..."
extension FormatDate on String {
  String formatDate({String? format, String locale = 'ar'}) {
    try {
      final date = DateTime.parse(this);
      // لو حدّدت فورمات صريح، نستخدمه (توافق مع الاستدعاءات القديمة)
      if (format != null && format.isNotEmpty) {
        return DateFormat(format, locale).format(date);
      }

      // سلوك عربي ذكي عند عدم تحديد format
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays < 0) {
        // التاريخ في المستقبل
        return _formatFullDate(date, locale);
      }

      if (difference.inDays == 0) {
        if (difference.inMinutes < 1) {
          return "الآن";
        } else if (difference.inHours < 1) {
          return "قبل ${_convertToArabicNumbers(difference.inMinutes)} دقيقة";
        } else {
          return "قبل ${_convertToArabicNumbers(difference.inHours)} ساعة";
        }
      }

      if (difference.inDays == 1) return "قبل يوم";
      if (difference.inDays == 2) return "قبل يومين";
      if (difference.inDays <= 30) {
        return "قبل ${_convertToArabicNumbers(difference.inDays)} يوم";
      }

      // أكثر من 30 يوم → صيغة كاملة
      return _formatFullDate(date, locale);
    } catch (_) {
      return "";
    }
  }

  String _formatFullDate(DateTime date, String locale) {
    return DateFormat("d  MMMM،  y", locale).format(date);
  }

  String _convertToArabicNumbers(int number) {
    final arabicNumbers = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return number
        .toString()
        .split('')
        .map((c) => arabicNumbers[int.parse(c)])
        .join();
  }
}

//scroll controller extenstion

extension ScrollEndListen on ScrollController {
  ///It will check if scroll is at the bottom or not
  bool isEndReached() {
    if (offset >= position.maxScrollExtent) {
      return true;
    }
    return false;
  }
}

class RemoveGlow extends ScrollBehavior {
  const RemoveGlow();

  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
  }
}

class RoundedBorderOnSomeSidesWidget extends StatelessWidget {
  /// Color of the content behind this widget
  final Color contentBackgroundColor;
  final Color borderColor;
  final Widget child;

  final double borderRadius;
  final double borderWidth;

  /// The sides where we want the rounded border to be
  final bool topLeft;
  final bool topRight;
  final bool bottomLeft;
  final bool bottomRight;

  const RoundedBorderOnSomeSidesWidget({
    super.key,
    required this.borderColor,
    required this.contentBackgroundColor,
    required this.child,
    required this.borderRadius,
    required this.borderWidth,
    this.topLeft = false,
    this.topRight = false,
    this.bottomLeft = false,
    this.bottomRight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: borderColor,
        borderRadius: BorderRadius.only(
          topLeft: topLeft ? Radius.circular(borderRadius) : Radius.zero,
          topRight: topRight ? Radius.circular(borderRadius) : Radius.zero,
          bottomLeft: bottomLeft ? Radius.circular(borderRadius) : Radius.zero,
          bottomRight:
              bottomRight ? Radius.circular(borderRadius) : Radius.zero,
        ),
      ),
      child: Container(
        margin: EdgeInsetsDirectional.only(
          top: topLeft || topRight ? borderWidth : 0,
          start: topLeft || bottomLeft ? borderWidth : 0,
          bottom: bottomLeft || bottomRight ? borderWidth : 0,
          end: topRight || bottomRight ? borderWidth : 0,
        ),
        decoration: BoxDecoration(
          color: contentBackgroundColor,
          borderRadius: BorderRadius.only(
            topLeft: topLeft
                ? Radius.circular(borderRadius - borderWidth)
                : Radius.zero,
            topRight: topRight
                ? Radius.circular(borderRadius - borderWidth)
                : Radius.zero,
            bottomLeft: bottomLeft
                ? Radius.circular(borderRadius - borderWidth)
                : Radius.zero,
            bottomRight: bottomRight
                ? Radius.circular(borderRadius - borderWidth)
                : Radius.zero,
          ),
        ),
        child: child,
      ),
    );
  }
}

class _SoftSnackBarWidget extends StatefulWidget {
  const _SoftSnackBarWidget({
    super.key,
    required this.message,
    required this.iconPath,
    required this.duration,
    required this.backgroundColor,
    required this.textColor,
    required this.fontSize,
    required this.fontWeight,
    required this.onFinish,
  });

  final String message;
  final String iconPath;
  final Duration duration;
  final Color backgroundColor;
  final Color textColor;
  final double fontSize;
  final FontWeight fontWeight;
  final VoidCallback onFinish;

  @override
  State<_SoftSnackBarWidget> createState() => _SoftSnackBarWidgetState();
}

class _SoftSnackBarWidgetState extends State<_SoftSnackBarWidget>
    with SingleTickerProviderStateMixin {
  static const Duration _animationDuration = Duration(milliseconds: 250);

  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  Timer? _autoDismissTimer;
  Completer<void>? _dismissCompleter;
  bool _hasCompletedExit = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _animationDuration,
      reverseDuration: _animationDuration,
    );

    final Animation<double> curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );

    _fadeAnimation = curved;
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(curved);

    _controller.addStatusListener(_handleStatusChange);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _controller.forward();
      _autoDismissTimer = Timer(widget.duration, dismiss);
    });
  }

  void _handleStatusChange(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _hasCompletedExit = false;
      return;
    }

    if (status == AnimationStatus.dismissed && !_hasCompletedExit) {
      _hasCompletedExit = true;
      widget.onFinish();
      if (_dismissCompleter != null && !_dismissCompleter!.isCompleted) {
        _dismissCompleter!.complete();
      }
      _dismissCompleter = null;
    }
  }

  Future<void> dismiss() {
    if (!mounted) {
      return Future.value();
    }

    if (_hasCompletedExit) {
      return _dismissCompleter?.future ?? Future.value();
    }

    _autoDismissTimer?.cancel();
    _dismissCompleter ??= Completer<void>();

    if (_controller.status == AnimationStatus.dismissed ||
        _controller.value == 0.0) {
      if (!_dismissCompleter!.isCompleted) {
        _dismissCompleter!.complete();
      }
      return _dismissCompleter!.future;
    }

    if (_controller.status != AnimationStatus.reverse) {
      _controller.reverse();
    }

    return _dismissCompleter!.future;
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _controller.removeStatusListener(_handleStatusChange);
    _controller.dispose();
    if (_dismissCompleter != null && !_dismissCompleter!.isCompleted) {
      _dismissCompleter!.complete();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 80,
      left: 0,
      right: 0,
      child: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                dismiss();
              },
              child: Material(
                color: Colors.transparent,
                child: IntrinsicWidth(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: widget.backgroundColor,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(100),
                          child: Image.asset(
                            widget.iconPath,
                            width: 30,
                            height: 30,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            widget.message,
                            style: TextStyle(
                              color: widget.textColor,
                              fontSize: widget.fontSize,
                              fontWeight: widget.fontWeight,
                            ),
                            textAlign: TextAlign.start,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SoftSnackBarHandle {
  const _SoftSnackBarHandle({
    required this.entry,
    required this.key,
  });

  final OverlayEntry entry;
  final GlobalKey<_SoftSnackBarWidgetState> key;
}

// لو BlurDialoge معرفة عندك في ملف ثاني، تأكد من import لها
// import 'package:marib/ui/screens/widgets/blurred_dialoge_box.dart';

class BlurredRichDialog extends StatelessWidget implements BlurDialoge {
  const BlurredRichDialog({
    super.key,
    this.title,
    required this.body,
    this.actions = const [],
    this.icon,
    this.maxWidth = 560,
    this.maxHeightFraction = .6,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  });

  final String? title;
  final String body;
  final List<BlurredAction> actions;
  final IconData? icon;
  final double maxWidth;
  final double maxHeightFraction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final maxH = MediaQuery.of(context).size.height * maxHeightFraction;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Material(
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: scheme.surface.withOpacity(
                      theme.brightness == Brightness.dark ? 0.25 : 0.35),
                  border: Border.all(color: scheme.onSurface.withOpacity(0.06)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 18,
                        offset: const Offset(0, 10))
                  ],
                ),
                child: SafeArea(
                  minimum: const EdgeInsets.all(12),
                  child: Padding(
                    padding: padding,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (icon != null)
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                    color: scheme.primary.withOpacity(0.12),
                                    shape: BoxShape.circle),
                                child: Icon(icon, color: scheme.primary),
                              ),
                            if (icon != null) const SizedBox(width: 12),
                            if (title != null)
                              Expanded(
                                child: Text(
                                  title!,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                      color: scheme.onSurface,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                            IconButton(
                              tooltip: MaterialLocalizations.of(context)
                                  .closeButtonTooltip,
                              onPressed: () => Navigator.of(context).maybePop(),
                              icon: Icon(Icons.close_rounded,
                                  color: scheme.onSurface.withOpacity(0.65)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: maxH),
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: SelectableText.rich(
                              _linkify(
                                body,
                                normal: theme.textTheme.bodyMedium?.copyWith(
                                    color: scheme.onSurface.withOpacity(0.9),
                                    height: 1.5),
                                link: theme.textTheme.bodyMedium?.copyWith(
                                    color: scheme.primary,
                                    decoration: TextDecoration.underline,
                                    height: 1.5),
                                onOpenLink: (url) async {
                                  // افتح الرابط بالطريقة المناسبة لمشروعك
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (actions.isNotEmpty)
                          Wrap(
                            spacing: 10,
                            children: actions.map((a) {
                              return ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  elevation: 0,
                                  backgroundColor: a.isPrimary
                                      ? scheme.primary
                                      : scheme.surface,
                                  foregroundColor: a.isPrimary
                                      ? scheme.onPrimary
                                      : scheme.onSurface,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: a.onPressed,
                                child: Text(a.label),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  TextSpan _linkify(
    String input, {
    TextStyle? normal,
    TextStyle? link,
    required void Function(String url) onOpenLink,
  }) {
    final reg = RegExp(
        r'((?:https?:\/\/)?(?:www\.)?[^\s]+\.[^\s]{2,}(?:\/[^\s]*)*)',
        caseSensitive: false);
    final spans = <TextSpan>[];
    int start = 0;

    for (final m in reg.allMatches(input)) {
      if (m.start > start)
        spans.add(
            TextSpan(text: input.substring(start, m.start), style: normal));
      final urlRaw = m.group(0)!;
      final url = urlRaw.startsWith('http') ? urlRaw : 'https://$urlRaw';
      spans.add(TextSpan(
        text: urlRaw,
        style: link,
        recognizer: (TapGestureRecognizer()..onTap = () => onOpenLink(url)),
      ));
      start = m.end;
    }
    if (start < input.length)
      spans.add(TextSpan(text: input.substring(start), style: normal));
    return TextSpan(children: spans);
  }
}

// زر أكشن
class BlurredAction {
  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;

  const BlurredAction(
      {required this.label, required this.onPressed, this.isPrimary = true});
}

class GalleryView extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const GalleryView({
    Key? key,
    required this.images,
    required this.initialIndex,
  }) : super(key: key);

  @override
  State<GalleryView> createState() => _GalleryViewState();
}

class _GalleryViewState extends State<GalleryView> {
  late PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.images.length,
            itemBuilder: (context, index) {
              return InteractiveViewer(
                child: Image.network(
                  widget.images[index],
                  fit: BoxFit.contain,
                ),
              );
            },
          ),
          Positioned(
            top: 40,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppBarBottomSection extends StatelessWidget {
  const _AppBarBottomSection({
    required this.children,
    this.height,
  });

  final List<Widget> children;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );

    if (height == null) {
      return content;
    }

    return SizedBox(
      height: height,
      width: double.infinity,
      child: SingleChildScrollView(
        padding: EdgeInsets.zero,
        child: content,
      ),
    );
  }
}





