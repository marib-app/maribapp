import 'package:flutter/material.dart';
import 'package:marib/data/model/category_model.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/ui_utils.dart';

import 'package:marib/ui/screens/merchant/onboarding/widgets/legacy_selectors.dart';

class Phase2Data {
  final List<int> categoryIds;
  final Map<int, DaySchedule> workingHours;

  Phase2Data({required this.categoryIds, required this.workingHours});
}

class DaySchedule {
  final bool enabled;
  final TimeOfDay from;
  final TimeOfDay to;

  DaySchedule({
    required this.enabled,
    required this.from,
    required this.to,
  });

  DaySchedule copyWith({
    bool? enabled,
    TimeOfDay? from,
    TimeOfDay? to,
  }) {
    return DaySchedule(
      enabled: enabled ?? this.enabled,
      from: from ?? this.from,
      to: to ?? this.to,
    );
  }
}

class Phase2CategoriesHours extends StatefulWidget {
  final VoidCallback onBack;
  final void Function(Phase2Data data) onNext;
  final ValueNotifier<int> visibilityNotifier;
  final int pageIndex;

  const Phase2CategoriesHours({
    super.key,
    required this.onBack,
    required this.onNext,
    required this.visibilityNotifier,
    required this.pageIndex,
  });

  @override
  State<Phase2CategoriesHours> createState() => _Phase2CategoriesHoursState();
}

