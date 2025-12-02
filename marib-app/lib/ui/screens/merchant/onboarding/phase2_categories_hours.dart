import 'package:flutter/material.dart';
import 'package:marib/data/model/category_model.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/ui_utils.dart';

import 'widgets/legacy_selectors.dart';

typedef DaySchedule = LegacyDayHours;

class Phase2Data {
  final Set<int> selectedCategories;
  final Map<int, LegacyDayHours> workingHours;
  final bool workingHoursSet;

  Phase2Data({
    required this.selectedCategories,
    required this.workingHours,
    required this.workingHoursSet,
  });

  Set<int> get categoryIds => selectedCategories;
}

class Phase2CategoriesHours extends StatefulWidget {
  final Future<List<CategoryModel>> Function() loadCategories;
  final VoidCallback onBack;
  final void Function(Phase2Data data) onNext;
  final ValueNotifier<int>? visibilityNotifier;
  final int? pageIndex;

  const Phase2CategoriesHours({
    super.key,
    required this.loadCategories,
    required this.onBack,
    required this.onNext,
    this.visibilityNotifier,
    this.pageIndex,
  });

  @override
  State<Phase2CategoriesHours> createState() => _Phase2CategoriesHoursState();
}

class _Phase2CategoriesHoursState extends State<Phase2CategoriesHours>
    with AutomaticKeepAliveClientMixin {
  late Future<List<CategoryModel>> _categoriesFuture;
  Set<int> _selected = <int>{};
  late Map<int, LegacyDayHours> _hours;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = widget.loadCategories();
    _hours = {for (int i = 0; i < 7; i++) i: LegacyDayHours(enabled: false)};
  }

  @override
  bool get wantKeepAlive => true;

  Future<void> _openCategoriesSelector(List<CategoryModel> categories) async {
    final result = await showLegacyCategoriesPalette(
      context: context,
      categories: categories,
      initialSelection: _selected,
    );
    if (result != null) {
      setState(() => _selected = result);
    }
  }

  Future<void> _openWorkingHoursSheet() async {
    final result = await showLegacyWorkingHoursSheet(
      context: context,
      initialDays: _hours,
    );
    if (result != null) {
      setState(() => _hours = result);
    }
  }

  bool get _workingHoursValid {
    for (final entry in _hours.values) {
      if (entry.enabled && (entry.from == null || entry.to == null)) {
        return false;
      }
    }
    return true;
  }

  Future<bool> _handlePop() async {
    widget.onBack();
    return false;
  }

  void _handleNext() {
    if (_selected.isEmpty) {
      HelperUtils.showSnackBarMessage(
        context,
        'اختر على الأقل فئة واحدة.',
      );
      return;
    }
    if (!_workingHoursValid) {
      HelperUtils.showSnackBarMessage(
        context,
        'أكمل أوقات الدوام للأيام المفعّلة.',
      );
      return;
    }
    widget.onNext(
      Phase2Data(
        selectedCategories: _selected,
        workingHours: _hours,
        workingHoursSet: _hours.values.any((e) => e.enabled),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<List<CategoryModel>>(
      future: _categoriesFuture,
      builder: (context, snapshot) {
        final bool loading = snapshot.connectionState == ConnectionState.waiting;
        final bool hasError = snapshot.hasError;
        final categories = snapshot.data;

        return WillPopScope(
          onWillPop: _handlePop,
          child: Scaffold(
            backgroundColor: context.color.secondaryColor,
            appBar: AppBar(
              backgroundColor: context.color.secondaryColor,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios),
                onPressed: _handlePop,
              ),
              title: Text(
                'الفئات وساعات العمل',
                style: TextStyle(
                  color: context.color.textDefaultColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            body: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : hasError
                      ? Center(
                          child: Text(
                            'تعذّر تحميل الفئات، حاول مجدداً.',
                            style: TextStyle(color: context.color.textColorDark),
                          ),
                        )
                      : _buildContent(categories!),
            ),
            bottomNavigationBar: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: UiUtils.buildButton(
                  context,
                  buttonTitle: 'nextStage'.translate(context),
                  onPressed: _handleNext,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(List<CategoryModel> categories) {
    final colors = context.color;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            'اختيار الأقسام',
            style: TextStyle(
              fontSize: context.font.extraLarge,
              fontWeight: FontWeight.w700,
              color: colors.textColorDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'اختر الأقسام التي ينتمي لها نشاطك ليظهر متجرك للمستخدمين بشكل صحيح.',
            style: TextStyle(
              fontSize: context.font.normal,
              color: colors.textColorDark.withValues(alpha: 0.75),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _openCategoriesSelector(categories),
              style: OutlinedButton.styleFrom(
                backgroundColor: colors.secondaryColor,
                side: BorderSide(color: colors.territoryColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.category_outlined, color: colors.territoryColor),
                  const SizedBox(width: 10),
                  Text(
                    _selected.isEmpty
                        ? 'اختر الأقسام'
                        : 'تم اختيار ${_selected.length} قسم',
                    style: TextStyle(
                      fontSize: context.font.normal,
                      color: colors.textColorDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right, color: colors.textLightColor),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildWorkingHoursCard(),
        ],
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
                'أوقات العمل',
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
          'اضبط أوقات العمل لتعرض حالة المتجر للزوار بدقة ويستفيد منها نظام التوصيل.',
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
          child: OutlinedButton(
            onPressed: _openWorkingHoursSheet,
            style: OutlinedButton.styleFrom(
              backgroundColor: colors.secondaryColor,
              side: BorderSide(color: colors.territoryColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: Row(
              children: [
                Icon(Icons.schedule, color: colors.territoryColor),
                const SizedBox(width: 10),
                Text(
                  'ضبط أوقات العمل',
                  style: TextStyle(
                    fontSize: context.font.normal,
                    fontWeight: FontWeight.w600,
                    color: colors.textColorDark,
                  ),
                ),
                const Spacer(),
                Icon(Icons.chevron_right, color: colors.textLightColor),
              ],
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
      'الأحد',
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت'
    ];

    return Column(
      children: List.generate(7, (index) {
        final entry = _hours[index]!;
        final enabled = entry.enabled;
        final text = enabled && entry.from != null && entry.to != null
            ? '${entry.from!.format(context)} - ${entry.to!.format(context)}'
            : 'مغلق';
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
}
