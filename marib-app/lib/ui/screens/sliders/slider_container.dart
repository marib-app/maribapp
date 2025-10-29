// ملف: slider_container.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'slider_component.dart';
import 'slider_shimmer.dart';
import 'package:marib/data/model/home_slider.dart';
import 'slider_constants.dart';

import 'package:marib/data/cubits/slider_cubit.dart';
import 'package:marib/utils/slider_interface_mapper.dart';
import 'dart:async';
import 'package:marib/ui/screens/widgets/lazy_network_image.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:marib/ui/widgets/shimmer/shimmer_box.dart';
import 'package:flutter/foundation.dart';

class SliderWidget extends StatefulWidget {
  final String interfaceType;
  final VoidCallback? onLoaded;
  final VoidCallback? onError;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  const SliderWidget({
    super.key,
    this.interfaceType = "homepage",
    this.onLoaded,
    this.onError,
    this.padding = kSliderHorizontalPadding,
    this.margin = const EdgeInsets.only(bottom: 12),
  });

  @override
  State<SliderWidget> createState() => _SliderWidgetState();
}

class _SliderWidgetState extends State<SliderWidget> {
  bool _hasRequestedCurrentInterface = false;
  List<HomeSlider>? _cachedSliderList;
  String? _cachedFallbackImage;
  bool _hasReportedError = false;

  @override
  void initState() {
    super.initState();
    _requestSlider();
  }