class _Phase2CategoriesHoursState extends State<Phase2CategoriesHours>
    with AutomaticKeepAliveClientMixin {
  Future<List<CategoryModel>>? _categoriesFuture;
  final Set<int> _selectedCategoryIds = <int>{};
  List<String> _selectedCategoryLabels = <String>[];
  static const int _storeRootCategoryId = 3;
  final Map<int, DaySchedule> _hours = {
    for (int i = 0; i < 7; i++)
      i: DaySchedule(
        enabled: false,
        from: const TimeOfDay(hour: 9, minute: 0),
        to: const TimeOfDay(hour: 18, minute: 0),
      ),
  };

  bool get _canProceed => _selectedCategoryIds.isNotEmpty;

  late final VoidCallback _visibilityListener;
  bool _refreshQueued = false;

  @override
  void initState() {
    super.initState();
    _visibilityListener = _handleVisibilityChanged;
    widget.visibilityNotifier.addListener(_visibilityListener);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _handleVisibilityChanged());
  }

  @override
  void didUpdateWidget(covariant Phase2CategoriesHours oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visibilityNotifier != widget.visibilityNotifier) {
      oldWidget.visibilityNotifier.removeListener(_visibilityListener);
      widget.visibilityNotifier.addListener(_visibilityListener);
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _handleVisibilityChanged());
    }
  }

  @override
  void dispose() {
    widget.visibilityNotifier.removeListener(_visibilityListener);
    super.dispose();
  }

  void _handleVisibilityChanged() {
    if (widget.visibilityNotifier.value == widget.pageIndex) {
      _scheduleRefresh();
    }
  }

  void _scheduleRefresh() {
    if (_refreshQueued) return;
    _refreshQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshQueued = false;
      _reloadCategories();
    });
  }

  void _reloadCategories() {
    setState(() {
      _categoriesFuture = _loadCategories();
    });
  }

  Future<List<CategoryModel>> _loadCategories() async {
    try {
      final Map<String, dynamic> response = await Api.get(
        url: Api.getCategoriesApi,
        queryParameters: <String, dynamic>{
          Api.page: 1,
          Api.categoryId: _storeRootCategoryId,
          Api.perPageQuery: 100,
        },
      );

      final List<CategoryModel> parsed =
          _parseCategoriesPayload(response['data']);
      final List<CategoryModel> filtered = parsed
          .where((category) => category.id != _storeRootCategoryId)
          .toList();

      if (filtered.isNotEmpty) {
        filtered.sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));
        return filtered;
      }

      final List<CategoryModel> fallback =
          _extractSelfCategoryChildren(response);
      if (fallback.isNotEmpty) {
        fallback.sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));
        return fallback;
      }

      return const <CategoryModel>[];
    } catch (_) {
      HelperUtils.showSnackBarMessage(
        context,
        'ÍÏË ÎØÃ ÃËäÇÁ ÊÍãíá ÇáÝÆÇÊ. ÍÇæá ãÌÏÏÇð.',
      );
      return const <CategoryModel>[];
    }
  }

  List<CategoryModel> _parseCategoriesPayload(dynamic data) {
    if (data is Map<String, dynamic>) {
      final List<dynamic> items = data['items'] ?? data['data'] ?? [];
      return _mapCategories(items);
    }
    if (data is List) {
      return _mapCategories(data);
    }
    return const <CategoryModel>[];
  }

  List<CategoryModel> _mapCategories(List<dynamic> source) {
    return source
        .whereType<Map<String, dynamic>>()
        .map(CategoryModel.fromJson)
        .where((category) => category.id != null)
        .toList();
  }

  List<CategoryModel> _extractSelfCategoryChildren(
      Map<String, dynamic> response) {
    final dynamic rawSelf = response['self_category'] ??
        (response['data'] is Map<String, dynamic>
            ? (response['data'] as Map<String, dynamic>)['self_category']
            : null);
    if (rawSelf is Map<String, dynamic>) {
      final CategoryModel root = CategoryModel.fromJson(rawSelf);
      return (root.children ?? const <CategoryModel>[])
          .where((category) => category.id != null)
          .toList();
    }
    return const <CategoryModel>[];
  }

  void _toggleCategory(int id) {
    if (id < 0) return;
    setState(() {
      if (_selectedCategoryIds.contains(id)) {
        _selectedCategoryIds.remove(id);
      } else {
        _selectedCategoryIds.add(id);
      }
    });
  }

  void _submit() {
    if (_selectedCategoryIds.isEmpty) {
      HelperUtils.showSnackBarMessage(
        context,
        'pleaseSelectAtLeastOneBusinessCategory'.translate(context),
      );
      return;
    }

    widget.onNext(
      Phase2Data(
        categoryIds: _selectedCategoryIds.toList(),
        workingHours: Map.of(_hours),
      ),
    );
  }

  Future<void> _openCategoriesPicker(List<CategoryModel> categories) async {
    final valid = categories
        .where((e) => e.id != null && (e.name?.trim().isNotEmpty ?? false))
        .toList();
    if (valid.isEmpty) {
      HelperUtils.showSnackBarMessage(
        context,
        'áÇ ÊæÌÏ ÝÆÇÊ ãÊÇÍÉ ÍÇáíÇð.',
      );
      return;
    }

    final result = await showLegacyCategoriesPalette(
      context: context,
      categories: valid,
      initialSelection: _selectedCategoryIds.toSet(),
    );

    if (result != null && mounted) {
      setState(() {
        _selectedCategoryIds
          ..clear()
          ..addAll(result);

        _selectedCategoryLabels = valid
            .where((c) => c.id != null && result.contains(c.id))
            .map((c) => c.name?.trim() ?? '')
            .where((name) => name.isNotEmpty)
            .toList();
      });
    }
  }

  Future<void> _openWorkingHoursSheet() async {
    final initial = <int, LegacyDayHours>{
      for (int i = 0; i < 7; i++)
        i: LegacyDayHours(
          enabled: _hours[i]!.enabled,
          from: _hours[i]!.from,
          to: _hours[i]!.to,
        ),
    };

    final result = await showLegacyWorkingHoursSheet(
      context: context,
      initialDays: initial,
    );

    if (result != null && mounted) {
      setState(() {
        result.forEach((key, value) {
          _hours[key] = DaySchedule(
            enabled: value.enabled,
            from: value.from ?? _hours[key]!.from,
            to: value.to ?? _hours[key]!.to,
          );
        });
      });
    }
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    final theme = context.color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: context.font.extraLarge,
            fontWeight: FontWeight.w700,
            color: theme.textColorDark,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: context.font.normal,
            color: theme.textColorDark.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryCard(bool loading, List<CategoryModel> categories) {
    final colors = context.color;
    final selectedCount = _selectedCategoryIds.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.category_rounded, color: colors.territoryColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Ø§Ø®ØªÙŠØ§Ø± Ø§Ù„Ø£Ù‚Ø³Ø§Ù…',
                style: TextStyle(
                  fontSize: context.font.large,
                  fontWeight: FontWeight.w700,
                  color: colors.textColorDark,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'ÙŠÙ…ÙƒÙ†Ùƒ ØªØ¹Ø¯ÙŠÙ„ Ù‡Ø°Ù‡ Ø§Ù„Ø£Ù‚Ø³Ø§Ù… Ù„Ø§Ø­Ù‚Ø§Ù‹ Ù…Ù† Ø¥Ø¹Ø¯Ø§Ø¯Ø§Øª Ø§Ù„Ù…ØªØ¬Ø± ÙÙŠ Ø£ÙŠ ÙˆÙ‚Øª.',
          style: TextStyle(
            fontSize: context.font.small,
            color: colors.textColorDark.withValues(alpha: 0.7),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 52,
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: loading ? null : () => _openCategoriesPicker(categories),
            icon: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.tune_rounded),
            label: Text('Ø§Ø®ØªÙŠØ§Ø± Ø§Ù„Ø£Ù‚Ø³Ø§Ù… â€¢ $selectedCount'),
            style: FilledButton.styleFrom(
              backgroundColor: colors.territoryColor,
              foregroundColor: Colors.white,
              textStyle: TextStyle(
                fontSize: context.font.normal,
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildSelectedCategoriesSummary(List<CategoryModel> categories) {
    final labels = _selectedCategoryLabels;
    if (labels.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.only(start: 4, end: 4),
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: labels.length,
        itemBuilder: (_, index) {
          final name = labels[index];
          final int? id = _selectedCategoryIds.length > index
              ? _selectedCategoryIds.elementAt(index)
              : null;
          return InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: id != null ? () => _toggleCategory(id) : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: context.color.territoryColor),
                color: context.color.territoryColor.withValues(alpha: 0.08),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_rounded,
                      size: 16, color: context.color.territoryColor),
                  const SizedBox(width: 6),
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: context.font.small,
                      fontWeight: FontWeight.w600,
                      color: context.color.territoryColor,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  Widget _buildWorkingHoursCard() {
    final colors = context.color;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.access_time_filled, color: colors.primaryColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'ÃæÞÇÊ ÇáÚãá',
                style: TextStyle(
                  fontSize: context.font.large,
                  fontWeight: FontWeight.w700,
                  color: colors.textColorDark,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'ÇÖÈØ ÃæÞÇÊ Úãá ãÊÌÑß ÈÓåæáÉ¡ æÃÖÝ ÃíÇã ÇáÅÌÇÒÉ Ãæ ÇáÝÊÑÇÊ ÇáÎÇÕÉ.',
          style: TextStyle(
            fontSize: context.font.small,
            color: colors.textColorDark.withValues(alpha: 0.7),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 52,
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _openWorkingHoursSheet,
            icon: const Icon(Icons.schedule),
            label: const Text('ÖÈØ ÃæÞÇÊ ÇáÚãá'),
            style: FilledButton.styleFrom(
              backgroundColor: colors.territoryColor,
              foregroundColor: Colors.white,
              textStyle: TextStyle(
                fontSize: context.font.normal,
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildWorkingHoursSummary(),
      ],
    );
  }

  Widget _buildWorkingHoursSummary() {
    const weekdays = [
      'Ø§Ù„Ø£Ø­Ø¯',
      'Ø§Ù„Ø¥Ø«Ù†ÙŠÙ†',
      'Ø§Ù„Ø«Ù„Ø§Ø«Ø§Ø¡',
      'Ø§Ù„Ø£Ø±Ø¨Ø¹Ø§Ø¡',
      'Ø§Ù„Ø®Ù…ÙŠØ³',
      'Ø§Ù„Ø¬Ù…Ø¹Ø©',
      'Ø§Ù„Ø³Ø¨Øª'
    ];

    return Column(
      children: List.generate(7, (index) {
        final entry = _hours[index]!;
        final enabled = entry.enabled;
        final text = enabled
            ? '${entry.from.format(context)} - ${entry.to.format(context)}'
            : 'Ù…ØºÙ„Ù‚';
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  weekdays[index],
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: context.color.textColorDark,
                  ),
                ),
              ),
              Text(
                text,
                style: TextStyle(
                  color: enabled
                      ? context.color.textColorDark.withValues(alpha: 0.8)
                      : context.color.textColorDark.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Future<bool> _handlePop() async {
    widget.onBack();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<List<CategoryModel>>(
      future: _categoriesFuture,
      builder: (context, snapshot) {
        final bool loading = _categoriesFuture == null ||
            snapshot.connectionState != ConnectionState.done;
        final List<CategoryModel> categories = snapshot.data ?? [];
        return WillPopScope(
          onWillPop: _handlePop,
          child: Scaffold(
      resizeToAvoidBottomInset: false,
            body: SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(
                      'Ø§Ù„ÙØ¦Ø§Øª ÙˆØ³Ø§Ø¹Ø§Øª Ø§Ù„Ø¹Ù…Ù„',
                      'Ø§Ø®ØªØ± Ø§Ù„Ø£Ù‚Ø³Ø§Ù… Ø§Ù„ØªÙŠ ØªÙ…Ø«Ù„ Ù†Ø´Ø§Ø· Ù…ØªØ¬Ø±ÙƒØŒ Ø«Ù… Ù‚Ù… Ø¨Ø¶Ø¨Ø· Ø³Ø§Ø¹Ø§Øª Ø§Ù„Ø¯ÙˆØ§Ù… Ø§Ù„Ø£Ø³Ø¨ÙˆØ¹ÙŠØ© Ù„Ø¶Ù…Ø§Ù† Ø¥Ø¸Ù‡Ø§Ø± Ø­Ø§Ù„Ø© Ø§Ù„Ù…ØªØ¬Ø± Ø¨Ø¯Ù‚Ø© Ù„Ù„Ù…Ø³ØªØ®Ø¯Ù…ÙŠÙ†.',
                    ),
                    const SizedBox(height: 24),
                    _buildCategoryCard(loading, categories),
                    const SizedBox(height: 24),
                    _buildWorkingHoursCard(),
                  ],
                ),
              ),
            ),
            bottomNavigationBar: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: UiUtils.buildButton(
                  context,
                  onPressed: _submit,
                  buttonTitle: 'nextStage'.translate(context),
                  disabled: !_canProceed,
                  autoManageState: false,
                  autoDisableWhenInvalid: false,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}












