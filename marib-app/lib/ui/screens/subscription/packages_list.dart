import 'dart:io';

import 'package:marib/data/cubits/subscription/fetch_ads_listing_subscription_packages_cubit.dart';
import 'package:marib/data/cubits/system/get_api_keys_cubit.dart';
import 'package:marib/settings.dart';
import 'package:marib/ui/screens/subscription/widget/featured_ads_subscription_plan_item.dart';
import 'package:marib/ui/screens/subscription/widget/item_listing_subscription_plans_item.dart';
import 'package:marib/ui/screens/widgets/intertitial_ads_screen.dart';
import 'package:marib/ui/theme/theme.dart';

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







class SubscriptionPackageListScreen extends StatefulWidget {
  const SubscriptionPackageListScreen({super.key});

  // ✅ توقيع مطابق لاستدعاء الراوتر لديك: route(routeSettings)
  static Route route(RouteSettings settings) {
    return BlurredRouter(builder: (context) {
      return MultiBlocProvider(
        providers: [
          BlocProvider(create: (context) => AssignFreePackageCubit()),
          // باقي الـ cubits توفَّر أعلى في الشجرة عادة (GetApiKeys / Fetch*). إن أردت، يمكن حقنها هنا أيضًا.
        ],
        child: const SubscriptionPackageListScreen(),
      );
    });
  }

  @override
  State<SubscriptionPackageListScreen> createState() =>
      _SubscriptionPackageListScreenState();
}

