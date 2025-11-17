import 'dart:io';

import 'package:marib/data/cubits/subscription/fetch_ads_listing_subscription_packages_cubit.dart';
import 'package:marib/data/cubits/system/get_api_keys_cubit.dart';
import 'package:marib/settings.dart';
import 'package:marib/ui/screens/subscription/widget/subscription_package_card.dart';
import 'package:marib/ui/screens/subscription/widget/subscription_packages_bottom_bar.dart';
import 'package:marib/ui/screens/subscription/widget/subscription_packages_shell.dart';
import 'package:marib/ui/screens/subscription/widget/subscription_packages_tab_switcher.dart';
import 'package:marib/ui/screens/widgets/intertitial_ads_screen.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/data/helper/widgets.dart';
import 'package:marib/utils/helper_utils.dart';

// âœ… ط­ظ„ طھط¹ط§ط±ط¶ HiveUtils ط¹ط¨ط± Alias
import 'package:marib/utils/hive_utils.dart' as OldHive;

import 'package:marib/utils/payment/gatways/inAppPurchaseManager.dart';
import 'package:marib/data/cubits/subscription/assign_free_package_cubit.dart';
import 'package:marib/data/cubits/subscription/fetch_featured_subscription_packages_cubit.dart';
import 'package:marib/data/model/subscription_pacakage_model.dart';
import 'package:flutter/material.dart';

import 'package:marib/utils/api.dart';

import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/ui/screens/widgets/errors/no_data_found.dart';
import 'package:marib/ui/screens/widgets/errors/no_internet.dart';
import 'package:marib/ui/screens/widgets/errors/something_went_wrong.dart';
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:marib/utils/payment/bank_transfer_args.dart';
import 'package:marib/utils/payment/bank_transfer_screen.dart';
import 'package:marib/utils/payment/manual_payment_service.dart';
import 'package:marib/ui/screens/Transaction_screen.dart';

int? _tryParseInt(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value.toString());
}

class SubscriptionPackageListScreen extends StatefulWidget {
  const SubscriptionPackageListScreen({
    super.key,
    this.focusPackageId,
    this.focusPackageType,
  });

  final int? focusPackageId;
  final String? focusPackageType;

  // âœ… طھظˆظ‚ظٹط¹ ظ…ط·ط§ط¨ظ‚ ظ„ط§ط³طھط¯ط¹ط§ط، ط§ظ„ط±ط§ظˆطھط± ظ„ط¯ظٹظƒ: route(routeSettings)
  static Route route(RouteSettings settings) {
    int? focusPackageId;
    String? focusPackageType;

    final Object? arguments = settings.arguments;
    if (arguments is Map) {
      focusPackageId =
          _tryParseInt(arguments['package_id'] ?? arguments['packageId']);
      final Object? rawType =
          arguments['package_type'] ?? arguments['packageType'];
      if (rawType != null) {
        focusPackageType = rawType.toString();
      }
    }
    return BlurredRouter(builder: (context) {
      return MultiBlocProvider(
        providers: [
          BlocProvider(create: (context) => AssignFreePackageCubit()),
          // ط¨ط§ظ‚ظٹ ط§ظ„ظ€ cubits طھظˆظپظ‘ظژط± ط£ط¹ظ„ظ‰ ظپظٹ ط§ظ„ط´ط¬ط±ط© ط¹ط§ط¯ط© (GetApiKeys / Fetch*). ط¥ظ† ط£ط±ط¯طھطŒ ظٹظ…ظƒظ† ط­ظ‚ظ†ظ‡ط§ ظ‡ظ†ط§ ط£ظٹط¶ظ‹ط§.
        ],
        child: SubscriptionPackageListScreen(
          focusPackageId: focusPackageId,
          focusPackageType: focusPackageType,
        ),
      );
    });
  }

  @override
  State<SubscriptionPackageListScreen> createState() =>
      _SubscriptionPackageListScreenState();
}