  @override
  void didUpdateWidget(covariant SliderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.interfaceType != widget.interfaceType) {
      _hasRequestedCurrentInterface = false;
      _clearCache();

      _requestSlider(forceRefresh: true);
    }
  }

  void _requestSlider({bool forceRefresh = false}) {
    if (_hasRequestedCurrentInterface && !forceRefresh) return;
    final String? normalized =
    SliderInterfaceMapper.normalize(widget.interfaceType);
    unawaited(
      context.read<SliderCubit>().fetchSlider(
        context,
        interfaceType: normalized ?? widget.interfaceType,
        forceRefresh: forceRefresh,
      ),
    );
    _hasRequestedCurrentInterface = true;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SliderCubit, SliderState>(
      listener: (context, state) {
        if (state is SliderFetchSuccess) {
          _hasReportedError = false;
          _cacheSliderList(state.sliderlist);
          if (state.sliderlist.isNotEmpty) {
            widget.onLoaded?.call();
          }
        }

        if (state is SliderFallbackState) {
          if (state is SliderFetchInProgress) {
            _hasReportedError = false;
          }

          _cacheFallbackImage(state);
          if (_isFallbackImageAvailable(state)) {
            widget.onLoaded?.call();
          }
        }
        if (state is SliderFetchFailure) widget.onError?.call();
      },
      builder: (context, state) {
        if (state is SliderFetchInProgress) {
          final Widget? cached = _buildFromCache();
          return cached ?? _wrapWithPadding(const SliderShimmer());
        }
        if (state is SliderFallbackState) {
          final String display = state.display.toLowerCase();
          if (display == 'shimmer') {
            return _wrapWithPadding(const SliderShimmer());
          }
          if (display == 'image') {
            final String? imageUrl = state.image;
            if (imageUrl != null && imageUrl.isNotEmpty) {
              _cacheFallbackImage(state);
              return _buildFallbackImage(
                context,
                imageUrl,
                margin: widget.margin,
              );

            }
            return const SizedBox.shrink();
          }
        }

        if (state is SliderFetchSuccess) {
          if (state.sliderlist.isEmpty) {
            _cachedSliderList = null;
            final Widget? cached = _buildFromCache();
            return cached ?? _wrapWithPadding(const SliderShimmer());
          }
          _cacheSliderList(state.sliderlist);
          return SliderComponent(
            interfaceType: widget.interfaceType,
            sliderList: state.sliderlist,
            padding: widget.padding,
            margin: widget.margin,
          );
        }
        if (state is SliderFetchFailure) {
          _notifySliderError();
          final Widget? cached = _buildFromCache();
          if (cached != null) {
            return cached;
          }
          if (_cachedFallbackImage != null &&
              _cachedFallbackImage!.isNotEmpty) {
            return _buildFallbackImage(
              context,
              _cachedFallbackImage!,
              margin: widget.margin,
            );

          }
          return _wrapWithPadding(const SliderShimmer());
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _wrapWithPadding(
      Widget child, {
        EdgeInsetsGeometry? margin,
      }) {
    Widget current = child;

    final EdgeInsetsGeometry effectiveMargin = margin ?? widget.margin;

    if (effectiveMargin != EdgeInsets.zero &&
        effectiveMargin != EdgeInsetsDirectional.zero) {
      current = Container(
        margin: effectiveMargin,
        child: current,
      );
    }
    if (widget.padding != EdgeInsets.zero &&
        widget.padding != EdgeInsetsDirectional.zero) {
      current = Padding(
        padding: widget.padding,
        child: current,
      );
    }

    return current;
  }

  void _notifySliderError() {
    if (_hasReportedError) return;
    _hasReportedError = true;
    debugPrint(
      'SliderWidget: Failed to fetch slider for interface "${widget.interfaceType}". Displaying fallback.',
    );
    widget.onError?.call();
  }

  void _cacheSliderList(List<HomeSlider> sliders) {
    if (sliders.isEmpty) {
      _cachedSliderList = null;
      return;
    }
    _cachedSliderList = List<HomeSlider>.from(sliders, growable: false);
  }

  void _cacheFallbackImage(SliderFallbackState state) {
    if (_isFallbackImageAvailable(state)) {
      _cachedFallbackImage = state.image;
    } else if (state.display.toLowerCase() == 'shimmer') {
      _cachedFallbackImage = null;
    }
  }

  void _clearCache() {
    _cachedSliderList = null;
    _cachedFallbackImage = null;
  }

  bool _isFallbackImageAvailable(SliderFallbackState state) {
    final String display = state.display.toLowerCase();
    final String? imageUrl = state.image;
    return display == 'image' && imageUrl != null && imageUrl.isNotEmpty;
  }

  Widget? _buildFromCache() {
    if (_cachedSliderList != null && _cachedSliderList!.isNotEmpty) {
      return SliderComponent(
        interfaceType: widget.interfaceType,
        sliderList: _cachedSliderList!,
        padding: widget.padding,
        margin: widget.margin,
      );
    }
    if (_cachedFallbackImage != null && _cachedFallbackImage!.isNotEmpty) {
      return _buildFallbackImage(
        context,
        _cachedFallbackImage!,
        margin: widget.margin,
      );
    }
    return null;
  }

  Widget _buildFallbackImage(
      BuildContext context,
      String imageUrl, {
        EdgeInsetsGeometry? margin,
      }) {
    final BorderRadius borderRadius = BorderRadius.circular(12);

    return _wrapWithPadding(
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: kSliderBannerHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: borderRadius,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    color: Colors.grey.shade200,
                  ),
                child: ClipRRect(

                  borderRadius: borderRadius,
                  child: LazyNetworkImage(
                    imageUrl: imageUrl,
                    width: double.infinity,
                    height: kSliderBannerHeight,
                    fit: BoxFit.cover,
                    fadeInDuration: Duration.zero,
                    fadeOutDuration: Duration.zero,
                    placeholder: ShimmerBox(
                      borderRadius: borderRadius,
                    ),
                  ),
                ),
                ),
          ],
            ),
          ),
          const SizedBox(height: 8),
          const _StaticSliderIndicator(
            count: 1,
            activeIndex: 0,
          ),
        ],
      ),
      margin: margin ?? widget.margin,

    );
  }
}

class _StaticSliderIndicator extends StatelessWidget {
  const _StaticSliderIndicator({
    required this.count,
    required this.activeIndex,
  });

  final int count;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    final int safeCount = count <= 0 ? 0 : count;
    if (safeCount == 0) {
      return const SizedBox.shrink();
    }

    final int safeActiveIndex;
    if (activeIndex < 0) {
      safeActiveIndex = 0;
    } else if (activeIndex >= safeCount) {
      safeActiveIndex = safeCount - 1;
    } else {
      safeActiveIndex = activeIndex;
    }

    return AnimatedSmoothIndicator(
      activeIndex: safeActiveIndex,
      count: safeCount,
      effect: CustomizableEffect(
        spacing: 6,
        activeDotDecoration: DotDecoration(
          width: 16,
          height: 8,
          color: const Color(0xFFEB5924),
          borderRadius: BorderRadius.circular(8),
        ),
        dotDecoration: DotDecoration(
          width: 8,
          height: 8,
          color: Colors.grey.shade400,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
