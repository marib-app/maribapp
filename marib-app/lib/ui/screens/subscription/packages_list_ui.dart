part of 'packages_list.dart';

enum _PackageType { listing, featured }

extension _SubscriptionPackageListScreenStateUi
    on _SubscriptionPackageListScreenState {
  Widget buildSubscriptionPackageListScreen(BuildContext context) {
    return Scaffold(
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
            final bool focused = applyListingFocus(list);
            if (!focused && _selectedListing.value == null && list.isNotEmpty) {
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
            final bool focused = applyFeaturedFocus(list);
            if (!focused &&
                _selectedFeatured.value == null &&
                list.isNotEmpty) {
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
                category: EmptyStateCategory.subscriptions,
              );
            }

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
                          modelList: [model],
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
}

class _CtaSwitcher extends StatelessWidget {
  final TabController tabController;
  final ValueNotifier<SubscriptionPackageModel?> selectedListing;
  final ValueNotifier<SubscriptionPackageModel?> selectedFeatured;
  final int listingIndex;
  final int featuredIndex;
  final String Function(SubscriptionPackageModel?, bool isFeatured)
      labelBuilder;
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
    final idx = tabController.index;
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
