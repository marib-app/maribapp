import 'dart:async';

import 'package:flutter/material.dart';
import 'package:marib/app/app_scroll_behavior.dart';
import 'package:marib/app/navigation/app_page_route.dart';
import 'package:marib/app/navigation/motion/route_motion.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/data/model/wifi/wifi_network.dart';
import 'package:marib/data/model/wifi/wifi_plan.dart';
import 'package:marib/data/wifi/wifi_repository.dart';
import 'package:marib/settings.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/ui/screens/classified_ads/other_services/wifi_cabin/network_details_screen.dart';
import 'package:marib/ui/screens/classified_ads/other_services/wifi_cabin/wifi_cabin_intro_screen.dart';
import 'package:marib/ui/widgets/icons/wifi_cabin_glyph.dart';
import 'package:marib/utils/errorFilter.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/ui_utils.dart';

class WifiCabinScreen extends StatefulWidget {
  const WifiCabinScreen({super.key});

  static Route route(RouteSettings settings) {
    return AppPageRoute.build(
      builder: (_) => const WifiCabinScreen(),
      settings: settings,
      maintainState: true,
      motionPattern: AppMotionPattern.glide,
    );
  }

  @override
  State<WifiCabinScreen> createState() => _WifiCabinScreenState();
}

class _WifiCabinScreenState extends State<WifiCabinScreen> {
  final WifiRepository _repository = const WifiRepository();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  Timer? _searchDebounce;
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';
  List<WifiNetwork> _networks = const <WifiNetwork>[];
  bool _hasApprovedOwnerNetwork = false;
  @override
  void initState() {
    super.initState();
    _loadNetworks();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadNetworks({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    } else {
      setState(() {
        _errorMessage = null;
      });
    }

    final String? normalizedQuery =
        _searchQuery.trim().isEmpty ? null : _searchQuery.trim();

    List<WifiNetwork> publicNetworks = const <WifiNetwork>[];
    List<WifiNetwork> ownerNetworks = const <WifiNetwork>[];
    String? fetchError;

    try {
      publicNetworks = await _repository.fetchNetworks(
        query: normalizedQuery,
        perPage: 60,
      );
    } catch (error) {
      fetchError = ErrorFilter.check(error).error;
    }

    try {
      ownerNetworks = await _repository.fetchOwnerNetworks(
        query: normalizedQuery,
        perPage: 60,
      );
    } catch (_) {
      // لا نريد تعطيل تجربة المستخدم إذا فشل استعلام المالكين
    }

    if (!mounted) return;
    setState(() {
      final Map<int, WifiNetwork> merged = <int, WifiNetwork>{};
      for (final network in publicNetworks) {
        merged[network.id] = network;
      }
      for (final network in ownerNetworks) {
        merged[network.id] = network;
      }

      _networks = merged.values.toList();
      _hasApprovedOwnerNetwork = ownerNetworks.any(
        (network) =>
            (network.status ?? '').toLowerCase().trim() == 'active' ||
            (network.meta?['status'] ?? '')
                .toString()
                .toLowerCase()
                .contains('active'),
      );
      _errorMessage = fetchError;
      _isLoading = false;
    });
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _searchQuery = value;
      _loadNetworks();
    });
  }

  Future<void> _openDashboard() async {
    final String dashboardUrl =
        '${HelperUtils.checkHost(AppSettings.hostUrl)}wifi-cabin';
    await UiUtils.launchURL(dashboardUrl);
  }

  Future<void> _openNetworkDetails(WifiNetwork network) async {
    await Navigator.of(context).push(
      WifiNetworkDetailsScreen.route(network),
    );
  }

  Future<void> _openAddNetworkFlow() async {
    final bool? created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const WifiCabinIntroScreen()),
    );
    if (created == true) {
      _loadNetworks();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.color;

    return Scaffold(
      appBar: UiUtils.buildAppBar(
        context,
        showBackButton: true,
        title: 'wifiCabin'.translate(context),
      ),
      backgroundColor: colors.backgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _loadNetworks(showLoader: false),
          displacement: 32,
          child: CustomScrollView(
            physics: AppScrollBehavior.defaultPhysics,
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(context)),
              if (_isLoading && _networks.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _WifiPageLoader(),
                )
              else if (_errorMessage != null && _networks.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _WifiPlaceholder(
                    icon: Icons.wifi_tethering_error_rounded,
                    title: 'تعذر تحميل الشبكات',
                    subtitle: _errorMessage!,
                    actionLabel: 'إعادة المحاولة',
                    onActionPressed: _loadNetworks,
                  ),
                )
              else if (_networks.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _WifiPlaceholder(
                    icon: Icons.travel_explore_rounded,
                    title: 'لا توجد شبكات متاحة حاليًا',
                    subtitle:
                        'لا توجد شبكات مطابقة لبحثك في الوقت الحالي. حاول تغيير كلمات البحث أو العودة لاحقًا.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) {
                      final double width = constraints.crossAxisExtent;
                      int crossAxisCount = width >= 320 ? 3 : 2;
                      return SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 0.78,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final WifiNetwork network = _networks[index];
                            return _WifiNetworkCard(
                              network: network,
                              onTap: () => _openNetworkDetails(network),
                            );
                          },
                          childCount: _networks.length,
                        ),
                      );
                    },
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: colors.territoryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            onPressed:
                _hasApprovedOwnerNetwork ? _openDashboard : _openAddNetworkFlow,
            icon: Icon(_hasApprovedOwnerNetwork
                ? Icons.dashboard_customize_rounded
                : Icons.add_circle_outline_rounded),
            label: Text(
              _hasApprovedOwnerNetwork ? 'إدارة شبكتك' : 'أضف شبكتك الآن',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: _SearchField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: _onSearchChanged,
        onClear: () {
          _searchController.clear();
          _searchQuery = '';
          _loadNetworks();
        },
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = context.color;

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          textInputAction: TextInputAction.search,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: 'ابحث باسم الشبكة أو الموقع',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: onClear,
                  ),
            filled: true,
            fillColor: colors.secondaryColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: colors.borderColor.withOpacity(.4)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: colors.territoryColor),
            ),
          ), 
        );
      },
    );
  }
}

