part of 'package:marib/ui/screens/classified_ads/other_services/wifi_cabin/wifi_cabin_screen.dart';

class _WifiCabinScreenState extends State<WifiCabinScreen> {
  late final WifiCabinController _controller;
  final WifiRepository _repository = const WifiRepository();
  late final WifiPurchasesManager _purchasesManager;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = WifiCabinController();
    _purchasesManager = WifiPurchasesManager(_repository);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.bootstrap();
      _purchasesManager.fetch();
    });
  }

  @override
  void dispose() {
    _purchasesManager.dispose();
    _controller.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final state = _controller.viewState;

        if (_searchController.text != _controller.query) {
          _searchController.value = _searchController.value.copyWith(
            text: _controller.query,
            selection: TextSelection.collapsed(
              offset: _controller.query.length,
            ),
          );
        }


        return Scaffold(
          backgroundColor: context.color.backgroundColor,
          appBar: AppBar(
            title: Text('wifiCabin'.translate(context)),
            elevation: 0,
            backgroundColor: theme.appBarTheme.backgroundColor,
            foregroundColor: theme.appBarTheme.foregroundColor,
            systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
            leading: const BackButton(),
            actions: [
              IconButton(
                tooltip: 'طلباتي',
                onPressed: () => _openPurchasesSheet(context),
                icon: const Icon(Icons.receipt_long),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                _SearchHeaderBar(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  isLoading: state.status == WifiCabinLoadStatus.loading &&
                      !state.hasData,
                  onChanged: (value) => _controller.updateQuery(value),
                  onSubmitted: (value) =>
                      _controller.updateQuery(value, immediate: true),
                  onClear: _controller.clearQuery,
                  onRefresh: () => _controller.refreshNetworks(force: true),
                ),
                const SizedBox(height: 12),
                const _ServiceOverview(),
                const SizedBox(height: 16),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: _buildBodyForState(context, state),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: context.color.primaryColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _openAddNetworkScreen(context),
                child: const Text('إضافة شبكة جديدة'),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBodyForState(BuildContext context, WifiCabinViewState state) {
    final grid = _buildNetworksGrid(state);

    switch (state.status) {
      case WifiCabinLoadStatus.loading:
        if (state.hasData) {
          return Stack(
            key: const ValueKey('loading_with_data'),
            children: [
              grid,
              const _LoadingOverlay(),
            ],
          );
        }
        return _buildShimmerGrid();
      case WifiCabinLoadStatus.success:
        return _buildNetworksGrid(state, key: const ValueKey('success'));
      case WifiCabinLoadStatus.failure:
        if (state.hasData) {
          return Stack(
            key: const ValueKey('failure_with_data'),
            children: [
              grid,
              _ErrorBanner(
                message: state.errorMessage ?? 'تعذّر تحديث الشبكات، حاول مجددًا.',
                onRetry: () => _controller.refreshNetworks(),
              ),
            ],
          );
        }
        return _ErrorState(
          key: const ValueKey('failure'),
          message: state.errorMessage ?? 'تعذّر جلب الشبكات في الوقت الحالي.',
          onRetry: () => _controller.refreshNetworks(),
        );
    }
  }

  Widget _buildNetworksGrid(WifiCabinViewState state, {Key? key}) {
    return _NetworksGrid(
      key: key,
      networks: state.networks,
      onSelect: (network) => _openPlansSheet(context, network),
      onRefresh: () => _controller.refreshNetworks(force: true),
      searchQuery: _controller.query,
    );
  }

  Widget _buildShimmerGrid() {
    final color = context.color.secondaryColor;
    final base = color.withOpacity(0.35);
    final highlight = color.withOpacity(0.18);

    return GridView.builder(
      key: const ValueKey('loading_shimmer'),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemCount: 6,
      itemBuilder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Shimmer.fromColors(
                baseColor: base,
                highlightColor: highlight,
                child: Container(
                  height: 70,
                  width: double.infinity,
                  color: base,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Shimmer.fromColors(
              baseColor: base,
              highlightColor: highlight,
              child: Container(
                height: 12,
                width: 90,
                decoration: BoxDecoration(
                  color: base,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Shimmer.fromColors(
              baseColor: base,
              highlightColor: highlight,
              child: Container(
                height: 10,
                width: 60,
                decoration: BoxDecoration(
                  color: base,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openPurchasesSheet(BuildContext context) async {
    unawaited(_purchasesManager.fetch());
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.color.backgroundColor,
      builder: (_) => _PurchasesSheet(
        purchasesListenable: _purchasesManager.purchases,
        loadingListenable: _purchasesManager.loading,
        errorListenable: _purchasesManager.error,
        onRefresh: () => _purchasesManager.refresh(),
      ),
    );
  }

  Future<void> _showCodesDialog(WifiPurchase purchase) async {
    final List<String> codes = purchase.codes;
    if (codes.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final color = dialogContext.color;
        return AlertDialog(
          title: Text(
            'أكواد ${purchase.planName ?? 'الخطة'}',
            style: TextStyle(color: color.textDefaultColor),
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: codes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, index) {
                final code = codes[index];
                return _CodeTile(
                  code: code,
                  onCopy: () {
                    Clipboard.setData(ClipboardData(text: code));
                    messenger.showSnackBar(
                      SnackBar(content: Text('تم نسخ الكود: $code')),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            if (codes.length > 1)
              TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: codes.join('\n')));
                  messenger.showSnackBar(
                    const SnackBar(content: Text('تم نسخ جميع الأكواد.')),
                  );
                },
                child: const Text('نسخ الكل'),
              ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('تم'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openAddNetworkScreen(BuildContext context) async {
    final dynamic result = await Navigator.of(context).push<dynamic>(
      MaterialPageRoute(
        builder: (_) => _AddNetworkScreen(
          userLatLng: null,
          repository: _repository,
        ),
      ),
    );

    await _handleAddNetworkResult(context, result);
  }

  Future<void> _openAddNetworkSheet(BuildContext context) async {
    final dynamic result = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.color.backgroundColor,
      builder: (_) => _AddNetworkSheet(
        repository: _repository,
        userLatLng: null,
      ),
    );

    await _handleAddNetworkResult(context, result);
  }

  Future<void> _handleAddNetworkResult(
      BuildContext context, dynamic result) async {
    if (result == null) {
      return;
    }

    await _controller.refreshNetworks(force: true);
    marib-app/lib/utils/api.dart    if (!mounted) return;

    final String? message = _formatNetworkResultMessage(result);
    if (message == null) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String? _formatNetworkResultMessage(dynamic result) {
    if (result is Map) {
      final map = Map<String, dynamic>.from(result as Map);
      return (map['message'] as String?) ?? (() {
        final String? name = map['name'] as String?;
        final String? status = map['status'] as String?;
        if (name != null && status != null) {
          return 'تم إرسال طلب الشبكة "$name" (الحالة: $status)';
        }
        if (name != null) {
          return 'تمت إضافة الشبكة "$name" بنجاح';
        }
        if (status != null) {
          return 'تم إرسال الطلب (الحالة: $status)';
        }
        return null;
      })();
    }
    if (result is String) {
      return 'تمت إضافة الشبكة "$result" بنجاح';
    }
    return 'تم إرسال طلب الشبكة بنجاح';
  }

  Future<void> _openPlansSheet(BuildContext context, WifiNetwork network) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.color.backgroundColor,
      builder: (_) => _PlansSheet(
        network: network,
        onRegisterPurchase: _purchasesManager.register,
        onRefreshPurchases: ({bool force = false}) =>
            _purchasesManager.fetch(force: force),
        onShowCodes: _showCodesDialog,
      ),
    );
  }
}