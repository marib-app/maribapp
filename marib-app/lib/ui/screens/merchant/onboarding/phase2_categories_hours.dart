import 'package:flutter/material.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/data/model/category_model.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/api.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/ui_utils.dart';

class Phase2Data {
  final List<int> categoryIds;
  final Map<int, DaySchedule> workingHours;

  Phase2Data({required this.categoryIds, required this.workingHours});
}

class DaySchedule {
  final bool enabled;
  final TimeOfDay from;
  final TimeOfDay to;

  DaySchedule({required this.enabled, required this.from, required this.to});

  DaySchedule copyWith({bool? enabled, TimeOfDay? from, TimeOfDay? to}) {
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

  const Phase2CategoriesHours({super.key, required this.onBack, required this.onNext});

  @override
  State<Phase2CategoriesHours> createState() => _Phase2CategoriesHoursState();
}

class _Phase2CategoriesHoursState extends State<Phase2CategoriesHours> {
  late Future<List<CategoryModel>> _categoriesFuture;
  final Set<int> _selectedCategoryIds = <int>{};
  final Map<int, DaySchedule> _hours = {
    for (int i = 0; i < 7; i++)
      i: DaySchedule(
        enabled: false,
        from: const TimeOfDay(hour: 9, minute: 0),
        to: const TimeOfDay(hour: 18, minute: 0),
      ),
  };

  @override
  void initState() {
    super.initState();
    _categoriesFuture = _loadCategories();
  }

  Future<List<CategoryModel>> _loadCategories() async {
    final Map<String, dynamic> response =
        await Api.get(url: Api.getCategoriesApi, queryParameters: {Api.page: 1});
    final dynamic data = response['data'];
    if (data is Map<String, dynamic>) {
      final List<dynamic> items = data['items'] ?? data['data'] ?? [];
      return items
          .whereType<Map<String, dynamic>>()
          .map(CategoryModel.fromJson)
          .toList();
    }
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(CategoryModel.fromJson)
          .toList();
    }
    return <CategoryModel>[];
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

  Future<void> _pickTime(int day, bool isFrom) async {
    final TimeOfDay initial = isFrom ? _hours[day]!.from : _hours[day]!.to;
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked != null) {
      setState(() {
        _hours[day] = isFrom
            ? _hours[day]!.copyWith(from: picked)
            : _hours[day]!.copyWith(to: picked);
      });
    }
  }

  void _applyToAll() {
    final DaySchedule reference = _hours[0]!;
    setState(() {
      for (int i = 0; i < 7; i++) {
        _hours[i] = _hours[i]!.copyWith(
          enabled: reference.enabled,
          from: reference.from,
          to: reference.to,
        );
      }
    });
  }

  void _submit() {
    if (_selectedCategoryIds.isEmpty) {
      HelperUtils.showSnackBarMessage(
          context, 'pleaseSelectAtLeastOneBusinessCategory'.translate(context));
      return;
    }
    widget.onNext(Phase2Data(
      categoryIds: _selectedCategoryIds.toList(),
      workingHours: Map.of(_hours),
    ));
  }

  Widget _buildDaysColumn() {
    const weekdays = ['sat', 'sun', 'mon', 'tue', 'wed', 'thu', 'fri'];
    return Column(
      children: List.generate(7, (index) {
        final DaySchedule schedule = _hours[index]!;
        return ListTile(
          title: Text(weekdays[index].translate(context)),
          subtitle: Text(schedule.enabled
              ? '${schedule.from.format(context)} � ${schedule.to.format(context)}'
              : 'closed'.translate(context)),
          trailing: Switch.adaptive(
            value: schedule.enabled,
            onChanged: (value) {
              setState(() {
                _hours[index] = schedule.copyWith(enabled: value);
              });
            },
          ),
          onTap: schedule.enabled
              ? () async {
                  await showDialog<void>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text('adjustHours'.translate(context)),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            title: Text('from'.translate(context)),
                            trailing: TextButton(
                              onPressed: () => _pickTime(index, true),
                              child: Text(schedule.from.format(context)),
                            ),
                          ),
                          ListTile(
                            title: Text('to'.translate(context)),
                            trailing: TextButton(
                              onPressed: () => _pickTime(index, false),
                              child: Text(schedule.to.format(context)),
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: Text('close'.translate(context)),
                        ),
                      ],
                    ),
                  );
                }
              : null,
        );
      }),
    );
  }

  Widget _buildCategoryChips(List<CategoryModel> categories) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: categories
          .map((category) => FilterChip(
                label: Text(category.name ?? 'unknown'.translate(context)),
                selected: category.id != null && _selectedCategoryIds.contains(category.id),
                onSelected: category.id != null ? (_) => _toggleCategory(category.id!) : null,
              ))
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.color;
    return FutureBuilder<List<CategoryModel>>(
      future: _categoriesFuture,
      builder: (context, snapshot) {
        final bool loading = snapshot.connectionState != ConnectionState.done;
        final List<CategoryModel> categories = snapshot.data ?? [];
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text('phase2_title'.translate(context)).size(context.font.extraLarge).color(theme.textDefaultColor).bold(),
            const SizedBox(height: 14),
            Text('phase2_description'.translate(context))
                .color(theme.textColorDark.withOpacity(0.75))
                .size(context.font.normal),
            const SizedBox(height: 18),
            Text('selectCategories'.translate(context))
                .size(context.font.large)
                .color(theme.textDefaultColor)
                .bold(),
            const SizedBox(height: 10),
            if (loading) ...[
              const SizedBox(height: 180, child: Center(child: CircularProgressIndicator())),
            ] else
              _buildCategoryChips(categories),
            const SizedBox(height: 16),
            Divider(color: theme.borderColor),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _applyToAll,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      backgroundColor: theme.secondaryColor,
                    ),
                    child: Text('applyToAllDays'.translate(context))
                        .size(context.font.normal)
                        .color(theme.textDefaultColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildDaysColumn(),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onBack,
                    child: Text('back'.translate(context)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: UiUtils.buildButton(
                    context,
                    onPressed: _submit,
                    buttonTitle: 'nextStage'.translate(context),
                    radius: 12,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