class _SubscriptionPackageListScreenState
    extends State<SubscriptionPackageListScreen>
    with SingleTickerProviderStateMixin {
  bool isInterstitialAdShown = false;

  // Controllers
  static const double _cardWidth = 260;
  static const double _cardSpacing = 16;

  final ScrollController _listingScrollController = ScrollController();
  final ScrollController _featuredScrollController = ScrollController();
  late final TabController _tabController;

  int _listingIndex = 0;
  int _featuredIndex = 0;
  bool _focusListingApplied = false;
  bool _focusFeaturedApplied = false;

  // iOS IAP
  final InAppPurchaseManager _inAppPurchaseManager = InAppPurchaseManager();

  @override
  void initState() {
    super.initState();
    AdHelper.loadInterstitialAd();

    if (OldHive.HiveUtils.isUserAuthenticated()) {
      context.read<GetApiKeysCubit>().fetch();
    }
    context.read<FetchAdsListingSubscriptionPackagesCubit>().fetchPackages();
    context.read<FetchFeaturedSubscriptionPackagesCubit>().fetchPackages();

    final initialTabIndex = _resolveInitialTabIndex();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: initialTabIndex,
    );

    _tabController.addListener(_handleTabSelection);

    if (Platform.isIOS) {
      InAppPurchaseManager.getPendings();
      _inAppPurchaseManager.listenIAP(context);
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();

    _listingScrollController.dispose();
    _featuredScrollController.dispose();
    if (Platform.isIOS) {
      _inAppPurchaseManager.dispose();
    }
    super.dispose();
  }

  int _resolveInitialTabIndex() {
    final focusType = widget.focusPackageType?.toLowerCase().trim();
    if (focusType == null || focusType.isEmpty) {
      return 0;
    }
    if (focusType.contains('featured')) {
      return 1;
    }
    return 0;
  }

  bool applyListingFocus(List<SubscriptionPackageModel> packages) {
    final focusId = widget.focusPackageId;
    if (focusId == null || _focusListingApplied) {
      return false;
    }

    final index = packages.indexWhere((pkg) => pkg.id == focusId);
    if (index < 0) {
      return false;
    }

    _focusListingApplied = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _listingIndex = index;
      });
      if (_tabController.index != 0) {
        _tabController.index = 0;
      }
      _scrollToIndex(_listingScrollController, index);
    });

    return true;
  }

  bool applyFeaturedFocus(List<SubscriptionPackageModel> packages) {
    final focusId = widget.focusPackageId;
    if (focusId == null || _focusFeaturedApplied) {
      return false;
    }

    final index = packages.indexWhere((pkg) => pkg.id == focusId);
    if (index < 0) {
      return false;
    }

    _focusFeaturedApplied = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _featuredIndex = index;
      });
      if (_tabController.index != 1) {
        _tabController.index = 1;
      }
      _scrollToIndex(_featuredScrollController, index);
    });

    return true;
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      setState(() {
        // ظٹظڈط¯ط§ط± ط§ظ„ظپظ‡ط±ط³ ط¹ظ†ط¯ onPageChanged ظ„ظƒظ„ طھط¨ظˆظٹط¨
      });
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final Color seedAccent = context.color.headingAccentColor;
    final listingAccent = seedAccent.darken(8);
    final featuredAccent = seedAccent.brighten(12);
    final highlights = _buildHighlightItems(context);
    final tabs = _buildTabs(context);

    return MultiBlocListener(
      listeners: [
        BlocListener<GetApiKeysCubit, GetApiKeysState>(
          listener: (context, state) {
            if (state is GetApiKeysSuccess) {
              AppSettings.updatePaymentGateways(
                wallet: state.walletEnabled,
                manualBanks: state.manualBanks,
                eastYemenBank: state.eastYemenBank,
              );
            }
          },
        ),
        BlocListener<AssignFreePackageCubit, AssignFreePackageState>(
          listener: _handleAssignState,
        ),
      ],
      child: SubscriptionPackageShell(
        tabController: _tabController,
        tabs: tabs,
        tabViews: [
          _buildListingTab(context, listingAccent),
          _buildFeaturedTab(context, featuredAccent),
        ],
        bottomBar: const SizedBox.shrink(),
        title: 'subsctiptionPlane'.translate(context),
        subtitle:
            'ط§ط®طھط± ط§ظ„ط¨ط§ظ‚ط© ط§ظ„ظ…ط«ط§ظ„ظٹط© ظ„طھط¹ط²ظٹط² ط¸ظ‡ظˆط± ط¥ط¹ظ„ط§ظ†ط§طھظƒ',
        highlights: highlights,
      ),
    );
  }

  Widget _buildListingTab(BuildContext context, Color accentColor) {
    return Builder(builder: (context) {
      if (!isInterstitialAdShown) {
        AdHelper.showInterstitialAd();
        isInterstitialAdShown = true;
      }

      return BlocConsumer<FetchAdsListingSubscriptionPackagesCubit,
          FetchAdsListingSubscriptionPackagesState>(
        listener: (context, state) {
          if (state is FetchAdsListingSubscriptionPackagesSuccess) {
            final list = state.subscriptionPackages;
            final focused = applyListingFocus(list);
            if (!focused && list.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                final safeIndex = _listingIndex.clamp(0, list.length - 1);
                if (safeIndex >= 0 && safeIndex < list.length) {
                  setState(() {
                    _listingIndex = safeIndex;
                  });
                  _scrollToIndex(_listingScrollController, safeIndex);
                }
              });
            }
          }
        },
        builder: (context, state) {
          if (state is FetchAdsListingSubscriptionPackagesInProgress) {
            return Center(child: UiUtils.progress());
          }

          if (state is FetchAdsListingSubscriptionPackagesFailure) {
            // âœ… ط¹ط±ط¶ NoInternet ط¹ظ†ط¯ ط§ظ„ط­ط§ط¬ط©طŒ ظˆط¥ظ„ط§ ط®ط·ط£ ط¹ط§ظ…
            if (state.errorMessage == "no-internet") {
              return NoInternet(
                onRetry: () => context
                    .read<FetchAdsListingSubscriptionPackagesCubit>()
                    .fetchPackages(),
              );
            }
            return const SomethingWentWrong();
          }

          if (state is FetchAdsListingSubscriptionPackagesSuccess) {
            final list = state.subscriptionPackages;
            if (list.isEmpty) {
              return NoDataFound(
                onTap: () => context
                    .read<FetchAdsListingSubscriptionPackagesCubit>()
                    .fetchPackages(),
                category: EmptyStateCategory.subscriptions,
              );
            }

            return _buildHorizontalPackagesSection(
              context: context,
              list: list,
              accentColor: accentColor,
              isFeatured: false,
            );
          }

          return const SizedBox.shrink();
        },
      );
    });
  }

  Widget _buildFeaturedTab(BuildContext context, Color accentColor) {
    return Builder(builder: (context) {
      if (!isInterstitialAdShown) {
        AdHelper.showInterstitialAd();
        isInterstitialAdShown = true;
      }

      return BlocConsumer<FetchFeaturedSubscriptionPackagesCubit,
          FetchFeaturedSubscriptionPackagesState>(
        listener: (context, state) {
          if (state is FetchFeaturedSubscriptionPackagesSuccess) {
            final list = state.subscriptionPackages;
            final focused = applyFeaturedFocus(list);
            if (!focused && list.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                final safeIndex = _featuredIndex.clamp(0, list.length - 1);
                if (safeIndex >= 0 && safeIndex < list.length) {
                  setState(() {
                    _featuredIndex = safeIndex;
                  });
                  _scrollToIndex(_featuredScrollController, safeIndex);
                }
              });
            }
          }
        },
        builder: (context, state) {
          if (state is FetchFeaturedSubscriptionPackagesInProgress) {
            return Center(child: UiUtils.progress());
          }

          if (state is FetchFeaturedSubscriptionPackagesFailure) {
            if (state.errorMessage == 'no-internet') {
              return NoInternet(
                onRetry: () => context
                    .read<FetchFeaturedSubscriptionPackagesCubit>()
                    .fetchPackages(),
              );
            }
            return const SomethingWentWrong();
          }

          if (state is FetchFeaturedSubscriptionPackagesSuccess) {
            final list = state.subscriptionPackages;
            if (list.isEmpty) {
              return NoDataFound(
                onTap: () => context
                    .read<FetchFeaturedSubscriptionPackagesCubit>()
                    .fetchPackages(),
                category: EmptyStateCategory.subscriptions,
              );
            }

            return _buildHorizontalPackagesSection(
              context: context,
              list: list,
              accentColor: accentColor,
              isFeatured: true,
            );
          }

          return const SizedBox.shrink();
        },
      );
    });
  }

  Widget _buildHorizontalPackagesSection({
    required BuildContext context,
    required List<SubscriptionPackageModel> list,
    required Color accentColor,
    required bool isFeatured,
  }) {
    final ScrollController controller =
        isFeatured ? _featuredScrollController : _listingScrollController;
    final String categoryLabel = isFeatured
        ? 'featuredAdsLbl'.translate(context)
        : 'adsListing'.translate(context);
    final IconData icon =
        isFeatured ? Icons.workspace_premium_outlined : Icons.layers_rounded;

    return SizedBox(
      height: 240,
      child: ListView.separated(
        controller: controller,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(width: _cardSpacing),
        itemBuilder: (context, index) {
          final model = list[index];
          final bool isActive =
              isFeatured ? index == _featuredIndex : index == _listingIndex;
          return SizedBox(
            width: _cardWidth,
            child: SubscriptionPackageCard(
              model: model,
              position: index + 1,
              selected: isActive,
              accentColor: accentColor,
              icon: icon,
              categoryLabel: categoryLabel,
              onTap: () => _handlePackageTap(
                list: list,
                index: index,
                isFeatured: isFeatured,
                accentColor: accentColor,
              ),
            ),
          );
        },
      ),
    );
  }

  void _handlePackageTap({
    required List<SubscriptionPackageModel> list,
    required int index,
    required bool isFeatured,
    required Color accentColor,
  }) {
    if (index < 0 || index >= list.length) {
      return;
    }
    final model = list[index];
    setState(() {
      if (isFeatured) {
        _featuredIndex = index;
      } else {
        _listingIndex = index;
      }
    });
    _showPackageDetailsSheet(
      model: model,
      accentColor: accentColor,
      tab: isFeatured
          ? SubscriptionPackageTab.featured
          : SubscriptionPackageTab.listing,
    );
  }

  void _scrollToIndex(ScrollController controller, int index) {
    final double targetOffset = index * (_cardWidth + _cardSpacing);
    if (!controller.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !controller.hasClients) return;
        final double maxOffset = controller.position.maxScrollExtent;
        controller.jumpTo(
          targetOffset.clamp(0, maxOffset),
        );
      });
      return;
    }

    final double maxOffset = controller.position.maxScrollExtent;
    controller.animateTo(
      targetOffset.clamp(0, maxOffset),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _showPackageDetailsSheet({
    required SubscriptionPackageModel model,
    required SubscriptionPackageTab tab,
    required Color accentColor,
  }) async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.color.secondaryColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (sheetContext) {
        return _PackageDetailsSheet(
          model: model,
          tab: tab,
          accentColor: accentColor,
          onPurchase: () {
            Navigator.of(sheetContext).pop();
            _onPurchase(model, tab);
          },
        );
      },
    );
  }

  Future<void> _onPurchase(
    SubscriptionPackageModel? selected,
    SubscriptionPackageTab tab,
  ) async {
    if (!OldHive.HiveUtils.isUserAuthenticated()) {
      _showSnack('loginFirst'.translate(context));
      return;
    }

    if (selected == null) {
      _showSnack('ط§ط®طھط± ط¨ط§ظ‚ط© ط£ظˆظ„ط§ظ‹'.translate(context));
      return;
    }

    final packageId = selected.id;
    if (packageId == null) {
      _showSnack('ط­ط¯ط« ط®ط·ط£ ط£ط«ظ†ط§ط، طھط­ط¯ظٹط¯ ط§ظ„ط¨ط§ظ‚ط©'
          .translate(context));
      return;
    }

    final amount = (selected.finalPrice ?? selected.price ?? 0).toDouble();
    if (amount <= 0) {
      context
          .read<AssignFreePackageCubit>()
          .assignFreePackage(packageId: packageId);
      return;
    }

    await _startManualBankTransfer(
      selected,
      isFeatured: tab == SubscriptionPackageTab.featured,
    );
  }

  void _refreshPackages() {
    context.read<FetchAdsListingSubscriptionPackagesCubit>().fetchPackages();
    context.read<FetchFeaturedSubscriptionPackagesCubit>().fetchPackages();
  }

  void _handleAssignState(
    BuildContext context,
    AssignFreePackageState state,
  ) {
    if (state is AssignFreePackageInProgress) {
      Widgets.showLoader(context);
      return;
    }

    Widgets.hideLoder(context);

    if (state is AssignFreePackageInSuccess) {
      HelperUtils.showSnackBarMessage(
        context,
        state.responseMessage,
        type: MessageType.success,
      );
      _refreshPackages();
    } else if (state is AssignFreePackageFailure) {
      HelperUtils.showSnackBarMessage(
        context,
        state.error,
        type: MessageType.error,
      );
    }
  }

  List<SubscriptionHighlightItem> _buildHighlightItems(BuildContext context) {
    final colors = context.color;
    final Color seedAccent = colors.headingAccentColor;
    return [
      SubscriptionHighlightItem(
        icon: Icons.auto_graph_rounded,
        label:
            'ظ…طھط§ط¨ط¹ط© ظپظˆط±ظٹط© ظ„ط£ط¯ط§ط، ط¥ط¹ظ„ط§ظ†ط§طھظƒ ظˆط¥ط­طµط§ط¦ظٹط§طھ ط¯ظ‚ظٹظ‚ط©',
        accentColor: seedAccent.darken(12),
      ),
      SubscriptionHighlightItem(
        icon: Icons.security_rounded,
        label:
            'ط·ط±ظ‚ ط¯ظپط¹ ظ…ظˆط«ظˆظ‚ط© طھط´ظ…ظ„ ط§ظ„طھط­ظˆظٹظ„ ط§ظ„ط¨ظ†ظƒظٹ ظˆط§ظ„ظ…ط­ط§ظپط¸ ط§ظ„ظ…ط­ظ„ظٹط©',
        accentColor: seedAccent.darken(4),
      ),
      SubscriptionHighlightItem(
        icon: Icons.notifications_active_rounded,
        label:
            'طھظ†ط¨ظٹظ‡ط§طھ ظˆطھط¬ط¯ظٹط¯ ظ…ط¨ظƒط± ظ„ط¶ظ…ط§ظ† ط¹ط¯ظ… طھظˆظ‚ظپ ط¸ظ‡ظˆط± ط¥ط¹ظ„ط§ظ†ط§طھظƒ',
        accentColor: seedAccent,
      ),
    ];
  }

  List<SubscriptionTabData> _buildTabs(BuildContext context) {
    final colors = context.color;
    final Color seedAccent = colors.headingAccentColor;
    return [
      SubscriptionTabData(
        icon: Icons.layers_rounded,
        label: 'adsListing'.translate(context),
        accentColor: seedAccent.darken(6),
      ),
      SubscriptionTabData(
        icon: Icons.workspace_premium_outlined,
        label: 'featuredAdsLbl'.translate(context),
        accentColor: seedAccent.brighten(8),
      ),
    ];
  }

  // ===== BottomSheet ظ„ط§ط®طھظٹط§ط± ط¨ظˆط§ط¨ط© ط§ظ„ط¯ظپط¹ =====
  Future<void> _startManualBankTransfer(
    SubscriptionPackageModel? selected, {
    required bool isFeatured,
  }) async {
    if (!OldHive.HiveUtils.isUserAuthenticated()) {
      _showSnack('ظٹطھط·ظ„ط¨ طھط³ط¬ظٹظ„ ط§ظ„ط¯ط®ظˆظ„ ظ„ط¥طھظ…ط§ظ… ط§ظ„ط´ط±ط§ط،'
          .translate(context));
      return;
    }

    if (selected == null) {
      _showSnack('ط§ط®طھط± ط¨ط§ظ‚ط© ط£ظˆظ„ط§ظ‹'.translate(context));
      return;
    }

    final token = OldHive.HiveUtils.getJWT();
    if (token.isEmpty) {
      _showSnack("loginFirst".translate(context));
      return;
    }
    final packageId = selected.id;
    if (packageId == null) {
      _showSnack("ط­ط¯ط« ط®ط·ط£ ط£ط«ظ†ط§ط، طھط­ط¯ظٹط¯ ط§ظ„ط¨ط§ظ‚ط©"
          .translate(context));
      return;
    }

    final amount = (selected.finalPrice ?? selected.price ?? 0).toDouble();
    if (amount <= 0) {
      _showSnack(
          "ظ‡ط°ظ‡ ط§ظ„ط¨ط§ظ‚ط© ظ…ط¬ط§ظ†ظٹط© ط­ط§ظ„ظٹط§ظ‹".translate(context));
      return;
    }

    final type = selected.type?.trim() ?? '';
    final packageType =
        type.isNotEmpty ? type : (isFeatured ? 'featured_ad' : 'item_listing');

    final args = BankTransferArgs(
      token: token,
      packageId: packageId,
      amount: amount,
      currency: selected.currency,
      packageType: packageType,
      itemId: null,
    );

    final result = await BankTransferScreen.show(context, args);

    if (!mounted) return;

    ManualPaymentSubmissionResult? submissionResult;
    bool success = false;

    if (result is ManualPaymentSubmissionResult) {
      submissionResult = result;
      success = result.success;
    } else if (result == true) {
      success = true;
    }

    if (success) {
      final routeArgs = submissionResult?.paymentTransaction ??
          submissionResult?.manualPaymentRequest ??
          submissionResult?.raw;
      await Navigator.of(context).push(
        TransactionScreen.route(
          RouteSettings(
            name: '/transactions',
            arguments: routeArgs,
          ),
        ),
      );
    }
  }
}

