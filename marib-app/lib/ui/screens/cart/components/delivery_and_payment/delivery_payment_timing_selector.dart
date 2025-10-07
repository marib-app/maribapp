import 'package:flutter/material.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';







class DeliveryPaymentTimingOption {
  const DeliveryPaymentTimingOption({
    required this.value,
    required this.label,
    this.description,
    this.isDisabled = false,
    this.isInitiallySelected = false,
  });

  final String value;
  final String label;
  final String? description;
  final bool isDisabled;
  final bool isInitiallySelected;
}

List<DeliveryPaymentTimingOption> normalizeDeliveryPaymentTimingOptions(
    List<dynamic>? rawOptions,
    ) {
  if (rawOptions == null || rawOptions.isEmpty) {
    return const <DeliveryPaymentTimingOption>[];
  }

  final List<DeliveryPaymentTimingOption> options =
  <DeliveryPaymentTimingOption>[];

  for (final dynamic entry in rawOptions) {
    if (entry == null) {
      continue;
    }

    if (entry is String) {
      final String? value = _stringValue(entry);
      if (value != null) {
        options.add(
          DeliveryPaymentTimingOption(
            value: value,
            label: value,
          ),
        );
      }
      continue;
    }

    final Map<String, dynamic>? map = _castToStringKeyedMap(entry);
    if (map == null) {
      continue;
    }

    String? value = _stringValue(map['value']) ??
        _stringValue(map['id']) ??
        _stringValue(map['key']) ??
        _stringValue(map['code']) ??
        _stringValue(map['timing']);

    String? label = _stringValue(map['label']) ??
        _stringValue(map['title']) ??
        _stringValue(map['name']) ??
        _stringValue(map['text']) ??
        _stringValue(map['display']) ??
        _stringValue(map['value']);

    final List<String> descriptionParts = <String>[];

    void addDescription(dynamic candidate) {
      final String? resolved = _stringValue(candidate);
      if (resolved != null && !descriptionParts.contains(resolved)) {
        descriptionParts.add(resolved);
      }
    }

    addDescription(map['description']);
    addDescription(map['subtitle']);
    addDescription(map['hint']);
    addDescription(map['note']);
    addDescription(map['details']);

    final String? description =
    descriptionParts.isEmpty ? null : descriptionParts.join('\n');

    final bool isDisabled = (_asBool(map['disabled']) ?? false) ||
        (_asBool(map['enabled']) == false);

    final bool isSelected = _asBool(map['selected']) ??
        _asBool(map['is_selected']) ??
        _asBool(map['default']) ??
        false;

    value ??= label;
    if (value == null) {
      continue;
    }

    options.add(
      DeliveryPaymentTimingOption(
        value: value,
        label: label ?? value,
        description: description,
        isDisabled: isDisabled,
        isInitiallySelected: isSelected,
      ),
    );
  }

  return options;
}

DeliveryPaymentTimingOption? findDeliveryPaymentTimingOption(
    List<DeliveryPaymentTimingOption> options,
    String? value,
    ) {
  if (value == null) {
    return null;
  }
  final String normalized = value.trim();
  if (normalized.isEmpty) {
    return null;
  }

  for (final DeliveryPaymentTimingOption option in options) {
    if (option.value == normalized) {
      return option;
    }
  }
  return null;
}

class DeliveryPaymentTimingSelector extends StatelessWidget {
  const DeliveryPaymentTimingSelector({
    super.key,
    required this.options,
    this.selectedValue,
    this.onSelect,
    this.isLoading = false,
    this.enabled = true,
  });

