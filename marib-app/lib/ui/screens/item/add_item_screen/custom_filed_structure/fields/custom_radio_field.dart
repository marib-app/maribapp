import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/responsiveSize.dart';

import 'package:marib/utils/ui_utils.dart';
import 'package:marib/utils/validator.dart';

import 'package:marib/ui/screens/item/add_item_screen/custom_filed_structure/custom_field.dart';

/// =====================
/// Logic (Controller)
/// =====================
class CustomRadioField extends CustomField {
  @override
  String type = "radio";

  String? _selected;
  List<String> _values = const [];

  @override
  void init() {
    // تحميل القيم
    final rawValues = parameters['values'];
    if (rawValues is List) {
      _values = rawValues.map((e) => e.toString()).toList();
    }

    // وضع التعديل
    if (parameters['isEdit'] == true) {
      final raw = parameters['value'];
      if (raw is List && raw.isNotEmpty && raw.first != null) {
        _selected = raw.first.toString();
      }
    }

    update(() {});
    super.init();
  }

  @override
  Widget render() {
    final String title = parameters['name'] ?? '';
    final String? notes = (parameters['notes']?.toString().isNotEmpty ?? false)
        ? parameters['notes'].toString()
        : null;
    final dynamic image = parameters['image'];
    final bool requiredField = parameters['required'] == 1;

    return CustomValidator<String?>(
      validator: (_) {
        if (!requiredField) return null;
        if (_selected == null || _selected!.isEmpty) {
          return "pleaseSelectValue".translate(context);
        }
        return null;
      },
      builder: (state) {
        return CustomRadioFieldView(
          // رأس الحقل
          title: title,
          notes: notes,
          image: image,

          // القيم
          values: _values,
          selected: _selected,

          // حالة الفالديشن
          hasError: state.hasError,
          errorText: state.errorText,

          // عند اختيار قيمة
          onSelect: (label) {
            if (_selected == label) {
              _selected = null; // إلغاء الاختيار عند الضغط على نفس الخيار
            } else {
              _selected = label;
            }

            // خزّن في مخزن الحقول
            CustomField.fieldsData[parameters['id'].toString()] =
                _selected == null ? [] : [_selected];

            // بلّغ الفالديتور وحدث الواجهة
            state.didChange(_selected);
            update(() {});

            // هابتك بسيط (اختياري)
            HapticFeedback.selectionClick();
          },
        );
      },
    );
  }
}

/// =====================
/// UI (Presentation Only)
/// =====================
class CustomRadioFieldView extends StatelessWidget {
  const CustomRadioFieldView({
    super.key,
    required this.title,
    required this.values,
    required this.selected,
    required this.onSelect,
    required this.hasError,
    this.notes,
    this.image,
    this.errorText,
  });

  final String title;
  final String? notes;
  final dynamic image;

  final List<String> values;
  final String? selected;

  final bool hasError;
  final String? errorText;

  final void Function(String label) onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(title: title, notes: notes, image: image, hasError: hasError),
        SizedBox(height: 14.rh(context)),

        // خيارات صغيرة ومرنة
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: values.map((label) {
            final isSelected = label == selected;
            final swatch = _tryColor(label);
            return _OptionTile(
              label: label,
              isSelected: isSelected,
              onTap: () => onSelect(label),
              colorSwatch: swatch,
            );
          }).toList(),
        ),

        if (hasError && (errorText?.isNotEmpty ?? false)) ...[
          const SizedBox(height: 6),
          Text(errorText!).size(context.font.small).color(context.color.error),
        ],
      ],
    );
  }

  /// يحاول تفسير النص كقيمة لون HEX (يدعم 6 أو 8 حروف، ويقبل #)
  Color? _tryColor(String raw) {
    try {
      final s = raw.replaceAll('#', '').trim();
      if (RegExp(r'^[A-Fa-f0-9]{6}$').hasMatch(s)) {
        return Color(int.parse('0xFF$s'));
      }
      if (RegExp(r'^[A-Fa-f0-9]{8}$').hasMatch(s)) {
        // لو فيها ألفا، خذ آخر 6 كـ RGB وثبّت الألفا 0xFF
        return Color(int.parse('0xFF${s.substring(s.length - 6)}'));
      }
    } catch (_) {}
    return null;
  }
}

/// هيدر بسيط (أيقونة اختيارية + عنوان + ملاحظات)
class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.hasError,
    this.notes,
    this.image,
  });

  final String title;
  final String? notes;
  final dynamic image;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (image != null) ...[
          Container(
            width: 48.rw(context),
            height: 48.rh(context),
            decoration: BoxDecoration(
              color: context.color.territoryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.none,
                child: UiUtils.imageType(
                  image,
                  width: 24,
                  height: 24,
                  fit: BoxFit.cover,
                  color: context.color.textDefaultColor,
                ),
              ),
            ),
          ),
          SizedBox(width: 10.rw(context)),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 3,
                      softWrap: true)
                  .size(context.font.large)
                  .bold(weight: FontWeight.w500)
                  .color(hasError
                      ? context.color.error
                      : context.color.textColorDark),
              if (notes != null && notes!.isNotEmpty) ...[
                SizedBox(height: 5.rh(context)),
                Text(notes!)
                    .size(context.font.small)
                    .color(context.color.textLightColor),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// عنصر خيار مدمج وخفيف
class _OptionTile extends StatefulWidget {
  const _OptionTile({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.colorSwatch,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? colorSwatch;

  @override
  State<_OptionTile> createState() => _OptionTileState();
}

class _OptionTileState extends State<_OptionTile> {
  bool _hover = false;
  bool _focused = false;
  final FocusNode _focusNode = FocusNode(debugLabel: 'radio_option');

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    final active = colors.territoryColor;
    final baseBorder = colors.borderColor;
    final borderColor = widget.isSelected
        ? active
        : (_hover || _focused ? baseBorder.darken(20) : baseBorder);

    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      child: Actions(
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap();
              return null;
            },
          ),
        },
        child: Semantics(
          button: true,
          selected: widget.isSelected,
          label: widget.label,
          child: FocusableActionDetector(
            focusNode: _focusNode,
            onShowFocusHighlight: (v) => setState(() => _focused = v),
            onShowHoverHighlight: (v) => setState(() => _hover = v),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: widget.onTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  curve: Curves.easeInOut,
                  constraints:
                      const BoxConstraints(minHeight: 36, minWidth: 64),
                  padding:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                  decoration: BoxDecoration(
                    color: widget.isSelected
                        ? active.withOpacity(0.06)
                        : context.color.secondaryColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderColor, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _CompactRadioIndicator(selected: widget.isSelected),
                      const SizedBox(width: 8),
                      if (widget.colorSwatch != null) ...[
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: widget.colorSwatch,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.grey.shade300, width: 1),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          widget.colorSwatch != null
                              ? '#${widget.label}'
                              : widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ).size(context.font.normal).color(
                              widget.isSelected
                                  ? active
                                  : context.color.textDefaultColor
                                      .withOpacity(0.65),
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// مؤشر راديو مدمج وصغير
class _CompactRadioIndicator extends StatelessWidget {
  const _CompactRadioIndicator({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final active = context.color.territoryColor;
    final idle = context.color.textColorDark.withOpacity(.55);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeInOut,
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: selected ? active : idle, width: 1.6),
      ),
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: selected ? 8 : 0,
          height: selected ? 8 : 0,
          decoration: BoxDecoration(
            color: selected ? active : Colors.transparent,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
