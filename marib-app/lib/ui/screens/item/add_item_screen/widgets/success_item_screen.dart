import 'package:marib/app/routes.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/data/model/item/item_model.dart';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:marib/ui/screens/settings/main_activity.dart';
import 'package:marib/utils/helper_utils.dart';



class SuccessItemScreen extends StatefulWidget {
  final ItemModel model;
  final bool isEdit;

  const SuccessItemScreen(
      {super.key, required this.model, required this.isEdit});

  static Route route(RouteSettings settings) {
    Map? arguments = settings.arguments as Map?;
    return BlurredRouter(
      builder: (context) {
        return SuccessItemScreen(
          model: arguments!['model'],
          isEdit: arguments['isEdit'],
        );
      },
    );
  }

  @override
  _SuccessItemScreenState createState() => _SuccessItemScreenState();
}

class _SuccessItemScreenState extends State<SuccessItemScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _isSuccessShown = false;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  bool isBack = false;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.isEdit) {
      _isLoading = false;
      _isSuccessShown = true;
    }

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, widget.isEdit ? 0 : 0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeOutCubic,
      ),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeIn,
    );

    if (widget.isEdit) {
      _slideController.value = 1;
    } else {
      Future.delayed(const Duration(milliseconds: 1600), () {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _isSuccessShown = true;
        });
        if (mounted) {
          _slideController.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  void _handleBackButtonPressed() {
    if (_isSuccessShown && _slideController.isAnimating) {
      setState(() {
        isBack = false;
      });
      // Don't allow popping while the animation is playing
      return;
    } else {
      // Navigate back to the home screen
      _navigateBackToHome();
      return;
    }
  }

  void _navigateToAdDetailsScreen() {
    Navigator.popUntil(context, (route) => route.isFirst);
    Navigator.pushNamed(
      context,
      Routes.adDetailsScreen,
      arguments: {
        'model': widget.model,
      },
    );
  }





  void _navigateBackToHome() {
    if (mounted)
      Future.delayed(
        Duration(milliseconds: 500),
        () {
          if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
          MainActivity.globalKey.currentState?.onItemTapped(0);
        },
      );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: isBack,
      onPopInvoked: (didPop) async {
        // Handle back button press
        _handleBackButtonPressed();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                context.color.backgroundColor,
                context.color.secondaryColor,
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 450),
                  transitionBuilder: (child, animation) =>
                      FadeTransition(opacity: animation, child: child),
                  child: _isLoading
                      ? _buildLoadingContent(context)
                      : _isSuccessShown
                      ? _buildSuccessContent(context)
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingContent(BuildContext context) {
    return Column(
      key: const ValueKey('success_loading'),
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 200,
          child: Lottie.asset(
            "assets/lottie/${Constant.loadingSuccessLottieFile}",
          ),
        ),
        const SizedBox(height: 24),
        Text('loading'.translate(context))
            .centerAlign()
            .size(context.font.larger)
            .color(context.color.textDefaultColor)
            .bold(weight: FontWeight.w600),
      ],
    );
  }

  Widget _buildSuccessContent(BuildContext context) {
    final Widget? summary = _buildAdSummary(context);

    return FadeTransition(
      key: const ValueKey('success_content'),
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: AnimatedSize(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
              Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 26, vertical: 32),
              decoration: BoxDecoration(
                color: context.color.secondaryColor,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: context.color.territoryColor.withOpacity(0.08),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                SizedBox(
                height: 180,
                child: Lottie.asset(
                  "assets/lottie/${Constant.successItemLottieFile}",
                  repeat: false,
                        ),
              ),
              const SizedBox(height: 18),
              if (!widget.isEdit)
            Text('congratulations'.translate(context))
          .centerAlign()
          .size(context.font.extraLarge)
          .color(context.color.territoryColor)
          .bold(weight: FontWeight.w700),
        if (!widget.isEdit) const SizedBox(height: 10),
    Text(widget.isEdit
    ? 'updatedSuccess'.translate(context)
        : 'submittedSuccess'.translate(context))
        .centerAlign()
        .size(context.font.larger)
        .color(context.color.textDefaultColor)
        .bold(weight: FontWeight.w600),
    if (summary != null) ...[
    const SizedBox(height: 24),
    summary,
                      ],
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _navigateToAdDetailsScreen,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.color.territoryColor,
                        foregroundColor: context.color.secondaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        textStyle: TextStyle(
                          fontSize: context.font.larger,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: Text('previewAd'.translate(context)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _navigateBackToHome,
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 18),
                    label: Text('backToHome'.translate(context)),
                    style: TextButton.styleFrom(
                      foregroundColor: context.color.textDefaultColor,
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 12),
                      textStyle: TextStyle(
                        fontSize: context.font.large,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              ),
                  ],
              ),
          ),
        ),
      ),
    );
  }



  Widget? _buildAdSummary(BuildContext context) {
    final bool hasName = (widget.model.name?.trim().isNotEmpty ?? false);
    final num? price = widget.model.finalPrice ?? widget.model.price;
    final String formattedPrice = HelperUtils.formatPrice(price);
    final String? currency = widget.model.currency;
    final String location = <String?>[
      widget.model.city,
      widget.model.state,
      widget.model.country,
    ]
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .join(', ');

    if (!hasName && formattedPrice.isEmpty && location.isEmpty) {
      return null;
    }

    final String priceDisplay = formattedPrice.isEmpty
        ? ''
        : currency != null && currency.trim().isNotEmpty
        ? '$formattedPrice ${currency.trim()}'
        : formattedPrice;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.color.backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: context.color.territoryColor.withOpacity(0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasName)
            Text(widget.model.name ?? '')
                .size(context.font.larger)
                .color(context.color.textDefaultColor)
                .bold(weight: FontWeight.w600),
          if (hasName && (priceDisplay.isNotEmpty || location.isNotEmpty))
            const SizedBox(height: 10),
          if (priceDisplay.isNotEmpty)
            Text(priceDisplay)
                .size(context.font.large)
                .color(context.color.territoryColor)
                .bold(weight: FontWeight.w600),
          if (priceDisplay.isNotEmpty && location.isNotEmpty)
            const SizedBox(height: 8),
          if (location.isNotEmpty)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.place_outlined,
                  size: 18,
                  color: context.color.textLightColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(location)
                      .size(context.font.normal)
                      .color(context.color.textLightColor),
                ),
              ],
            ),
        ],
      ),
    );
  }

}
