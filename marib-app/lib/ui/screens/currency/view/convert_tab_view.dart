import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:marib/data/model/currency_rate.dart';
import 'dart:ui' as ui;
import '../state/state.dart';
import 'convert/convert_action_buttons.dart';
import 'convert/convert_amount_input.dart';
import 'convert/convert_currency_selector.dart';
import 'convert/convert_governorate_section.dart';
import 'convert/convert_header.dart';

class ConvertTabView extends StatefulWidget {
  const ConvertTabView({
    super.key,
    required this.state,
    required this.amountController,
    required this.onChangeFrom,
    required this.onChangeTo,
    required this.onAmountChanged,
    required this.onReset,
    required this.onConvert,
    required this.amountInputFormatters,
    required this.brand,
    required this.onGovernorateChanged,
    this.onShowAdvancedDetails,
  });

  final CurrencyViewState state;
  final TextEditingController amountController;
  final ValueChanged<String> onChangeFrom;
  final ValueChanged<String> onChangeTo;
  final ValueChanged<String> onAmountChanged;
  final VoidCallback onReset;
  final VoidCallback onConvert;
  final List<TextInputFormatter> amountInputFormatters;
  final Color brand;
  final void Function(String?) onGovernorateChanged;
  final VoidCallback? onShowAdvancedDetails;

  @override
  State<ConvertTabView> createState() => _ConvertTabViewState();
}

class _ConvertTabViewState extends State<ConvertTabView> {
  late final TextEditingController _fromCurrencyController;
  late final TextEditingController _toCurrencyController;

  CurrencyViewState get state => widget.state;

  TextEditingController get amountController => widget.amountController;

  ValueChanged<String> get onChangeFrom => widget.onChangeFrom;

  ValueChanged<String> get onChangeTo => widget.onChangeTo;

  ValueChanged<String> get onAmountChanged => widget.onAmountChanged;

  VoidCallback get onReset => widget.onReset;

  VoidCallback get onConvert => widget.onConvert;

  List<TextInputFormatter> get amountInputFormatters =>
      widget.amountInputFormatters;

  Color get brand => widget.brand;

  void Function(String?) get onGovernorateChanged =>
      widget.onGovernorateChanged;

  VoidCallback? get onShowAdvancedDetails => widget.onShowAdvancedDetails;

  @override
  void initState() {
    super.initState();
    _fromCurrencyController = TextEditingController();
    _toCurrencyController = TextEditingController();
  }

  @override
  void dispose() {
    _fromCurrencyController.dispose();
    _toCurrencyController.dispose();
    super.dispose();
  }

  CurrencyRate? _resolveSelectedCurrencyRate() {
    final Iterable<dynamic> entries = state.rates;
    final String? currencyName = state.fromCurrency.isNotEmpty
        ? state.fromCurrency
        : (state.toCurrency.isNotEmpty ? state.toCurrency : null);
    if (currencyName == null) {
      return null;
    }
    for (final dynamic entry in entries) {
      if (entry is CurrencyRate && entry.currencyName == currencyName) {
        return entry;
      }
    }
    return null;
  }

