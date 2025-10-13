// lib/new_code/ui/currency/currency_screen.dart
//
// ✅ ملف المنطق فقط (Logic-Only)
// - لا UI هنا. الواجهة بالكامل في currency_screen_ui.dart (CurrencyScreenUI).
// - لا نعتمد على نوع نموذج معيّن (مثل CurrencyRate) لتجنّب أخطاء الأنواع.
// - نستخدم List<dynamic> ونقرأ الخصائص المتوقعة ديناميكيًا.
//
// المتطلبات:
//   • currency_screen_ui.dart يحتوي CurrencyScreenUI المتوافقة مع هذه الواجهة.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:share_plus/share_plus.dart';

import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/utils/extensions/extensions.dart'; // context.color
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';

import 'package:marib/data/cubits/currency/currency_cubit.dart';
import 'package:marib/data/repositories/currency_repository.dart';

// 👇 واجهة العرض (UI-Only)
import 'currency_screen_ui.dart' show CurrencyScreenUI;
import 'package:marib/data/repositories/preferences/governorate_preference_repository.dart';
import 'package:marib/data/model/metal_rate.dart';
import 'package:marib/data/repositories/metal_repository.dart';
/// حالة صفحة العملات
enum CurrencyPageStatus { loading, error, ready }

/// ViewState يُمرَّر للـ UI فقط
class CurrencyViewState {
  final CurrencyPageStatus status;
  final String? errorMessage;

  // بيانات الأسعار (ديناميكية لتفادي خطأ النوع)
  final List<dynamic> rates;
  final DateTime? lastUpdatedAt;
  final List<MetalRate> goldRates;
  final List<MetalRate> silverRates;
  final DateTime? metalsLastUpdatedAt;
  final List<Map<String, String?>> governorates;
  final String? selectedGovernorateCode;
  final String? appliedGovernorateCode;
  final String? appliedGovernorateName;
  final String? requestedGovernorateCode;
  final String? requestedGovernorateName;
  final bool usedFallback;

  // حالة الحاسبة
  final String amountText;
  final String fromCurrency;
  final String toCurrency;
  final double convertedAmount;
  final bool hasCalculated;

  const CurrencyViewState({
    required this.status,
    this.errorMessage,
    required this.goldRates,
    required this.silverRates,
    required this.metalsLastUpdatedAt,
    required this.rates,
    required this.lastUpdatedAt,
    required this.amountText,
    required this.fromCurrency,
    required this.toCurrency,
    required this.convertedAmount,
    required this.hasCalculated,




    required this.governorates,
    required this.selectedGovernorateCode,
    required this.appliedGovernorateCode,
    required this.appliedGovernorateName,
    required this.requestedGovernorateCode,
    required this.requestedGovernorateName,
    required this.usedFallback,

  });

  CurrencyViewState copyWith({
    CurrencyPageStatus? status,
    String? errorMessage,
    List<dynamic>? rates,
    DateTime? lastUpdatedAt,
    List<MetalRate>? goldRates,
    List<MetalRate>? silverRates,
    DateTime? metalsLastUpdatedAt,
    String? amountText,
    String? fromCurrency,
    String? toCurrency,
    double? convertedAmount,
    bool? hasCalculated,
  }) {
    return CurrencyViewState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      rates: rates ?? this.rates,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      amountText: amountText ?? this.amountText,
      goldRates: goldRates ?? this.goldRates,
      silverRates: silverRates ?? this.silverRates,
      metalsLastUpdatedAt: metalsLastUpdatedAt ?? this.metalsLastUpdatedAt,
      fromCurrency: fromCurrency ?? this.fromCurrency,
      toCurrency: toCurrency ?? this.toCurrency,
      convertedAmount: convertedAmount ?? this.convertedAmount,
      hasCalculated: hasCalculated ?? this.hasCalculated,
      governorates: governorates ?? this.governorates,
      selectedGovernorateCode:
      selectedGovernorateCode ?? this.selectedGovernorateCode,
      appliedGovernorateCode:
      appliedGovernorateCode ?? this.appliedGovernorateCode,
      appliedGovernorateName:
      appliedGovernorateName ?? this.appliedGovernorateName,
      requestedGovernorateCode:
      requestedGovernorateCode ?? this.requestedGovernorateCode,
      requestedGovernorateName:
      requestedGovernorateName ?? this.requestedGovernorateName,
      usedFallback: usedFallback ?? this.usedFallback,
    );
  }
}

