import 'package:flutter/material.dart';

class AttributeSelectorSection extends StatelessWidget {
  const AttributeSelectorSection({
    super.key,
    required this.title,
    required this.values,
    required this.selectedValue,
    required this.onValueSelected,
    this.showOptionalChoice = false,
    this.optionalLabel = 'بدون اختيار',
    this.emptyStateMessage = 'لا توجد قيم محددة لهذه السمة.',
    this.isRequired = false,
  });

  final String title;
  final List<String> values;
  final String selectedValue;
  final ValueChanged<String> onValueSelected;
  final bool showOptionalChoice;
  final String optionalLabel;
  final String emptyStateMessage;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (values.isEmpty && !showOptionalChoice) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isRequired ? '$title *' : title,
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            emptyStateMessage,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
        ],
      );
    }

    final descriptors = <_AttributeValueDescriptor>[
      if (showOptionalChoice)
        _AttributeValueDescriptor(
          value: '',
          label: optionalLabel,
          isOptional: true,
        ),
      ...values.map(
            (value) => _AttributeValueDescriptor(
          value: value,
          label: value,
          isOptional: false,
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isRequired ? '$title *' : title,
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 56,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: descriptors.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final descriptor = descriptors[index];
              final selected = descriptor.value == selectedValue;
              return AttributeChoiceChip(
                label: descriptor.label,
                selected: selected,
                isOptional: descriptor.isOptional,
                onTap: () => onValueSelected(descriptor.value),
              );
            },
          ),
        ),
      ],
    );
  }
}

class AttributeChoiceChip extends StatelessWidget {
  const AttributeChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.isOptional = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isOptional;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final baseTextColor = theme.textTheme.bodyMedium?.color ?? colorScheme.onSurface;
    final textColor = selected ? colorScheme.primary : baseTextColor;
    final backgroundColor = selected ? colorScheme.primary.withOpacity(0.12) : theme.colorScheme.surface;
    final borderColor = selected ? colorScheme.primary : colorScheme.outline.withOpacity(0.3);

    final semanticsLabel = label.isEmpty ? '—' : label;
    final semanticsText = isOptional ? '$semanticsLabel (اختياري)' : semanticsLabel;

    return Semantics(
      button: true,
      selected: selected,
      label: semanticsText,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 170),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: 1.2),
              boxShadow: selected
                  ? [
                BoxShadow(
                  color: colorScheme.primary.withOpacity(0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
                  : null,
            ),
            child: Text(
              label.isEmpty ? '—' : label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: textColor,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ) ??
                  TextStyle(
                    color: textColor,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AttributeValueDescriptor {
  const _AttributeValueDescriptor({
    required this.value,
    required this.label,
    required this.isOptional,
  });

  final String value;
  final String label;
  final bool isOptional;
}