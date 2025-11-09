import 'dart:async';

import 'package:flutter/material.dart';
import 'package:marib/app/app_scroll_behavior.dart';
import 'package:marib/app/navigation/app_page_route.dart';
import 'package:marib/app/navigation/motion/route_motion.dart';
import 'package:marib/data/model/wifi/wifi_network.dart';
import 'package:marib/data/model/wifi/wifi_plan.dart';
import 'package:marib/data/wifi/wifi_repository.dart';
import 'package:marib/settings.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/ui/screens/classified_ads/other_services/wifi_cabin/wifi_cabin_intro_screen.dart';
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

    try {
      final List<WifiNetwork> result = await _repository.fetchNetworks(
        query: _searchQuery.trim().isEmpty ? null : _searchQuery.trim(),
        perPage: 60,
      );
      if (!mounted) return;
      setState(() {
        _networks = result;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = ErrorFilter.check(error).error;
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return _WifiNetworkDetailsSheet(
          network: network,
          repository: _repository,
        );
      },
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
                        'بمجرد ربط شبكتك في اللوحة ستظهر هنا مع تفاصيل الخطط والتحويلات.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) {
                      final double width = constraints.crossAxisExtent;
                      int crossAxisCount = 1;
                      if (width >= 1100) {
                        crossAxisCount = 3;
                      } else if (width >= 700) {
                        crossAxisCount = 2;
                      }
                      return SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 0.92,
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
            onPressed: _openAddNetworkFlow,
            icon: const Icon(Icons.add_circle_outline_rounded),
            label: Text(
              'إضافة شبكة جديدة',
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
    final colors = context.color;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'شبكاتك المرتبطة بلوحة Marib',
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: colors.textDefaultColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'يمكنك مراقبة الشبكات، الاطلاع على الخطط، والانتقال مباشرة إلى اللوحة لإدارة الأكواد والدفعات.',
            style: textTheme.bodyMedium?.copyWith(
              color: colors.textLightColor,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          _SearchField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            onChanged: _onSearchChanged,
            onClear: () {
              _searchController.clear();
              _searchQuery = '';
              _loadNetworks();
            },
          ),
          const SizedBox(height: 16),
          _DashboardHintCard(onOpenDashboard: _openDashboard),
        ],
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

class _DashboardHintCard extends StatelessWidget {
  const _DashboardHintCard({required this.onOpenDashboard});

  final VoidCallback onOpenDashboard;

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.borderColor.withOpacity(.4)),
        color: colors.secondaryColor,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: colors.territoryColor.withOpacity(.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.wifi_tethering,
              color: colors.territoryColor,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إدارة متقدمة من خلال اللوحة',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.textDefaultColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'لرفع دفعات الأكواد أو تحديث الخطط، استخدم لوحة wifi-cabin وستظهر التغييرات هنا تلقائيًا.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colors.textLightColor,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: onOpenDashboard,
                  icon: Icon(Icons.open_in_new_rounded,
                      color: colors.territoryColor, size: 18),
                  label: Text(
                    'فتح اللوحة',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.territoryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          decoration: BoxDecoration(
            color: colors.secondaryColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors.borderColor.withOpacity(.35)),
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: colors.territoryColor.withOpacity(.12),
                    backgroundImage:
                        network.iconUrl != null && network.iconUrl!.isNotEmpty
                            ? NetworkImage(network.iconUrl!)
                            : null,
                    child: (network.iconUrl == null || network.iconUrl!.isEmpty)
                        ? Icon(Icons.wifi, color: colors.territoryColor)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          network.name,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colors.textDefaultColor,
                          ),
                        ),
                        if (network.address?.isNotEmpty == true)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              network.address!,
                              style: textTheme.bodyMedium?.copyWith(
                                color: colors.textLightColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  _InfoPill(
                    label: '${network.planCount} خطة',
                    icon: Icons.layers_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (network.coverageKm != null)
                    _InfoChip(
                      icon: Icons.radar_rounded,
                      label: '${network.coverageKm!.toStringAsFixed(1)} كم مدى',
                    ),
                  if (network.currencies.isNotEmpty)
                    _InfoChip(
                      icon: Icons.payments_outlined,
                      label: network.currencies.join(' • '),
                    ),
                  if (network.contacts.isNotEmpty)
                    _InfoChip(
                      icon: Icons.phone_in_talk_rounded,
                      label: network.contacts.first,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.territoryColor.withOpacity(.12),
                    foregroundColor: colors.territoryColor,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: onTap,
                  child: const Text('عرض التفاصيل والخطط'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        color: context.color.territoryColor.withOpacity(.12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: context.color.territoryColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.color.territoryColor,
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
                return Column(
                  children: plans
                      .map((plan) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _WifiPlanTile(plan: plan),
                          ))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _NetworkInfoBlock extends StatelessWidget {
  const _NetworkInfoBlock({required this.network});

  final WifiNetwork network;

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    final textTheme = Theme.of(context).textTheme;

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

class _WifiPlanTile extends StatelessWidget {
  const _WifiPlanTile({required this.plan});

  final WifiPlan plan;

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.borderColor.withOpacity(.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.name,
                      style: textTheme.titleMedium?.copyWith(
                        color: colors.textDefaultColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${plan.price.toStringAsFixed(2)} ${plan.currency ?? ''}',
                      style: textTheme.titleMedium?.copyWith(
                        color: colors.territoryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              if (plan.isUnlimited)
                _InfoPill(
                    label: 'غير محدود', icon: Icons.all_inclusive_rounded),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (plan.durationDays != null)
                _InfoChip(
                  icon: Icons.access_time_rounded,
                  label: '${plan.durationDays} يوم',
                ),
              if (!plan.isUnlimited && plan.dataCapGb != null)
                _InfoChip(
                  icon: Icons.data_usage_rounded,
                  label: '${plan.dataCapGb!.toStringAsFixed(1)} جيجا',
                ),
            ],
          ),
          if (plan.description?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(
              plan.description!,
              style: textTheme.bodyMedium?.copyWith(
                color: colors.textLightColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