class CurrencyScreen extends StatelessWidget {
  const CurrencyScreen({super.key});

  static Route route(RouteSettings routeSettings) {
    return BlurredRouter(builder: (_) => const CurrencyScreen());
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: UiUtils.getSystemUiOverlayStyle(
        context: context,
        statusBarColor: context.color.secondaryColor,
      ),
      child: BlocProvider(
        create: (_) => CurrencyCubit(
          CurrencyRepository(),
          MetalRepository(),
          GovernoratePreferenceRepository(),
        )..initialize(),

        child: const _CurrencyScreenLogic(),
      ),
    );
  }
}

class _CurrencyScreenLogic extends StatefulWidget {
  const _CurrencyScreenLogic();

  @override
  State<_CurrencyScreenLogic> createState() => _CurrencyScreenLogicState();
}

class _CurrencyScreenLogicState extends State<_CurrencyScreenLogic>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _amountController = TextEditingController();

  String _fromCurrency = '';
  String _toCurrency = '';
  double _convertedAmount = 0.0;
  bool _hasCalculated = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  // ————— الكولباكات التي يستدعيها الـ UI —————

  void _onChangeFrom(String value, List<dynamic> rates) {
    if (value.isEmpty) return;
    setState(() {
      _fromCurrency = value;
      if (_toCurrency == value && rates.length > 1) {
        _toCurrency = _firstOtherCurrency(rates: rates, not: value) ?? _toCurrency;
      }
      _hasCalculated = false;
    });
  }

  void _onChangeTo(String value) {
    if (value.isEmpty || value == _fromCurrency) return;
    setState(() {
      _toCurrency = value;
      _hasCalculated = false;
    });
  }

  void _onAmountChanged(String _) {
    setState(() => _hasCalculated = false);
  }

  void _onReset() {
    setState(() {
      _amountController.clear();
      _convertedAmount = 0.0;
      _hasCalculated = false;
    });
  }

  void _onConvert(CurrencyCubit cubit) {
    if (_amountController.text.trim().isEmpty) return;
    if (_fromCurrency.isEmpty || _toCurrency.isEmpty) return;
    if (cubit.state is! CurrencySuccess) return;

    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final result = cubit.calculateConversion(
      amount: amount,
      fromCurrency: _fromCurrency,
      toCurrency: _toCurrency,
      isBuying: true,
    );

    setState(() {
      _convertedAmount = result;
      _hasCalculated = true;
    });
  }

  void _onShareRates(CurrencyViewState viewState) {
    final currencyRates = viewState.rates;
    final goldRates = viewState.goldRates;
    final silverRates = viewState.silverRates;

    if (currencyRates.isEmpty && goldRates.isEmpty && silverRates.isEmpty) {
      return;
    }

    final priceFormat = NumberFormat('#,##0.000');

    final buffer = StringBuffer();

    if (currencyRates.isNotEmpty) {
      final applied = viewState.appliedGovernorateName ?? 'المتوسط الافتراضي';
      final requested = viewState.requestedGovernorateName;
      final locationLine = (requested != null && requested != applied)
          ? 'المحافظة: $applied (بديل عن $requested)'
          : 'المحافظة: $applied';
      final stamp = viewState.lastUpdatedAt != null
          ? DateFormat('yyyy-MM-dd HH:mm').format(viewState.lastUpdatedAt!)
          : 'غير متاح';

      buffer.writeln('💰 أسعار العملات - $applied 💰\n');

      for (final rate in currencyRates) {
        final dynamic r = rate;
        final name = r.currencyName?.toString() ?? '';
        final sell = r.sellPrice?.toString() ?? '';
        final buy = r.buyPrice?.toString() ?? '';
        buffer.writeln('💱 $name');
        buffer.writeln('بيع: $sell');
        buffer.writeln('شراء: $buy\n');
      }

      buffer.writeln('📍 $locationLine');
      buffer.writeln('📅 تم التحديث: $stamp\n');
    }

    if (goldRates.isNotEmpty) {
      buffer.writeln('🟡 أسعار الذهب:');
      for (final rate in goldRates) {
        buffer.writeln(
            '• ${rate.displayName}: بيع ${priceFormat.format(rate.sellPrice)} | شراء ${priceFormat.format(rate.buyPrice)}');
      }
      buffer.writeln('');
    }

    if (silverRates.isNotEmpty) {
      buffer.writeln('⚪ أسعار الفضة:');
      for (final rate in silverRates) {
        buffer.writeln(
            '• ${rate.displayName}: بيع ${priceFormat.format(rate.sellPrice)} | شراء ${priceFormat.format(rate.buyPrice)}');
      }
      buffer.writeln('');
    }


    if (viewState.metalsLastUpdatedAt != null) {
      buffer.writeln(
          '⏱️ آخر تحديث للمعادن: ${DateFormat('yyyy-MM-dd HH:mm').format(viewState.metalsLastUpdatedAt!)}');
      buffer.writeln('');
    }

    buffer.writeln('🔗 حمل تطبيق "مارب بين يديك" الآن للاستفادة من المزيد من الخدمات المميزة!');


    Share.share(buffer.toString().trim());

  }

  // ————— أدوات مساعدة داخلية —————

  String? _firstOtherCurrency({
    required List<dynamic> rates,
    required String not,
  }) {
    for (final r in rates) {
      final name = (r as dynamic).currencyName?.toString();
      if (name != null && name != not) return name;
    }
    return rates.isNotEmpty ? (rates.first as dynamic).currencyName?.toString() : null;
  }

  void _ensureInitialSelection(List<dynamic> rates) {
    if (rates.isEmpty) return;
    String _name(dynamic d) => (d as dynamic).currencyName?.toString() ?? '';

    if (_fromCurrency.isEmpty) {
      _fromCurrency = _name(rates.first);
    }
    if (_toCurrency.isEmpty) {
      _toCurrency = rates.length > 1 ? _name(rates[1]) : _name(rates.first);
    }
  }







  void _onGovernorateChanged(String? code) {
    context.read<CurrencyCubit>().changeGovernorate(code);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CurrencyCubit, CurrencyState>(
      builder: (context, state) {
        CurrencyViewState viewState;

        if (state is CurrencyLoading) {
          viewState = CurrencyViewState(
            status: CurrencyPageStatus.loading,
            rates: const [],
            lastUpdatedAt: null,
            amountText: _amountController.text,
            fromCurrency: _fromCurrency,
            goldRates: const [],
            silverRates: const [],
              metalsLastUpdatedAt: null,
            toCurrency: _toCurrency,
            convertedAmount: _convertedAmount,
            hasCalculated: _hasCalculated,
            governorates: const [],
            selectedGovernorateCode: null,
            appliedGovernorateCode: null,
            appliedGovernorateName: null,
            requestedGovernorateCode: null,
            requestedGovernorateName: null,
            usedFallback: false,
          );
        } else if (state is CurrencyError) {
          viewState = CurrencyViewState(
            status: CurrencyPageStatus.error,
            errorMessage: state.message,
            rates: const [],
            lastUpdatedAt: null,
            amountText: _amountController.text,
            fromCurrency: _fromCurrency,
            toCurrency: _toCurrency,
            convertedAmount: _convertedAmount,
            hasCalculated: _hasCalculated,
            goldRates: const [],
            silverRates: const [],
            metalsLastUpdatedAt: null,
            governorates: const [],
            selectedGovernorateCode: null,
            appliedGovernorateCode: null,
            appliedGovernorateName: null,
            requestedGovernorateCode: null,
            requestedGovernorateName: null,
            usedFallback: false,
          );
        } else if (state is CurrencySuccess) {
          final rates = state.currencyRates;
          final goldRates = state.metalRates
              .where((rate) => rate.isGold)
              .toList(growable: false);
          final silverRates = state.metalRates
              .where((rate) => rate.isSilver)
              .toList(growable: false);
          _ensureInitialSelection(rates);

          // محاولة أخذ آخر تحديث من أول عنصر
          DateTime? updatedAt;
          if (rates.isNotEmpty) {
            final first = rates.first as dynamic;
            if (first.lastUpdatedAt is DateTime) {
              updatedAt = first.lastUpdatedAt as DateTime;
            }
          }

          final governorateOptions = state.governorates
              .map((gov) => {
            'code': gov.code,
            'name': gov.name,
          })
              .toList();

          String? requestedCode =
              state.requestedGovernorateCode ?? state.requestedGovernorate?.code;
          String? requestedName = state.requestedGovernorate?.name;
          if (requestedName == null && requestedCode != null) {
            try {
              requestedName = state.governorates
                  .firstWhere((gov) => gov.code == requestedCode)
                  .name;
            } catch (_) {}
          }

          String? appliedCode = state.appliedGovernorate?.code ?? requestedCode;
          String? appliedName = state.appliedGovernorate?.name;
          if (appliedName == null && appliedCode != null) {
            try {
              appliedName = state.governorates
                  .firstWhere((gov) => gov.code == appliedCode)
                  .name;
            } catch (_) {}
          }

          final selectedCode = requestedCode ?? appliedCode;


          viewState = CurrencyViewState(
            status: CurrencyPageStatus.ready,
            rates: rates,
            lastUpdatedAt: updatedAt,
            governorates: governorateOptions,
            selectedGovernorateCode: selectedCode,
            goldRates: goldRates,
            silverRates: silverRates,
            metalsLastUpdatedAt: state.metalsLastUpdatedAt,
            appliedGovernorateCode: appliedCode,
            appliedGovernorateName: appliedName,
            requestedGovernorateCode: requestedCode,
            requestedGovernorateName: requestedName,
            usedFallback: state.usedFallback,


            amountText: _amountController.text,
            fromCurrency: _fromCurrency,
            toCurrency: _toCurrency,
            convertedAmount: _convertedAmount,
            hasCalculated: _hasCalculated,
          );
        } else {
          viewState = CurrencyViewState(
            status: CurrencyPageStatus.error,
            errorMessage: 'حدث خطأ ما',
            rates: const [],
            lastUpdatedAt: null,
            governorates: const [],
            goldRates: const [],
            silverRates: const [],
            metalsLastUpdatedAt: null,
            selectedGovernorateCode: null,
            appliedGovernorateCode: null,
            appliedGovernorateName: null,
            requestedGovernorateCode: null,
            requestedGovernorateName: null,
            usedFallback: false,
            amountText: _amountController.text,
            fromCurrency: _fromCurrency,
            toCurrency: _toCurrency,
            convertedAmount: _convertedAmount,
            hasCalculated: _hasCalculated,
          );
        }

        return CurrencyScreenUI(
          state: viewState,
          tabController: _tabController,
          amountController: _amountController,
          onChangeFrom: (v) => _onChangeFrom(v, viewState.rates),
          onChangeTo: _onChangeTo,
          onAmountChanged: _onAmountChanged,
          onReset: _onReset,
          onConvert: () => _onConvert(context.read<CurrencyCubit>()),
          onShareRates: () => _onShareRates(viewState),
          onGovernorateChanged: _onGovernorateChanged,
          // 🔧 لا تستخدم const هنا
          amountInputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],

          systemUiOverlayStyle: UiUtils.getSystemUiOverlayStyle(
            context: context,
            statusBarColor: context.color.secondaryColor,
          ),
        );
      },
    );
  }
}