  final List<DeliveryPaymentTimingOption> options;
  final String? selectedValue;
  final ValueChanged<String>? onSelect;
  final bool isLoading;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) {
      return const SizedBox.shrink();
    }

    String? resolvedSelectedValue = _stringValue(selectedValue);
    if (resolvedSelectedValue != null && resolvedSelectedValue.isEmpty) {
      resolvedSelectedValue = null;
    }

    final bool containsSelected = resolvedSelectedValue != null &&
        options.any(
              (DeliveryPaymentTimingOption option) =>
          option.value == resolvedSelectedValue,
        );

    if (!containsSelected) {
      final DeliveryPaymentTimingOption preselected = options.firstWhere(
            (DeliveryPaymentTimingOption option) => option.isInitiallySelected,
        orElse: () => options.first,
      );
      resolvedSelectedValue = preselected.value;
    }

    DeliveryPaymentTimingOption? resolvedSelectedOption;
    for (final DeliveryPaymentTimingOption option in options) {
      if (option.value == resolvedSelectedValue) {
        resolvedSelectedOption = option;
        break;
      }
    }

    bool hasDescription(DeliveryPaymentTimingOption option) {
      final String? text = option.description?.trim();
      return text != null && text.isNotEmpty;
    }

    final bool useSegmented =
        options.length <= 3 && options.every((option) => !hasDescription(option));

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color accent = context.color.territoryColor;
    final bool interactionsEnabled =
        enabled && !isLoading && onSelect != null;

    Widget buildSegmentedSelector() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ToggleButtons(
            borderRadius: BorderRadius.circular(12),
            constraints: const BoxConstraints(minHeight: 40, minWidth: 72),
            borderColor: accent.withOpacity(0.4),
            selectedBorderColor: accent,
            fillColor: accent.withOpacity(0.12),
            color: context.color.textDefaultColor.withOpacity(0.75),
            selectedColor: accent,
            splashColor: accent.withOpacity(0.15),
            isSelected: options
                .map((DeliveryPaymentTimingOption option) =>
            option.value == resolvedSelectedValue)
                .toList(growable: false),
            onPressed: (int index) {
              final DeliveryPaymentTimingOption option = options[index];
              final bool isOptionEnabled =
                  interactionsEnabled && !option.isDisabled;
              if (!isOptionEnabled) {
                return;
              }
              final String value = option.value;
              if (value != resolvedSelectedValue) {
                onSelect?.call(value);
              }
            },
            children: options.map((DeliveryPaymentTimingOption option) {
              final bool isSelected = option.value == resolvedSelectedValue;
              final bool isOptionEnabled =
                  interactionsEnabled && !option.isDisabled;
              final Color textColor = isSelected
                  ? accent
                  : isOptionEnabled
                  ? context.color.textDefaultColor
                  : context.color.textDefaultColor.withOpacity(0.4);
              return Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  option.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              );
            }).toList(),
          ),
          if (resolvedSelectedOption != null &&
              resolvedSelectedOption.description != null &&
              resolvedSelectedOption.description!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                resolvedSelectedOption.description!,
                style: TextStyle(
                  color: context.color.textDefaultColor.withOpacity(0.75),
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ),
        ],
      );
    }

    Widget buildRadioSelector() {
      return Column(
        children: options.map((DeliveryPaymentTimingOption option) {
          final bool isSelected = resolvedSelectedValue == option.value;
          final bool isOptionEnabled =
              interactionsEnabled && !option.isDisabled;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: isSelected ? accent.withOpacity(0.08) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: RadioListTile<String>(
              value: option.value,
              groupValue: resolvedSelectedValue,
              onChanged: isOptionEnabled
                  ? (String? value) {
                if (value == null) {
                  return;
                }
                if (value != resolvedSelectedValue) {
                  onSelect?.call(value);
                }
              }
                  : null,
              activeColor: accent,
              dense: true,
              visualDensity: VisualDensity.compact,
              contentPadding: const EdgeInsetsDirectional.only(start: 4),
              title: Text(
                option.label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: context.color.textDefaultColor,
                ),
              ),
              subtitle: option.description == null
                  ? null
                  : Text(
                option.description!,
                style: TextStyle(
                  color:
                  context.color.textDefaultColor.withOpacity(0.75),
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              controlAffinity: ListTileControlAffinity.trailing,
            ),
          );
        }).toList(),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, color: accent),
              const SizedBox(width: 8),
              Text(
                'وقت دفع المبلغ المتبقي',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: context.color.textDefaultColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          useSegmented ? buildSegmentedSelector() : buildRadioSelector(),
        ],
      ),
    );
  }
}

String? _stringValue(dynamic value) {
  if (value == null) return null;
  if (value is String) {
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  return value.toString();
}

Map<String, dynamic>? _castToStringKeyedMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map(
          (dynamic key, dynamic value) => MapEntry(key.toString(), value),
    );
  }
  return null;
}

bool? _asBool(dynamic value) {
  if (value == null) return null;
  if (value is bool) {
    return value;
  }
  if (value is num) {
    if (value == 0) return false;
    if (value == 1) return true;
    return value != 0;
  }
  if (value is String) {
    final String normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    if (<String>{'true', '1', 'yes', 'y', 'on'}.contains(normalized)) {
      return true;
    }
    if (<String>{'false', '0', 'no', 'n', 'off'}.contains(normalized)) {
      return false;
    }
  }
  return null;
}