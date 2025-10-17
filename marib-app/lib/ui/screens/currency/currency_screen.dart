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
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:share_plus/share_plus.dart';

import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/utils/extensions/extensions.dart'; // context.color
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';

import 'package:marib/data/cubits/currency/currency_cubit.dart';
import 'package:marib/data/repositories/currency_repository.dart';

// 👇 واجهة العرض (UI-Only)
import 'package:marib/data/repositories/preferences/governorate_preference_repository.dart';
import 'package:marib/data/model/metal_rate.dart';
import 'package:marib/data/repositories/metal_repository.dart';
import 'rates_share_card.dart';

import 'package:marib/data/model/preference_option.dart';
import 'package:marib/data/repositories/metal_repository.dart';
import 'package:marib/data/repositories/preferences/user_preference_repository.dart';

import 'state/state.dart';
import 'view/currency_screen_shell.dart' show CurrencyScreenUI;
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:permission_handler/permission_handler.dart';



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
          UserPreferenceRepository(),
          MetalRepository(),
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
  final GlobalKey _shareBoundaryKey = GlobalKey(debugLabel: 'currencyShareBoundary');

  String _fromCurrency = '';
  String _toCurrency = '';
  double _convertedAmount = 0.0;
  bool _hasCalculated = false;
  final Map<int, int> _selectedHistoryRanges = <int, int>{};
  int _defaultHistoryRange = 7;
  bool _isSharingRates = false;


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

  Future<void> _onShareRates(CurrencyViewState viewState) async {
    final List<dynamic> currencyRates = viewState.displayRates;
    final List<MetalRate> goldRates = viewState.displayGoldRates;
    final List<MetalRate> silverRates = viewState.displaySilverRates;

    if (currencyRates.isEmpty && goldRates.isEmpty && silverRates.isEmpty) {
      return;
    }

    if (_isSharingRates) {
      return;
    }

    final NumberFormat priceFormat = NumberFormat('#,##0.000');
    final StringBuffer buffer = StringBuffer();



    if (currencyRates.isNotEmpty) {
      final String applied = viewState.appliedGovernorateName ?? 'المتوسط الافتراضي';
      final String? requested = viewState.requestedGovernorateName;
      final String locationLine = (requested != null && requested != applied)
          ? 'المحافظة: $applied (بديل عن $requested)'
          : 'المحافظة: $applied';
      final String stamp = viewState.lastUpdatedAt != null
          ? DateFormat('yyyy-MM-dd HH:mm').format(viewState.lastUpdatedAt!)
          : 'غير متاح';

      buffer.writeln('💰 أسعار العملات - $applied 💰\n');

      for (final dynamic rate in currencyRates) {

        final dynamic r = rate;
        final String name = r.currencyName?.toString() ?? '';
        final String sell = r.sellPrice?.toString() ?? '';
        final String buy = r.buyPrice?.toString() ?? '';
        String sourceLabel = 'غير متاح';
        try {
          final dynamic rawSource = r.quoteSource;
          if (rawSource is String && rawSource.trim().isNotEmpty) {
            sourceLabel = rawSource.trim();
          }
        } catch (_) {}
        buffer.writeln('💱 $name');
        buffer.writeln('بيع: $sell');
        buffer.writeln('شراء: $buy');
        buffer.writeln('المصدر: $sourceLabel\n');
      }

      buffer.writeln('📍 $locationLine');
      buffer.writeln('📅 تم التحديث: $stamp\n');
    }

    if (goldRates.isNotEmpty) {
      buffer.writeln('🟡 أسعار الذهب:');
      for (final MetalRate rate in goldRates) {
        final String sourceLabel =
        rate.source != null && rate.source!.trim().isNotEmpty
            ? rate.source!.trim()
            : 'غير متاح';
        buffer.writeln('• ${rate.displayName}');
        buffer.writeln(
            'بيع: ${priceFormat.format(rate.sellPrice)} | شراء: ${priceFormat.format(rate.buyPrice)}');
        buffer.writeln('المصدر: $sourceLabel\n');
      }

    }

    if (silverRates.isNotEmpty) {
      buffer.writeln('⚪ أسعار الفضة:');
      for (final MetalRate rate in silverRates) {
        final String sourceLabel =
        rate.source != null && rate.source!.trim().isNotEmpty
            ? rate.source!.trim()
            : 'غير متاح';
        buffer.writeln('• ${rate.displayName}');
        buffer.writeln(
            'بيع: ${priceFormat.format(rate.sellPrice)} | شراء: ${priceFormat.format(rate.buyPrice)}');
        buffer.writeln('المصدر: $sourceLabel\n');

      }

    }


    if (viewState.metalsLastUpdatedAt != null) {
      buffer.writeln(
          '⏱️ آخر تحديث للمعادن: ${DateFormat('yyyy-MM-dd HH:mm').format(viewState.metalsLastUpdatedAt!)}');
      buffer.writeln('');
    }

    buffer.writeln('🔗 حمل تطبيق "مارب بين يديك" الآن للاستفادة من المزيد من الخدمات المميزة!');

    final String shareText = buffer.toString().trim();

    _isSharingRates = true;

    try {
      if (!await _ensureSharePermission()) {
        if (!mounted) {
          await Share.share(shareText);
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لم يتم منح إذن مشاركة الصور. سيتم مشاركة النص فقط.'),
          ),
        );
        await Share.share(shareText);
        return;
      }

      if (!mounted) {
        await Share.share(shareText);
        return;
      }

      final OverlayState? overlayState = Overlay.of(context);
      if (overlayState == null) {
        await Share.share(shareText);
        return;
      }

      final OverlayEntry overlayEntry = OverlayEntry(
        builder: (BuildContext overlayContext) {
          return RatesShareCard(
            viewState: viewState,
            boundaryKey: _shareBoundaryKey,
          );
        },
      );

      overlayState.insert(overlayEntry);

      try {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await WidgetsBinding.instance.endOfFrame;

        final RenderRepaintBoundary? boundary =
        _shareBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;

        if (boundary == null) {
          debugPrint('Currency share boundary not found, sharing text only.');
          await Share.share(shareText);
          return;
        }

        final double pixelRatio =
        MediaQuery.of(context).devicePixelRatio.clamp(2.0, 4.0).toDouble();
        final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
        final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

        if (byteData == null) {
          debugPrint('Currency share capture failed (no byteData), sharing text only.');
          await Share.share(shareText);
          return;
        }

        final Uint8List pngBytes = byteData.buffer.asUint8List();
        final XFile shareFile = XFile.fromData(
          pngBytes,
          mimeType: 'image/png',
          name: 'marib_rates_${DateTime.now().millisecondsSinceEpoch}.png',
        );

        await Share.shareXFiles(<XFile>[shareFile], text: shareText);
      } finally {
        overlayEntry.remove();
      }
    } catch (error, stackTrace) {
      debugPrint('Currency share failed: $error\n$stackTrace');
      await Share.share(shareText);
    } finally {
      _isSharingRates = false;
    }
  }


  Future<bool> _ensureSharePermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return true;
    }

    final Permission permission = Platform.isIOS ? Permission.photos : Permission.storage;
    final PermissionStatus currentStatus = await permission.status;

    if (currentStatus.isGranted || currentStatus.isLimited) {
      return true;
    }

    final PermissionStatus requestedStatus = await permission.request();
    return requestedStatus.isGranted || requestedStatus.isLimited;

  }




  void _onToggleWatchlistFilter(bool enabled) {
    context.read<CurrencyCubit>().toggleWatchlistFilter(enabled);
  }

  void _onToggleCurrencyWatchlist(int currencyId) {
    context.read<CurrencyCubit>().toggleCurrencyWatchlist(currencyId);
  }

  void _onToggleMetalWatchlist(int metalId) {
    context.read<CurrencyCubit>().toggleMetalWatchlist(metalId);
  }

  void _onNotificationFrequencyChanged(String value) {
    context.read<CurrencyCubit>().changeNotificationFrequency(value);
  }

  void _onHistoryRangeSelected(int? currencyId, int days) {
    if (days != 1 && days != 3 && days != 7) {
      return;
    }
    setState(() {
      if (currencyId == null) {
        _defaultHistoryRange = days;
        _selectedHistoryRanges.removeWhere((_, value) => value == days);
        return;
      }
      if (days == _defaultHistoryRange) {
        _selectedHistoryRanges.remove(currencyId);
      } else {
        _selectedHistoryRanges[currencyId] = days;
      }
    });
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
            currency: CurrencyRatesState(
              rates: const [],
              displayRates: const [],
              lastUpdatedAt: null,
              watchlist: const <int>{},
              showWatchlistOnly: false,
              selectedHistoryRanges:
              Map<int, int>.from(_selectedHistoryRanges),
              defaultHistoryRangeDays: _defaultHistoryRange,
            ),
            gold: GoldRatesState(
              rates: const [],
              displayRates: const [],
              watchlist: const <int>{},
            ),
            silver: SilverRatesState(
              rates: const [],
              displayRates: const [],
              watchlist: const <int>{},
            ),
            metalsLastUpdatedAt: null,

            governorates: const [],
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
            notificationFrequency: 'daily',
            notificationOptions: const <PreferenceOption>[],
          );
        } else if (state is CurrencyError) {
          viewState = CurrencyViewState(
            status: CurrencyPageStatus.error,
            errorMessage: state.message,
            currency: CurrencyRatesState(
              rates: const [],
              displayRates: const [],
              lastUpdatedAt: null,
              watchlist: const <int>{},
              showWatchlistOnly: false,
              selectedHistoryRanges:
              Map<int, int>.from(_selectedHistoryRanges),
              defaultHistoryRangeDays: _defaultHistoryRange,
            ),
            gold: GoldRatesState(
              rates: const [],
              displayRates: const [],
              watchlist: const <int>{},
            ),
            silver: SilverRatesState(
              rates: const [],
              displayRates: const [],
              watchlist: const <int>{},
            ),
            metalsLastUpdatedAt: null,
            governorates: const [],
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
            notificationFrequency: 'daily',
            notificationOptions: const <PreferenceOption>[],
          );
        } else if (state is CurrencySuccess) {
          final rates = state.currencyRates;
          final goldRates = state.metalRates

              .where((rate) => rate.isGold)
              .toList(growable: false);
          final silverRates = state.metalRates
              .where((rate) => rate.isSilver)
              .toList(growable: false);
          final displayRates = state.visibleCurrencyRates;
          final displayGoldRates = state.visibleMetalRates
              .where((rate) => rate.isGold)
              .toList(growable: false);
          final displaySilverRates = state.visibleMetalRates
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


          final currencyState = CurrencyRatesState(

            rates: rates,

            displayRates: displayRates,
            lastUpdatedAt: updatedAt,
            watchlist: state.preferences.currencyWatchlist,
            showWatchlistOnly: state.showWatchlistOnly,
            selectedHistoryRanges:
            Map<int, int>.from(_selectedHistoryRanges),
            defaultHistoryRangeDays: _defaultHistoryRange,
          );

          final Set<int> metalWatchlist = state.preferences.metalWatchlist;
          final goldState = GoldRatesState(
            rates: goldRates,
            displayRates: displayGoldRates,
            watchlist: metalWatchlist,
          );
          final silverState = SilverRatesState(
            rates: silverRates,
            displayRates: displaySilverRates,
            watchlist: metalWatchlist,
          );

          viewState = CurrencyViewState(
            status: CurrencyPageStatus.ready,
            currency: currencyState,
            gold: goldState,
            silver: silverState,
            metalsLastUpdatedAt: state.metalsLastUpdatedAt,

            governorates: governorateOptions,
            selectedGovernorateCode: selectedCode,

            appliedGovernorateCode: appliedCode,
            appliedGovernorateName: appliedName,
            requestedGovernorateCode: requestedCode,
            requestedGovernorateName: requestedName,
            usedFallback: state.usedFallback,
            notificationFrequency: state.preferences.notificationFrequency,
            notificationOptions: state.notificationOptions,

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
            currency: CurrencyRatesState(
              rates: const [],
              displayRates: const [],
              lastUpdatedAt: null,
              watchlist: const <int>{},
              showWatchlistOnly: false,
              selectedHistoryRanges:
              Map<int, int>.from(_selectedHistoryRanges),
              defaultHistoryRangeDays: _defaultHistoryRange,
            ),
            gold: GoldRatesState(
              rates: const [],
              displayRates: const [],
              watchlist: const <int>{},
            ),
            silver: SilverRatesState(
              rates: const [],
              displayRates: const [],
              watchlist: const <int>{},
            ),
            metalsLastUpdatedAt: null,
            governorates: const [],
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
            notificationFrequency: 'daily',
            notificationOptions: const <PreferenceOption>[],
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

          onToggleWatchlistFilter: _onToggleWatchlistFilter,
          onToggleCurrencyWatchlist: _onToggleCurrencyWatchlist,
          onToggleMetalWatchlist: _onToggleMetalWatchlist,
          onNotificationFrequencyChanged: _onNotificationFrequencyChanged,
          onSelectHistoryRange: _onHistoryRangeSelected,

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
