import 'dart:io';

import 'package:marib/data/cubits/subscription/fetch_ads_listing_subscription_packages_cubit.dart';
import 'package:marib/data/cubits/system/get_api_keys_cubit.dart';
import 'package:marib/settings.dart';
import 'package:marib/ui/screens/subscription/widget/subscription_package_card.dart';
import 'package:marib/ui/screens/subscription/widget/subscription_packages_bottom_bar.dart';
import 'package:marib/ui/screens/subscription/widget/subscription_packages_indicator.dart';
import 'package:marib/ui/screens/subscription/widget/subscription_packages_shell.dart';
import 'package:marib/ui/screens/subscription/widget/subscription_packages_tab_switcher.dart';
import 'package:marib/ui/screens/widgets/intertitial_ads_screen.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/data/helper/widgets.dart';
import 'package:marib/utils/helper_utils.dart';

// ✅ حل تعارض HiveUtils عبر Alias
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

  // ✅ توقيع مطابق لاستدعاء الراوتر لديك: route(routeSettings)
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
          // باقي الـ cubits توفَّر أعلى في الشجرة عادة (GetApiKeys / Fetch*). إن أردت، يمكن حقنها هنا أيضًا.
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
  final PageController adsPageController =
      PageController(initialPage: 0, viewportFraction: 0.86);
  final PageController featuredPageController =
      PageController(initialPage: 0, viewportFraction: 0.86);
  late final TabController _tabController;

  // Selection state per tab
  final ValueNotifier<SubscriptionPackageModel?> _selectedListing =
      ValueNotifier<SubscriptionPackageModel?>(null);
  final ValueNotifier<SubscriptionPackageModel?> _selectedFeatured =
      ValueNotifier<SubscriptionPackageModel?>(null);

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

    adsPageController.dispose();
    featuredPageController.dispose();
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
      _selectedListing.value = packages[index];
      if (_tabController.index != 0) {
        _tabController.index = 0;
      }
      _jumpToPage(adsPageController, index);
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
      _selectedFeatured.value = packages[index];
      if (_tabController.index != 1) {
        _tabController.index = 1;
      }
      _jumpToPage(featuredPageController, index);
    });

    return true;
  }

  void _jumpToPage(PageController controller, int index) {
    if (!mounted) return;
    if (controller.hasClients) {
      controller.jumpToPage(index);
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (controller.hasClients) {
        controller.jumpToPage(index);
      }
    });
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      setState(() {
        // يُدار الفهرس عند onPageChanged لكل تبويب
      });
    }
  }

  void _onListingPageChanged(int i, List<SubscriptionPackageModel> list) {
    setState(() {
      _listingIndex = i;
      _selectedListing.value = list[i];
    });
  }

  void _onFeaturedPageChanged(int i, List<SubscriptionPackageModel> list) {
    setState(() {
      _featuredIndex = i;
      _selectedFeatured.value = list[i];
    });
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }


  @override
  Widget build(BuildContext context) {
    final listingAccent = context.color.territoryColor;
    final featuredAccent = context.color.forthColor;
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
        bottomBar: SubscriptionPackageBottomBar(
          tabController: _tabController,
          selectedListing: _selectedListing,
          selectedFeatured: _selectedFeatured,
          listingIndex: _listingIndex,
          featuredIndex: _featuredIndex,
          onPay: _onPurchase,
          listingAccentColor: listingAccent,
          featuredAccentColor: featuredAccent,
        ),
        title: 'subsctiptionPlane'.translate(context),
        subtitle: 'اختر الباقة المثالية لتعزيز ظهور إعلاناتك',
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
                  _selectedListing.value = list[safeIndex];
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
            // ✅ عرض NoInternet عند الحاجة، وإلا خطأ عام
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

            return Column(

              children: [
            Expanded(
            child: PageView.builder(
            controller: adsPageController,
              physics: const BouncingScrollPhysics(),
              itemCount: list.length,
              onPageChanged: (i) => _onListingPageChanged(i, list),
              itemBuilder: (context, index) {
                final model = list[index];
                final active = index == _listingIndex;
                return AnimatedPadding(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOut,
                  padding: EdgeInsets.symmetric(
                    horizontal: active ? 4 : 12,
                    vertical: active ? 0 : 12,
                        ),
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutBack,
                    scale: active ? 1 : 0.94,
                    child: SubscriptionPackageCard(
                      model: model,
                      position: index + 1,
                      selected: active,
                      accentColor: accentColor,
                      icon: Icons.view_list_rounded,
                      categoryLabel: 'adsListing'.translate(context),
                      onTap: () => _onListingCardTapped(index, list),
                    ),
                  ),
                );
              },
                  ),
                ),
                const SizedBox(height: 16),
                SubscriptionPackagesIndicator(
                  count: list.length,
                  index: _listingIndex,
                  activeColor: accentColor,
                ),
              ],
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
                  _selectedFeatured.value = list[safeIndex];
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

            return Column(
              children: [
            Expanded(
            child: PageView.builder(
            controller: featuredPageController,
              physics: const BouncingScrollPhysics(),
              itemCount: list.length,
              onPageChanged: (i) => _onFeaturedPageChanged(i, list),
              itemBuilder: (context, index) {
                final model = list[index];
                final active = index == _featuredIndex;
                return AnimatedPadding(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOut,
                  padding: EdgeInsets.symmetric(
                    horizontal: active ? 4 : 12,
                    vertical: active ? 0 : 12,
                        ),
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutBack,
                    scale: active ? 1 : 0.94,
                    child: SubscriptionPackageCard(
                      model: model,
                      position: index + 1,
                      selected: active,
                      accentColor: accentColor,
                      icon: Icons.workspace_premium_outlined,
                      categoryLabel: 'featuredAdsLbl'.translate(context),
                      onTap: () => _onFeaturedCardTapped(index, list),
                    ),
                  ),
                );
              },
                  ),
                ),
                const SizedBox(height: 16),
                SubscriptionPackagesIndicator(
                  count: list.length,
                  index: _featuredIndex,
                  activeColor: accentColor,
                ),
              ],
            );
          }

          return const SizedBox.shrink();
        },
      );
    });
  }







  void _onListingCardTapped(
      int index, List<SubscriptionPackageModel> list) {
    if (index < 0 || index >= list.length) {
      return;
    }
    _jumpToPage(adsPageController, index);
    setState(() {
      _listingIndex = index;
      _selectedListing.value = list[index];
    });
  }

  void _onFeaturedCardTapped(
      int index, List<SubscriptionPackageModel> list) {
    if (index < 0 || index >= list.length) {
      return;
    }
    _jumpToPage(featuredPageController, index);
    setState(() {
      _featuredIndex = index;
      _selectedFeatured.value = list[index];
    });
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
      _showSnack('اختر باقة أولاً'.translate(context));
      return;
    }

    final packageId = selected.id;
    if (packageId == null) {
      _showSnack('حدث خطأ أثناء تحديد الباقة'.translate(context));
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

  List<SubscriptionHighlightItem> _buildHighlightItems(
      BuildContext context) {
    final scheme = context.color;
    return [
      SubscriptionHighlightItem(
        icon: Icons.auto_graph_rounded,
        label: 'متابعة فورية لأداء إعلاناتك وإحصائيات دقيقة',
        accentColor: scheme.territoryColor,
      ),
      SubscriptionHighlightItem(
        icon: Icons.security_rounded,
        label: 'طرق دفع موثوقة تشمل التحويل البنكي والمحافظ المحلية',
        accentColor: scheme.forthColor,
      ),
      SubscriptionHighlightItem(
        icon: Icons.notifications_active_rounded,
        label: 'تنبيهات وتجديد مبكر لضمان عدم توقف ظهور إعلاناتك',
        accentColor: scheme.headingAccentColor,
      ),
    ];
  }

  List<SubscriptionTabData> _buildTabs(BuildContext context) {
    final scheme = context.color;
    return [
      SubscriptionTabData(
        icon: Icons.layers_rounded,
        label: 'adsListing'.translate(context),
        accentColor: scheme.territoryColor,
      ),
      SubscriptionTabData(
        icon: Icons.workspace_premium_outlined,
        label: 'featuredAdsLbl'.translate(context),
        accentColor: scheme.forthColor,
      ),
    ];
  }







  // ===== BottomSheet لاختيار بوابة الدفع =====
  Future<void> _startManualBankTransfer(
    SubscriptionPackageModel? selected, {
    required bool isFeatured,
  }) async {
    if (!OldHive.HiveUtils.isUserAuthenticated()) {
      _showSnack('يتطلب تسجيل الدخول لإتمام الشراء'.translate(context));
      return;
    }

    if (selected == null) {
      _showSnack('اختر باقة أولاً'.translate(context));
      return;
    }

    final token = OldHive.HiveUtils.getJWT();
    if (token.isEmpty) {
      _showSnack("loginFirst".translate(context));
      return;
    }
    final packageId = selected.id;
    if (packageId == null) {
      _showSnack("حدث خطأ أثناء تحديد الباقة".translate(context));
      return;
    }

    final amount = (selected.finalPrice ?? selected.price ?? 0).toDouble();
    if (amount <= 0) {
      _showSnack("هذه الباقة مجانية حالياً".translate(context));
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


