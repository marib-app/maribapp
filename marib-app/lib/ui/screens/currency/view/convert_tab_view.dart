import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:marib/data/model/currency_rate.dart';
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
  late final TextEditingController _fromCtrl;
  late final TextEditingController _toCtrl;

  CurrencyViewState get state => widget.state;

  @override
  void initState() {
    super.initState();
    _fromCtrl = TextEditingController(text: state.fromCurrency);
    _toCtrl   = TextEditingController(text: state.toCurrency);
    widget.amountController.addListener(_onAmountChangedLocal);
  }

  @override
  void didUpdateWidget(covariant ConvertTabView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_fromCtrl.text != state.fromCurrency) _fromCtrl.text = state.fromCurrency;
    if (_toCtrl.text   != state.toCurrency)   _toCtrl.text   = state.toCurrency;
  }

  @override
  void dispose() {
    widget.amountController.removeListener(_onAmountChangedLocal);
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  void _onAmountChangedLocal() => setState(() {});

  String _name(dynamic d) => (d as dynamic).currencyName?.toString() ?? '';

  CurrencyRate? _resolveSelectedRate() {
    final String? key = state.fromCurrency.isNotEmpty
        ? state.fromCurrency
        : (state.toCurrency.isNotEmpty ? state.toCurrency : null);
    if (key == null) return null;
    for (final dynamic e in state.rates) {
      if (e is CurrencyRate && e.currencyName == key) return e;
    }
    return null;
  }

  num? _asNum(dynamic v) {
    if (v is num) return v;
    if (v is String) {
      final s = v.replaceAll(',', '').trim();
      return double.tryParse(s);
    }
    return null;
  }

  num? _readBuy(dynamic r) {
    try { final v = (r as dynamic).buyPrice; final n = _asNum(v); if (n != null) return n; } catch (_) {}
    try { final v = (r as dynamic).buy;      final n = _asNum(v); if (n != null) return n; } catch (_) {}
    try { final v = (r as dynamic).purchase; final n = _asNum(v); if (n != null) return n; } catch (_) {}
    try { final v = (r as dynamic).cashBuy;  final n = _asNum(v); if (n != null) return n; } catch (_) {}
    if (r is Map) {
      for (final k in const ['buyPrice','buy','purchase','cashBuy']) {
        final n = _asNum(r[k]);
        if (n != null) return n;
      }
    }
    return null;
  }

  num? _readSell(dynamic r) {
    try { final v = (r as dynamic).sellPrice; final n = _asNum(v); if (n != null) return n; } catch (_) {}
    try { final v = (r as dynamic).sell;      final n = _asNum(v); if (n != null) return n; } catch (_) {}
    try { final v = (r as dynamic).sale;      final n = _asNum(v); if (n != null) return n; } catch (_) {}
    try { final v = (r as dynamic).cashSell;  final n = _asNum(v); if (n != null) return n; } catch (_) {}
    if (r is Map) {
      for (final k in const ['sellPrice','sell','sale','cashSell']) {
        final n = _asNum(r[k]);
        if (n != null) return n;
      }
    }
    return null;
  }

  String _fmt(num v) => NumberFormat('#,##0.##').format(v);

  double? _parseAmount(String s) {
    if (s.trim().isEmpty) return null;
    const arabic = {'٠':'0','١':'1','٢':'2','٣':'3','٤':'4','٥':'5','٦':'6','٧':'7','٨':'8','٩':'9'};
    final normalized = s.split('').map((c) => arabic[c] ?? c).join()
        .replaceAll(RegExp(r'[^0-9\.\,]'), '')
        .replaceAll(',', '');
    return double.tryParse(normalized);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color onBg  = isDark ? Colors.white : Colors.black;

    final List<dynamic> all = state.rates;
    final List<String> fromOptions = all.map(_name).toList(growable: false);
    final List<String> toOptions   =
    all.where((r) => _name(r) != state.fromCurrency).map(_name).toList(growable: false);

    final convertedText = state.hasCalculated
        ? "${NumberFormat('#,##0.##').format(state.convertedAmount)} ${state.toCurrency}"
        : '---';

    final CurrencyRate? rate = _resolveSelectedRate();
    final num buyUnit  = rate != null ? (_readBuy(rate)  ?? 0) : 0;
    final num sellUnit = rate != null ? (_readSell(rate) ?? 0) : 0;

    final double qty   = _parseAmount(widget.amountController.text) ?? 0;
    final num buyTotal  = qty * buyUnit;
    final num sellTotal = qty * sellUnit;

    void handleSwap() {
      if (state.toCurrency.isNotEmpty && state.fromCurrency.isNotEmpty) {
        final f = state.fromCurrency, t = state.toCurrency;
        widget.onChangeFrom(t);
        widget.onChangeTo(f);
      }
    }

    InputDecoration _denseDecoration(String hint) => InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      hintText: hint,
    );

    // ===== المحافظات من السيرفر =====
    const String defaultValue = '_default_';
    final List<DropdownMenuItem<String>> govItems = [
      const DropdownMenuItem<String>(
        value: defaultValue,
        child: Text('المتوسط الافتراضي الوطني', textDirection: ui.TextDirection.rtl),
      ),
      ...state.governorates
          .whereType<Map<String, String?>>()
          .map((g) {
        final String code = (g['code'] ?? '').toString();
        if (code.isEmpty) return null;
        final dynamic rawName = g['name'];
        final String label = (rawName is String && rawName.isNotEmpty) ? rawName : code;
        return DropdownMenuItem<String>(
          value: code,
          child: Text(label, overflow: TextOverflow.ellipsis, textDirection: ui.TextDirection.rtl),
        );
      })
          .whereType<DropdownMenuItem<String>>(),
    ];

    final String selectedGovValue =
    (state.selectedGovernorateCode ?? '').isEmpty ? defaultValue : state.selectedGovernorateCode!;

    final bool hasSelectedGovItem =
    govItems.any((item) => item.value == selectedGovValue);

    if (!hasSelectedGovItem && selectedGovValue != defaultValue) {
      final String fallbackLabel = state.appliedGovernorateName ??
          state.requestedGovernorateName ??
          selectedGovValue;
      govItems.add(
        DropdownMenuItem<String>(
          value: selectedGovValue,
          child: Text(fallbackLabel, textDirection: ui.TextDirection.rtl),
        ),
      );
    }

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: SafeArea(
        top: true, bottom: false,
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(12, 12, 12, (bottomInset > 0 ? bottomInset + 16 : 16)),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ===== شريط أسعار المحافظة (مرتبط بالسيرفر) =====
                    Row(
                      children: [
                        SizedBox(
                          width: 120,
                          child: Text(
                            'أسعار محافظة',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            key: const Key('convertGovernorateDropdown'),
                            value: selectedGovValue,
                            items: govItems,
                            isDense: true,
                            isExpanded: true,
                            iconSize: 18,
                            onChanged: (v) {
                              if (v == defaultValue) {
                                widget.onGovernorateChanged(null);
                              } else {
                                widget.onGovernorateChanged(v);
                              }
                            },
                            decoration: _denseDecoration('اختر المحافظة'),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // صف: من | تبادل | إلى
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: fromOptions.contains(state.fromCurrency) ? state.fromCurrency : null,
                            isDense: true,
                            isExpanded: true,
                            iconSize: 18,
                            items: fromOptions
                                .map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis)))
                                .toList(),
                            onChanged: (v) { if (v != null) widget.onChangeFrom(v); },
                            decoration: _denseDecoration('من'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 44, height: 44,
                          child: OutlinedButton(
                            onPressed: handleSwap,
                            style: OutlinedButton.styleFrom(padding: EdgeInsets.zero, shape: const StadiumBorder()),
                            child: const Icon(Icons.swap_horiz_rounded, size: 22),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: toOptions.contains(state.toCurrency) ? state.toCurrency : null,
                            isDense: true,
                            isExpanded: true,
                            iconSize: 18,
                            items: toOptions
                                .map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis)))
                                .toList(),
                            onChanged: (v) { if (v != null) widget.onChangeTo(v); },
                            decoration: _denseDecoration('إلى'),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // إدخال المبلغ
                    TextField(
                      controller: widget.amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: widget.amountInputFormatters,
                      textAlign: TextAlign.center,
                      decoration: _denseDecoration('ادخل المبلغ'),
                      onChanged: widget.onAmountChanged,
                    ),

                    const SizedBox(height: 12),

                    // المبلغ المحوّل
                    Column(
                      children: [
                        Text(
                          'المبلغ المحول',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: onBg.withOpacity(.72), fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          convertedText,
                          key: const Key('convertedValueText'),
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: onBg, fontWeight: FontWeight.w900, fontSize: 22,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // بطاقتا السعر — ناتج واحد فقط
                    Row(
                      children: [
                        Expanded(child: _priceCard(
                          title: 'سعر الشراء',
                          value: (qty > 0 && buyUnit > 0) ? _fmt(buyTotal) : '—',
                        )),
                        const SizedBox(width: 8),
                        Expanded(child: _priceCard(
                          title: 'سعر البيع',
                          value: (qty > 0 && sellUnit > 0) ? _fmt(sellTotal) : '—',
                        )),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // أزرار
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: widget.onConvert,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: widget.brand,
                              minimumSize: const Size.fromHeight(44),
                              shape: const StadiumBorder(),
                              textStyle: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            child: const Text('تحويل'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: widget.onReset,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(44),
                              shape: const StadiumBorder(),
                              side: BorderSide(color: Colors.orange.shade700, width: 1.4),
                              foregroundColor: Colors.orange.shade700,
                              textStyle: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            child: const Text('تصفير'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _priceCard({required String title, required String value}) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
      ),
    );
  }
}
