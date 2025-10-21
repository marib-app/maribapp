import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:marib/data/model/currency_rate.dart';
import 'convert/convert_action_buttons.dart';
import 'convert/convert_amount_input.dart';
import 'convert/convert_currency_selector.dart';
import 'convert/convert_governorate_section.dart';
import 'convert/convert_header.dart';
import 'convert/convert_result_card.dart';

import '../state/state.dart';

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
    final edge = const EdgeInsets.fromLTRB(12, 8, 12, 18);

    final bool isDarkContext = Theme.of(context).brightness == Brightness.dark;

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

    void handleSwap() {
      if (state.toCurrency.isNotEmpty && state.fromCurrency.isNotEmpty) {
        final String oldFrom = state.fromCurrency;
        final String oldTo = state.toCurrency;
        onChangeFrom(oldTo);
        onChangeTo(oldFrom);
      }
    }

    return SafeArea(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double bottomInset = MediaQuery.of(context).viewInsets.bottom;
          final EdgeInsets scrollPadding = edge.copyWith(
            bottom: edge.bottom + bottomInset,
          );

          return SingleChildScrollView(
            padding: scrollPadding,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth:
                    constraints.maxWidth.isFinite ? constraints.maxWidth : 0,
                minHeight: constraints.maxHeight.isFinite
                    ? math.max(0.0, constraints.maxHeight - bottomInset)
                    : 0.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ConvertHeader(state: state, brand: brand),
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
                  const SizedBox(height: 18),
                  ConvertAmountInput(
                    controller: amountController,
                    inputFormatters: amountInputFormatters,
                    onChanged: onAmountChanged,
                  ),
                  const SizedBox(height: 18),
                  ConvertResultCard(
                    brand: brand,
                    isDark: isDarkContext,
                    convertedAmount: state.convertedAmount,
                    hasCalculated: state.hasCalculated,
                    toCurrency: state.toCurrency,
                    onShowAdvancedDetails: onShowAdvancedDetails,
                    actions: ConvertActionButtons(
                      brand: brand,
                      onConvert: onConvert,
                      onReset: onReset,
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
}