class _WifiNetworkCard extends StatelessWidget {
  const _WifiNetworkCard({required this.network, required this.onTap});

  final WifiNetwork network;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    final textTheme = Theme.of(context).textTheme;
    final bool hasLogo = network.iconUrl?.isNotEmpty == true;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: colors.borderColor.withOpacity(.4)),
                      color: colors.secondaryColor,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: hasLogo
                          ? Image.network(
                              network.iconUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Center(
                                child: WifiCabinGlyph(size: 34),
                              ),
                            )
                          : const Center(
                              child: WifiCabinGlyph(
                                size: 34,
                                color: Colors.white70,
                              ),
                            ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: _NetworkBadge(label: '${network.planCount}'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              network.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.textDefaultColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NetworkBadge extends StatelessWidget {
  const _NetworkBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.black.withOpacity(.55),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.layers_rounded, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            '$label خطة',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.borderColor.withOpacity(.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colors.textLightColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.textLightColor,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}


class _WifiPageLoader extends StatelessWidget {
  const _WifiPageLoader();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }
}

class _WifiPlaceholder extends StatelessWidget {
  const _WifiPlaceholder({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onActionPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onActionPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 44,
            backgroundColor: colors.territoryColor.withOpacity(.12),
            child: Icon(icon, size: 36, color: colors.territoryColor),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colors.textDefaultColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: colors.textLightColor,
            ),
          ),
          if (actionLabel != null && onActionPressed != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onActionPressed,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class _WifiNetworkDetailsSheet extends StatefulWidget {
  const _WifiNetworkDetailsSheet({
    required this.network,
    required this.repository,
  });

  final WifiNetwork network;
  final WifiRepository repository;

  @override
  State<_WifiNetworkDetailsSheet> createState() =>
      _WifiNetworkDetailsSheetState();
}

class _WifiNetworkDetailsSheetState extends State<_WifiNetworkDetailsSheet> {
  late Future<List<WifiPlan>> _plansFuture;

  @override
  void initState() {
    super.initState();
    _plansFuture = widget.repository.fetchNetworkPlans(widget.network.id);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 8,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.network.name,
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.textDefaultColor,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            if (widget.network.description?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: Text(
                  widget.network.description!,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colors.textLightColor,
                  ),
                ),
              ),
            _NetworkInfoBlock(network: widget.network),
            const SizedBox(height: 16),
            Text(
              'الخطط المتاحة',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.textDefaultColor,
              ),
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<WifiPlan>>(
              future: _plansFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return _WifiPlaceholder(
                    icon: Icons.error_outline,
                    title: 'تعذر تحميل الخطط',
                    subtitle: ErrorFilter.check(snapshot.error).error,
                    actionLabel: 'إعادة المحاولة',
                    onActionPressed: () {
                      setState(() {
                        _plansFuture = widget.repository
                            .fetchNetworkPlans(widget.network.id);
                      });
                    },
                  );
                }
                final plans = snapshot.data ?? const <WifiPlan>[];
                if (plans.isEmpty) {
                  return const _WifiPlaceholder(
                    icon: Icons.inventory_2_outlined,
                    title: 'لا توجد خطط مسجلة',
                    subtitle:
                        'قم بإنشاء خطة جديدة من لوحة wifi-cabin لتظهر هنا للعملاء.',
                  );
                }
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final double width = constraints.maxWidth;
                    final int crossAxisCount = width >= 360 ? 3 : 2;
                    final double aspectRatio = 0.85;

                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: aspectRatio,
                      ),
                      itemCount: plans.length,
                      itemBuilder: (context, index) {
                        final plan = plans[index];
                        return _WifiPlanCard(
                          plan: plan,
                          onTap: () => _openPlanCheckout(plan),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openPlanCheckout(WifiPlan plan) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _PlanCheckoutSheet(
        plan: plan,
        network: widget.network,
        onProceed: () async {
          Navigator.of(sheetContext).pop();
          await _navigateToPayment(plan);
        },
      ),
    );
  }

  Future<void> _navigateToPayment(WifiPlan plan) async {
    final double amount = plan.price.toDouble();
    final String? currency = plan.currency;

    if (currency == null || currency.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن متابعة الدفع لهذه الخطة حالياً.')),
      );
      return;
    }

    await Navigator.of(context).pushNamed(
      Routes.servicePaymentPage,
      arguments: {
        'serviceId': plan.id,
        'serviceTitle': '${plan.name} - ${widget.network.name}',
        'amount': amount,
        'currency': currency,
        'note':
            plan.description ?? 'خطة ${plan.name} لشبكة ${widget.network.name}',
      },
    );
  }
}

class _NetworkInfoBlock extends StatelessWidget {
  const _NetworkInfoBlock({required this.network});

  final WifiNetwork network;

  @override
  Widget build(BuildContext context) {
    final colors = context.color;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.borderColor.withOpacity(.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (network.address?.isNotEmpty == true)
            _InfoRow(
              icon: Icons.location_on_outlined,
              label: 'العنوان',
              value: network.address!,
            ),
          if (network.coverageKm != null)
            _InfoRow(
              icon: Icons.radar_rounded,
              label: 'نطاق التغطية',
              value: '${network.coverageKm!.toStringAsFixed(1)} كم',
            ),
          if (network.currencies.isNotEmpty)
            _InfoRow(
              icon: Icons.currency_exchange_rounded,
              label: 'العملات المدعومة',
              value: network.currencies.join('، '),
            ),
          if (network.contacts.isNotEmpty)
            _InfoRow(
              icon: Icons.call_rounded,
              label: 'جهات التواصل',
              value: network.contacts.join('\n'),
            ),
          if (network.notes?.isNotEmpty == true)
            _InfoRow(
              icon: Icons.sticky_note_2_outlined,
              label: 'ملاحظات داخلية',
              value: network.notes!,
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.textLightColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.textLightColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colors.textDefaultColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WifiPlanCard extends StatelessWidget {
  const _WifiPlanCard({required this.plan, required this.onTap});

  final WifiPlan plan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    final textTheme = Theme.of(context).textTheme;
    final bool hasCurrency = plan.currency?.trim().isNotEmpty ?? false;
    final String priceLabel =
        '${plan.price.toStringAsFixed(2)} ${plan.currency ?? ''}'.trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: colors.borderColor.withOpacity(.35)),
            color: colors.secondaryColor,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: colors.borderColor.withOpacity(.4)),
                    color: colors.secondaryColor,
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      WifiCabinGlyph(
                        size: 32,
                        color: colors.territoryColor,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        priceLabel,
                        style: textTheme.bodyLarge?.copyWith(
                          color: colors.territoryColor,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (!hasCurrency)
                        Text(
                          '—',
                          style: textTheme.bodySmall
                              ?.copyWith(color: colors.textLightColor),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                plan.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.textDefaultColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanCheckoutSheet extends StatelessWidget {
  const _PlanCheckoutSheet({
    required this.plan,
    required this.network,
    required this.onProceed,
  });

  final WifiPlan plan;
  final WifiNetwork network;
  final VoidCallback onProceed;

  bool get _canProceed => plan.currency?.trim().isNotEmpty ?? false;

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    final textTheme = Theme.of(context).textTheme;
    final String priceLabel =
        '${plan.price.toStringAsFixed(2)} ${plan.currency ?? ''}'.trim();

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'خطة ${plan.name}',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.textDefaultColor,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          Text(
            network.name,
            style: textTheme.bodyMedium?.copyWith(
              color: colors.textLightColor,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: colors.borderColor.withOpacity(.4)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'السعر الإجمالي',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.textLightColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    priceLabel,
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.territoryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (plan.durationDays != null)
                _InfoChip(
                  icon: Icons.schedule_rounded,
                  label: '${plan.durationDays} يوم سريان',
                ),
              if (plan.dataCapGb != null)
                _InfoChip(
                  icon: Icons.cloud_download_rounded,
                  label: '${plan.dataCapGb!.toStringAsFixed(1)} جيجا متاحة',
                ),
              if (plan.isUnlimited)
                _InfoChip(
                  icon: Icons.all_inclusive_rounded,
                  label: 'سرعة مفتوحة',
                ),
            ],
          ),
          if (plan.description?.isNotEmpty == true) ...[
            const SizedBox(height: 16),
            Text(
              plan.description!,
              style: textTheme.bodyMedium?.copyWith(
                color: colors.textLightColor,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _canProceed ? onProceed : null,
              icon: const Icon(Icons.payment_rounded),
              label: const Text('متابعة الدفع'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: textTheme.titleMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