  void _syncController(
    TextEditingController controller,
    String selection,
    List<String> options,
  ) {
    final String trimmed = selection.trim();
    final String? normalized =
        (trimmed.isEmpty || !options.contains(trimmed)) ? null : trimmed;
    final String newText = normalized ?? '';
    if (controller.text != newText) {
      controller.value = controller.value.copyWith(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const EdgeInsets viewPadding = EdgeInsets.fromLTRB(12, 8, 12, 12);
    final NumberFormat convertedFormat = NumberFormat('#,##0.##');

    final bool isDarkContext = Theme.of(context).brightness == Brightness.dark;
    final Color onBackground = isDarkContext ? Colors.white : Colors.black;

    String _name(dynamic d) => (d as dynamic).currencyName?.toString() ?? '';
    final List<dynamic> all = state.rates;
    final List<String> fromOptions = all.map(_name).toList(growable: false);

    final List<String> toOptions = all
        .where((r) => _name(r) != state.fromCurrency)
        .map(_name)
        .toList(growable: false);

    _syncController(_fromCurrencyController, state.fromCurrency, fromOptions);
    _syncController(_toCurrencyController, state.toCurrency, toOptions);

    final CurrencyRate? selectedRate = _resolveSelectedCurrencyRate();
    final String convertedValue = state.hasCalculated
        ? "${convertedFormat.format(state.convertedAmount)} ${state.toCurrency}"
        : '---';
    void handleSwap() {
      if (state.toCurrency.isNotEmpty && state.fromCurrency.isNotEmpty) {
        final String oldFrom = state.fromCurrency;
        final String oldTo = state.toCurrency;
        onChangeFrom(oldTo);
        onChangeTo(oldFrom);
      }
    }

    return SafeArea(
      top: true,
      bottom: false,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double bottomInset = MediaQuery.of(context).viewInsets.bottom;
          final EdgeInsets scrollPadding = viewPadding.copyWith(
            bottom: viewPadding.bottom,
          );

          return SingleChildScrollView(
            padding: scrollPadding.add(
              EdgeInsets.only(
                bottom: bottomInset > 0 ? bottomInset + 16 : 16,
              ),
            ),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ConvertHeader(state: state, brand: brand),
                const SizedBox(height: 12),
                ConvertGovernorateSection(
                  state: state,
                  brand: brand,
                  selectedRate: selectedRate,
                  onGovernorateChanged: onGovernorateChanged,
                ),
                const SizedBox(height: 16),
                ConvertCurrencySelector(
                  brand: brand,
                  fromOptions: fromOptions,
                  toOptions: toOptions,
                  fromController: _fromCurrencyController,
                  toController: _toCurrencyController,
                  selectedFrom: state.fromCurrency,
                  selectedTo: state.toCurrency,
                  onChangeFrom: onChangeFrom,
                  onChangeTo: onChangeTo,
                  onSwap: handleSwap,
                  isDark: isDarkContext,
                ),
                const SizedBox(height: 16),
                ConvertAmountInput(
                  controller: amountController,
                  inputFormatters: amountInputFormatters,
                  onChanged: onAmountChanged,
                ),
                const SizedBox(height: 12),
                _ConvertedValueText(
                  brand: brand,
                  onBackground: onBackground,
                  convertedValue: convertedValue,
                  onShowAdvancedDetails: onShowAdvancedDetails,
                ),
                const SizedBox(height: 16),
                ConvertActionButtons(
                  brand: brand,
                  onConvert: onConvert,
                  onReset: onReset,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ConvertedValueText extends StatelessWidget {
  const _ConvertedValueText({
    required this.brand,
    required this.onBackground,
    required this.convertedValue,
    this.onShowAdvancedDetails,
  });

  final Color brand;
  final Color onBackground;
  final String convertedValue;
  final VoidCallback? onShowAdvancedDetails;

  @override
  Widget build(BuildContext context) {
    final TextStyle captionStyle =
        Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: onBackground.withOpacity(0.72),
                  fontWeight: FontWeight.w700,
                ) ??
            TextStyle(
              color: onBackground.withOpacity(0.72),
              fontWeight: FontWeight.w700,
            );
    final TextStyle valueStyle =
        Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: onBackground,
                  fontSize: 22,
                ) ??
            TextStyle(
              fontWeight: FontWeight.w900,
              color: onBackground,
              fontSize: 22,
            );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'المبلغ المحول',
                style: captionStyle,
                textDirection: ui.TextDirection.ltr,
              ),
              const SizedBox(height: 4),
              Text(
                convertedValue,
                key: const Key('convertedValueText'),
                style: valueStyle,
                textAlign: TextAlign.right,
              ),
            ],
          ),
        ),
        if (onShowAdvancedDetails != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              key: const Key('advancedDetailsButton'),
              onPressed: onShowAdvancedDetails,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('التفاصيل المتقدمة'),
              style: TextButton.styleFrom(
                foregroundColor: brand,
                padding: const EdgeInsetsDirectional.fromSTEB(10, 0, 12, 0),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