class _PackageDetailsSheet extends StatelessWidget {
  const _PackageDetailsSheet({
    required this.model,
    required this.tab,
    required this.accentColor,
    required this.onPurchase,
  });

  final SubscriptionPackageModel model;
  final SubscriptionPackageTab tab;
  final Color accentColor;
  final VoidCallback onPurchase;

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    final double priceValue = (model.finalPrice ?? model.price ?? 0).toDouble();
    final bool isFree = priceValue <= 0;
    final String priceLabel = isFree
        ? 'free'.translate(context)
        : '${HelperUtils.formatPrice(priceValue)} ${model.currency ?? ''}'
            .trim();
    final String title = model.name?.trim().isNotEmpty == true
        ? model.name!.trim()
        : _tabLabel(context);
    final String description = _description(context);
    final List<Widget> chips = _buildMetaChips(context);
    final String buttonLabel =
        isFree ? 'free'.translate(context) : 'buyNow'.translate(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.borderColor.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: colors.textDefaultColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _tabLabel(context),
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.textLightColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        priceLabel,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: accentColor,
                        ),
                      ),
                      if (!isFree && (model.price ?? 0) > priceValue)
                        Text(
                          '${HelperUtils.formatPrice(model.price)} ${model.currency ?? ''}'
                              .trim(),
                          style: TextStyle(
                            decoration: TextDecoration.lineThrough,
                            color: colors.textLightColor,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              if (chips.isNotEmpty) ...[
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: chips,
                ),
              ],
              if (description.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  description,
                  style: TextStyle(
                    color: colors.textDefaultColor.withOpacity(0.85),
                    height: 1.45,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: onPurchase,
                  child: Text(
                    buttonLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildMetaChips(BuildContext context) {
    final List<Widget> chips = [];
    void addChip(IconData icon, String label) {
      chips.add(
        _DetailChip(
          icon: icon,
          label: label,
          accentColor: accentColor,
        ),
      );
    }

    final String? duration = _durationLabel(context);
    if (duration != null) {
      addChip(Icons.schedule_rounded, duration);
    }

    final String? limit = _limitLabel(context);
    if (limit != null) {
      addChip(Icons.layers_outlined, limit);
    }

    return chips;
  }

  String? _durationLabel(BuildContext context) {
    final raw = model.duration?.trim();
    if (raw == null || raw.isEmpty || raw.toLowerCase() == 'null') {
      return null;
    }
    return '$raw ${"days".translate(context)}';
  }

  String? _limitLabel(BuildContext context) {
    final raw = model.limit?.trim();
    if (raw == null || raw.isEmpty || raw.toLowerCase() == 'null') {
      return null;
    }
    final bool unlimited = raw.toLowerCase() == 'unlimited';
    final String base =
        unlimited ? 'unlimitedLbl'.translate(context) : raw.trim();
    return '$base - ${_tabLabel(context)}';
  }

  String _description(BuildContext context) {
    final raw = model.description?.trim();
    if (raw != null && raw.isNotEmpty && raw.toLowerCase() != 'null') {
      return raw;
    }
    return 'صممنا هذه الباقة لتمنح إعلانك دفعة إضافية من الظهور.';
  }

  String _tabLabel(BuildContext context) {
    switch (tab) {
      case SubscriptionPackageTab.listing:
        return 'adsListing'.translate(context);
      case SubscriptionPackageTab.featured:
        return 'featuredAdsLbl'.translate(context);
    }
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({
    required this.icon,
    required this.label,
    required this.accentColor,
  });

  final IconData icon;
  final String label;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: colors.backgroundColor,
        border: Border.all(color: colors.borderColor.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: accentColor,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: colors.textDefaultColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