class _SubscriptionPackageListScreenState
    extends State<SubscriptionPackageListScreen> {
  bool isInterstitialAdShown = false;

  // Controllers
  final PageController adsPageController =
  PageController(initialPage: 0, viewportFraction: 0.86);
  final PageController featuredPageController =
  PageController(initialPage: 0, viewportFraction: 0.86);
  TabController? _tabController;

  // Selection state per tab
  final ValueNotifier<SubscriptionPackageModel?> _selectedListing =
  ValueNotifier<SubscriptionPackageModel?>(null);
  final ValueNotifier<SubscriptionPackageModel?> _selectedFeatured =
  ValueNotifier<SubscriptionPackageModel?>(null);

  int _listingIndex = 0;
  int _featuredIndex = 0;

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tabController = DefaultTabController.of(context);
      _tabController?.addListener(_handleTabSelection);
    });

    if (Platform.isIOS) {
      InAppPurchaseManager.getPendings();
      _inAppPurchaseManager.listenIAP(context);
    }
  }

  @override
  void dispose() {
    _tabController?.removeListener(_handleTabSelection);
    adsPageController.dispose();
    featuredPageController.dispose();
    if (Platform.isIOS) {
      _inAppPurchaseManager.dispose();
    }
    super.dispose();
  }

  void _handleTabSelection() {
    if (_tabController!.indexIsChanging) {
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

  String _priceLabel(SubscriptionPackageModel? m) {
    if (m == null) return "";
    final p = m.price?.toString() ?? "";
    return p; // 🔒 لا نعتمد على خصائص غير موجودة (title/durationText)
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // Number of tabs
      child: Scaffold(
        backgroundColor: context.color.backgroundColor,
        appBar: UiUtils.buildAppBar(
          context,
          showBackButton: true,
          title: "subsctiptionPlane".translate(context),
          bottomHeight: 49,
          bottom: [
            Container(
              decoration: BoxDecoration(
                color: context.color.secondaryColor,
                boxShadow: [
                  BoxShadow(
                    color: context.color.borderColor.withOpacity(0.8),
                    spreadRadius: 3,
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: TabBar(
                controller: _tabController,
                tabs: [
                  Tab(text: "adsListing".translate(context)),
                  Tab(text: "featuredAdsLbl".translate(context)),
                ],
                indicatorColor: context.color.territoryColor,
                indicatorWeight: 3,
                labelColor: context.color.territoryColor,
                unselectedLabelColor:
                context.color.textDefaultColor.withOpacity(0.5),
                labelStyle: const TextStyle(fontSize: 16),
                labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                indicatorSize: TabBarIndicatorSize.tab,
              ),
            ),
          ],
        ),

        // ====== CTA ثابت أسفل الشاشة لكل تبويب ======
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            decoration: BoxDecoration(
              color: context.color.secondaryColor,
              border: Border(
                top: BorderSide(color: context.color.borderColor),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: _CtaSwitcher(
              tabController: _tabController,
              selectedListing: _selectedListing,
              selectedFeatured: _selectedFeatured,
              listingIndex: _listingIndex,
              featuredIndex: _featuredIndex,
              labelBuilder: (sel, isFeatured) {
                // 🔒 لا نستخدم title — نعرض تسمية عامة مع رقم الصفحة + السعر
                final idx = isFeatured ? _featuredIndex : _listingIndex;
                final price = _priceLabel(sel);
                final base = isFeatured ? "باقة التمييز" : "باقة النشر";
                return price.isNotEmpty
                    ? "$base #${idx + 1} • $price"
                    : "$base #${idx + 1}";
              },
              onPickGateway: (selected, type) {
                _startManualBankTransfer(
                  selected,
                  isFeatured: type == _PackageType.featured,
                );
              },
            ),
          ),
        ),

        body: BlocListener<GetApiKeysCubit, GetApiKeysState>(
          listener: (context, state) {
            if (state is GetApiKeysSuccess) {
              AppSettings.updatePaymentGateways(
                wallet: state.walletEnabled,
                manualBanks: state.manualBanks,
                eastYemenBank: state.eastYemenBank,
              );
            }
          },
          child: TabBarView(
            controller: _tabController,
            children: [
              adsListing(),
              featuredAds(),
            ],
          ),
        ),
      ),
    );
  }

  Builder adsListing() {
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
            if (_selectedListing.value == null && list.isNotEmpty) {
              // ✅ تهيئة أولية خارج مرحلة البناء
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final safeIndex = _listingIndex.clamp(0, list.length - 1);
                _selectedListing.value = list[safeIndex];
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
              );
            }

            // ❌ لا نعين _selectedListing.value هنا
            return Stack(
              children: [
                PageView.builder(
                  controller: adsPageController,
                  itemCount: list.length,
                  onPageChanged: (i) => _onListingPageChanged(i, list),
                  itemBuilder: (context, index) {
                    final model = list[index];
                    final active = index == _listingIndex;

                    return AnimatedPadding(
                      duration: const Duration(milliseconds: 220),
                      padding: EdgeInsets.symmetric(vertical: active ? 8 : 18),
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 220),
                        scale: active ? 1.0 : 0.95,
                        child: ItemListingSubscriptionPlansItem(
                          itemIndex: _listingIndex,
                          index: index,
                          model: model,
                          inAppPurchaseManager: _inAppPurchaseManager,
                        ),
                      ),
                    );
                  },
                ),
                Positioned(
                  bottom: 12,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _DotsIndicator(
                      count: list.length,
                      index: _listingIndex,
                      activeColor: context.color.territoryColor,
                      color: context.color.borderColor.withOpacity(0.6),
                    ),
                  ),
                ),
              ],
            );
          }

          return const SizedBox.shrink();
        },
      );
    });
  }


  Builder featuredAds() {
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
            if (_selectedFeatured.value == null && list.isNotEmpty) {
              // ✅ تهيئة أولية خارج مرحلة البناء
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final safeIndex = _featuredIndex.clamp(0, list.length - 1);
                _selectedFeatured.value = list[safeIndex];
              });
            }
          }
        },
        builder: (context, state) {
          if (state is FetchFeaturedSubscriptionPackagesInProgress) {
            return Center(child: UiUtils.progress());
          }

          if (state is FetchFeaturedSubscriptionPackagesFailure) {
            if (state.errorMessage == "no-internet") {
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
              );
            }

            // ❌ لا نعين _selectedFeatured.value هنا
            return Stack(
              children: [
                PageView.builder(
                  controller: featuredPageController,
                  itemCount: list.length,
                  onPageChanged: (i) => _onFeaturedPageChanged(i, list),
                  itemBuilder: (context, index) {
                    final model = list[index];
                    final active = index == _featuredIndex;

                    return AnimatedPadding(
                      duration: const Duration(milliseconds: 220),
                      padding: EdgeInsets.symmetric(vertical: active ? 8 : 18),
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 220),
                        scale: active ? 1.0 : 0.95,
                        child: FeaturedAdsSubscriptionPlansItem(
                          modelList: [model], // الودجت يتوقع قائمة
                          inAppPurchaseManager: _inAppPurchaseManager,
                        ),
                      ),
                    );
                  },
                ),
                Positioned(
                  bottom: 12,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _DotsIndicator(
                      count: list.length,
                      index: _featuredIndex,
                      activeColor: context.color.territoryColor,
                      color: context.color.borderColor.withOpacity(0.6),
                    ),
                  ),
                ),
              ],
            );
          }

          return const SizedBox.shrink();
        },
      );
    });
  }


  // ===== BottomSheet لاختيار بوابة الدفع =====
  Future<void> _startManualBankTransfer(
      SubscriptionPackageModel? selected, {
        required bool isFeatured,
      }) async {
    if (!OldHive.HiveUtils.isUserAuthenticated()) {
      _showSnack("يتطلب تسجيل الدخول لإتمام الشراء".translate(context));
      return;
    }

    if (selected == null) {
      _showSnack("اختر باقة أولاً".translate(context));
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
    final packageType = type.isNotEmpty
        ? type
        : (isFeatured ? 'featured_ad' : 'item_listing');

    final args = BankTransferArgs(
      token: token,
      packageId: packageId,
      amount: amount,
      currency: selected.currency,
      packageType: packageType,
      itemId: null,
    );

    final result = await Navigator.of(context).push(
      BankTransferScreen.route(
        RouteSettings(
          name: '/bank-transfer',
          arguments: args,
        ),
      ),
    );

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

// ======== Widgets مساعدة =========

enum _PackageType { listing, featured }

class _CtaSwitcher extends StatelessWidget {
  final TabController? tabController;
  final ValueNotifier<SubscriptionPackageModel?> selectedListing;
  final ValueNotifier<SubscriptionPackageModel?> selectedFeatured;
  final int listingIndex;
  final int featuredIndex;

  final String Function(SubscriptionPackageModel?, bool isFeatured) labelBuilder;
  final void Function(SubscriptionPackageModel?, _PackageType) onPickGateway;

  const _CtaSwitcher({
    required this.tabController,
    required this.selectedListing,
    required this.selectedFeatured,
    required this.listingIndex,
    required this.featuredIndex,
    required this.labelBuilder,
    required this.onPickGateway,
  });

  @override
  Widget build(BuildContext context) {
    final idx = tabController?.index ?? 0;
    if (idx == 1) {
      return ValueListenableBuilder<SubscriptionPackageModel?>(
        valueListenable: selectedFeatured,
        builder: (_, sel, __) => _BottomCtaBar(
          label: labelBuilder(sel, true),
          enabled: sel != null,
          onPay: () => onPickGateway(sel, _PackageType.featured),
        ),
      );
    }
    return ValueListenableBuilder<SubscriptionPackageModel?>(
      valueListenable: selectedListing,
      builder: (_, sel, __) => _BottomCtaBar(
        label: labelBuilder(sel, false),
        enabled: sel != null,
        onPay: () => onPickGateway(sel, _PackageType.listing),
      ),
    );
  }
}

class _BottomCtaBar extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onPay;

  const _BottomCtaBar({
    required this.label,
    required this.enabled,
    required this.onPay,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: enabled ? 1 : 0.7,
            child: Text(
              label.isEmpty ? "اختر باقة أولاً".translate(context) : label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.color.textDefaultColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 44,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: enabled
                  ? context.color.territoryColor
                  : context.color.borderColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18),
            ),
            onPressed: enabled ? onPay : null,
            child: Text(
              "اختر طريقة الدفع".translate(context),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}

class _DotsIndicator extends StatelessWidget {
  final int count;
  final int index;
  final Color activeColor;
  final Color color;

  const _DotsIndicator({
    required this.count,
    required this.index,
    required this.activeColor,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 1) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 18 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: active ? activeColor : color,
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
    );
  }
}


