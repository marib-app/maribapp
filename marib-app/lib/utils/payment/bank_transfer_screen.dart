import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:marib/app/app_scroll_behavior.dart';

import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/api.dart';

import 'package:marib/utils/ui_utils.dart';

// شاشة تحويل الأموال عبر التحويل البنكي وخيارات المحافظ.

import 'package:marib/utils/payment/bank_account.dart';
import 'package:marib/utils/payment/manual_payment_service.dart';
import 'package:marib/utils/payment/bank_transfer_args.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:marib/utils/payment/payment_method_cards.dart';
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/data/cubits/wallet/wallet_summary_cubit.dart';
import 'package:marib/data/model/wallet/wallet_summary.dart';
import 'package:marib/utils/notification/notification_service.dart';
import 'package:intl/intl.dart';
import 'package:marib/utils/currency_utils.dart';

import 'package:marib/utils/payment/east_yemen_bank_config.dart';
import 'package:marib/ui/widgets/standard_bottom_sheet_scaffold.dart';
import 'package:marib/utils/money_formatter.dart';
import 'package:marib/utils/payment/payment_route_result.dart';

part 'bank_transfer_screen_ui.dart';

class BankTransferScreen extends StatefulWidget {
  final BankTransferArgs args;

  const BankTransferScreen({super.key, required this.args});

  /// تعرض شاشة التحويل البنكي كصفحة سفلية تمنع الإغلاق العرضي وتساعد
  /// المستخدم على إكمال خطوات الدفع قبل المغادرة.


  static Future<T?> show<T>(BuildContext context, BankTransferArgs args) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return BankTransferScreen(args: args);
      },
    );
  }

  @override
  State<BankTransferScreen> createState() => _BankTransferScreenState();
}

class _BankTransferScreenState extends State<BankTransferScreen>
    with SingleTickerProviderStateMixin {
  final _service = ManualPaymentService();

  late final WalletSummaryCubit _walletSummaryCubit;
  StreamSubscription<WalletSummaryState>? _walletSummarySub;
  StreamSubscription<String>? _walletUpdateSub;
  OverlayEntry? _overlayMessageEntry;
  Timer? _overlayMessageTimer;

  List<BankAccount> _banks = [];
  EastYemenBankConfig? _eastYemenBank;
  String? _selectedMethod;

  bool _loadingBanks = false;
  bool _loadingWallet = false;

  int? _selectedBankId;
  int? _pressedBankId; // لتعقب حالة الضغط على بطاقة البنك (مؤثر Scale)
  int?
      _highlightedAccountNameBankId; // لتعقب تمييز اسم الحساب عند التفاعل مع العنصر
  WalletSummary? _walletSummary;
  dynamic _walletError;
  String? _lastWalletEventKey;
  CurrencyParseResult _settingsCurrencyInfo = const CurrencyParseResult();

  String? _paymentIntentId;
  String? _paymentTransactionId;
  Map<String, dynamic>? _subject;
  Map<String, dynamic>? _next;
  bool _walletGatewayAllowed = true;
  bool _manualGatewayAllowed = true;
  bool _eastGatewayAllowed = true;

  static const String _manualBankMethod = BankTransferGateway.manualBank;
  static const String _eastYemenMethod = BankTransferGateway.eastYemenBank;
  static const String _walletMethod = BankTransferGateway.wallet;
  static const String _walletTopUpPurpose =
      ManualPaymentService.walletTopUpPurpose;

  static const int _eastYemenPressedKey = -1000;
  static const int _walletPressedKey = -1001;
  static const List<String> _allowedReceiptExtensions = <String>[
    'jpg',
    'jpeg',
    'png',
    'pdf',
  ]; // Keep in sync with PaymentController::manual MIME validation.

  // عناصر التحكم الخاصة ببيانات التحويل
  final _senderCtrl = TextEditingController(); // متحكم إدخال للنص
  final _transferCodeCtrl = TextEditingController(); // متحكم إدخال للنص
  final _notesCtrl = TextEditingController(); // متحكم إدخال للنص
  bool _allowRoutePop = false; // حالة تحكم داخلية

  File? _receiptFile;
  String? _receiptName;
  bool _pickingReceipt = false;
  bool _submitting = false;
  bool _attempted = false; // حالة تحكم داخلية

  late final AnimationController _shimmerCtl;

  @override
  void initState() {
    super.initState();
    _shimmerCtl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1, milliseconds: 800),
    )..repeat();
    _walletSummaryCubit = WalletSummaryCubit();
    _walletSummarySub = _walletSummaryCubit.stream.listen(_onWalletState);
    _walletUpdateSub =
        NotificationService.walletNotifications.listen(_handleWalletUpdate);

    _loadBanks();
    _loadWalletSummary();
  }

  @override
  void dispose() {
    _senderCtrl.dispose();
    _transferCodeCtrl.dispose();
    _notesCtrl.dispose();
    _shimmerCtl.dispose();
    _walletSummarySub?.cancel();
    _walletUpdateSub?.cancel();
    _walletSummaryCubit.close();
    _overlayMessageTimer?.cancel();
    _overlayMessageEntry?.remove();
    _overlayMessageEntry = null;

    super.dispose();
  }

  void _onWalletState(WalletSummaryState state) {
    if (!mounted) return;
    if (state is WalletSummaryLoading) {
      setState(() {
        _loadingWallet = true;
        if (state.previous != null) {
          _walletSummary = state.previous!.summary;
          _walletError = null;
        }
      });
      return;
    }
    if (state is WalletSummaryLoadSuccess) {
      setState(() {
        _loadingWallet = false;
        _walletSummary = state.summary;
        _walletError = null;
        if (_selectedMethod == _walletMethod && !_walletCanPay) {
          _selectedMethod = null;
        }
      });
      return;
    }
    if (state is WalletSummaryFailure) {
      setState(() {
        _loadingWallet = false;
        _walletError = state.error;
        if (_selectedMethod == _walletMethod) {
          _selectedMethod = null;
        }
      });
    }
  }

  void _handleWalletUpdate(String key) {
    if (!mounted) return;
    if (key.isEmpty) {
      _loadWalletSummary(forceReload: true);
      return;
    }
    if (_lastWalletEventKey == key) {
      return;
    }
    _lastWalletEventKey = key;
    _loadWalletSummary(forceReload: true);
  }

  Future<void> _loadWalletSummary({bool forceReload = false}) async {
    setState(() {
      _loadingWallet = true;
      if (forceReload) {
        _walletError = null;
      }
    });
    await _walletSummaryCubit.fetchSummary(forceReload: forceReload);
  }

  String _resolvedPurpose() {
    final explicit = widget.args.purpose?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      final normalized = explicit.toLowerCase();
      if (normalized.contains('wallet')) {
        return _walletTopUpPurpose;
      }

      if (normalized.contains('order')) {
        return 'order';
      }

      if (normalized.contains('wifi')) {
        return 'wifi_plan';
      }

      if (normalized == 'general') {
        return 'general';
      }
      if (normalized.contains('service')) {
        return 'service';
      }
      if (normalized.contains('package')) {
        return 'package';
      }
      return normalized;
    }

    final packageType = widget.args.packageType.trim().toLowerCase();
    if (packageType.contains('wifi') || widget.args.wifiPlanId != null) {
      return 'wifi_plan';
    }
    if (packageType.contains('service') || widget.args.serviceId != null) {
      return 'service';
    }

    if (packageType.contains('wallet')) {
      return _walletTopUpPurpose;
    }
    if (packageType.contains('order')) {
      return 'order';
    }

    if (packageType.isEmpty) {
      return 'general';
    }
    return 'package';
  }

  bool _isWalletTopUpPurpose(String? purpose) {
    final normalized = purpose?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      return false;
    }
    if (normalized == _walletTopUpPurpose || normalized == 'wallet') {
      return true;
    }
    if (normalized.contains('wallet_top_up')) {
      return true;
    }
    if (normalized.contains('wallet')) {
      return true;
    }
    return false;
  }

  Future<void> _loadBanks() async {
    setState(() => _loadingBanks = true);
    try {
      final purpose = _resolvedPurpose();
      final bool isWalletTopUp =
          purpose == _walletTopUpPurpose || purpose == 'wallet';

      final bool normalizedWalletTopUp =
          _isWalletTopUpPurpose(widget.args.normalizedPurpose);

      final String? purposeParam;
      if (purpose == 'order' || purpose == 'package') {
        purposeParam = purpose;
      } else if (purpose == 'wifi_plan' || widget.args.wifiPlanId != null) {
        purposeParam = 'wifi_plan';
      } else if (isWalletTopUp) {
        purposeParam = _walletTopUpPurpose;
      } else if (purpose == 'service' || widget.args.serviceId != null) {
        purposeParam = 'service';
      } else {
        purposeParam = null;
      }

      final currency = widget.args.normalizedCurrency;

      final int? orderIdParam = (!isWalletTopUp && widget.args.packageId > 0)
          ? widget.args.packageId
          : null;

      final settings = await _service.fetchManualPaymentSettings(
        token: widget.args.token,
        purpose: purposeParam,
        currency: currency,
        orderId: orderIdParam,
        paymentMethod:
            ManualPaymentService.paymentMethodForApi(_manualBankMethod),
        amount: isWalletTopUp ? widget.args.amount : null,
        serviceId: widget.args.serviceId ?? widget.args.itemId,
        wifiPlanId: widget.args.wifiPlanId,
        serviceRequestId: widget.args.serviceRequestId,
      );

      final List<CurrencyParseResult> currencyCandidates =
          <CurrencyParseResult>[
        CurrencyUtils.parseCurrency(settings.paymentIntent),
        CurrencyUtils.parseCurrency(settings.paymentTransaction),
        CurrencyUtils.parseCurrency(settings.raw),
      ];
      CurrencyParseResult settingsCurrency = const CurrencyParseResult();
      for (final CurrencyParseResult candidate in currencyCandidates) {
        if (!candidate.hasData) {
          continue;
        }
        settingsCurrency = candidate.mergePreferNew(settingsCurrency);
      }
      final EastYemenBankConfig? eastConfigForUi =
          (settings.eastYemenBank != null && settings.eastYemenBank!.isEnabled)
              ? settings.eastYemenBank
              : null;
      final List<BankAccount> dedupedBanks = _dedupeBanks(settings.banks);
      final List<BankAccount> displayableBanks =
          _filterBanksForDisplay(dedupedBanks, eastConfigForUi);
      final List<String>? allowedGateways =
          widget.args.normalizedAllowedGateways;
      final bool manualAllowed = allowedGateways == null ||
          allowedGateways.contains(_manualBankMethod);
      final bool eastAllowed =
          allowedGateways == null || allowedGateways.contains(_eastYemenMethod);
      final bool walletAllowedByConfig =
          allowedGateways == null || allowedGateways.contains(_walletMethod);

      setState(() {
        _banks = manualAllowed ? displayableBanks : <BankAccount>[];
        _eastYemenBank = eastAllowed ? eastConfigForUi : null;
        _walletGatewayAllowed = walletAllowedByConfig;

        _manualGatewayAllowed = manualAllowed;
        _eastGatewayAllowed = eastAllowed;

        _paymentIntentId = settings.paymentIntentId?.trim();
        _paymentTransactionId = settings.paymentTransactionId?.trim();
        _subject = settings.subject;
        _next = settings.next;
        _settingsCurrencyInfo = settingsCurrency;

        final normalizedGateway = widget.args.normalizedGateway;
        final bool walletAvailable =
            _walletSummaryReady && walletAllowedByConfig;
        final bool walletPurpose = isWalletTopUp || normalizedWalletTopUp;
        final bool walletOptionAllowed =
            walletAvailable && !walletPurpose && walletAllowedByConfig;
        if (normalizedGateway == _eastYemenMethod && _eastYemenBank != null) {
          _selectedMethod = _eastYemenMethod;
          _selectedBankId = null;
        } else if (normalizedGateway == _walletMethod && walletOptionAllowed) {
          _selectedMethod = _walletMethod;
          _selectedBankId = null;
        } else if (normalizedGateway == _manualBankMethod &&
            _manualGatewayAllowed &&
            _banks.isNotEmpty) {
          _selectedMethod = _manualBankMethod;
          _selectedBankId = _banks.first.id;
        } else if (_eastYemenBank != null) {
          _selectedMethod = _eastYemenMethod;
          _selectedBankId = null;
        } else if (walletOptionAllowed) {
          _selectedMethod = _walletMethod;
          _selectedBankId = null;
        } else if (_manualGatewayAllowed && _banks.isNotEmpty) {
          _selectedMethod = _manualBankMethod;
          _selectedBankId = _banks.first.id;
        } else {
          _selectedMethod = null;
          _selectedBankId = null;
        }
        if (_selectedMethod == null &&
            normalizedGateway == _walletMethod &&
            walletOptionAllowed) {
          _selectedMethod = _walletMethod;
          _selectedBankId = null;
        }

        if (!walletOptionAllowed && _selectedMethod == _walletMethod) {
          if (_eastYemenBank != null) {
            _selectedMethod = _eastYemenMethod;
            _selectedBankId = null;
          } else if (_manualGatewayAllowed && _banks.isNotEmpty) {
            _selectedMethod = _manualBankMethod;
            _selectedBankId = _banks.first.id;
          } else {
            _selectedMethod = null;
            _selectedBankId = null;
          }
        }

        if (!_manualGatewayAllowed && _selectedMethod == _manualBankMethod) {
          if (_walletGatewayAllowed && walletOptionAllowed) {
            _selectedMethod = _walletMethod;
            _selectedBankId = null;
          } else if (_eastYemenBank != null) {
            _selectedMethod = _eastYemenMethod;
            _selectedBankId = null;
          } else {
            _selectedMethod = null;
            _selectedBankId = null;
          }
        }

        _pressedBankId = null;
        _attempted = false;
      });
    } finally {
      if (mounted) setState(() => _loadingBanks = false);
    }
  }

  List<BankAccount> _dedupeBanks(List<BankAccount> banks) {
    if (banks.isEmpty) {
      return banks;
    }

    String _normalize(
      String? value, {
      bool removeWhitespace = false,
      bool collapseWhitespace = false,
    }) {
      if (value == null) return '';
      final trimmed = value.trim();
      if (trimmed.isEmpty) return '';
      String normalized = trimmed;
      if (collapseWhitespace) {
        normalized = normalized.replaceAll(RegExp(r'\s+'), ' ');
      }
      if (removeWhitespace) {
        normalized = normalized.replaceAll(RegExp(r'\s+'), '');
      }
      return normalized.toLowerCase();
    }

    String _bankIdentity(BankAccount bank) {
      final iban = _normalize(bank.iban, removeWhitespace: true);

      final accountNumber =
          _normalize(bank.accountNumber, removeWhitespace: true);
      final swift = _normalize(bank.swift, removeWhitespace: true);

      final accountName = _normalize(
        bank.accountName,
        removeWhitespace: true,
        collapseWhitespace: true,
      );
      final bankName = _normalize(bank.bankName, collapseWhitespace: true);
      final components = <String>[
        if (iban.isNotEmpty) 'iban:$iban',
        if (accountNumber.isNotEmpty) 'acc:$accountNumber',
        if (swift.isNotEmpty) 'swift:$swift',
        if (accountName.isNotEmpty) 'beneficiary:$accountName',
        if (bankName.isNotEmpty) 'name:$bankName',
      ];

      if (components.isEmpty) {
        final notes = _normalize(bank.notes, collapseWhitespace: true);
        if (notes.isNotEmpty) {
          components.add('notes:${notes.hashCode}');
        }
      }

      if (components.isEmpty && bank.id > 0) {
        components.add('id:${bank.id}');
      }

      if (components.isEmpty) {
        components.add('bank:${identityHashCode(bank)}');
      }

      return components.join('|');
    }

    final seen = <String>{};
    final uniqueBanks = <BankAccount>[];
    for (final bank in banks) {
      if (!bank.isActive) {
        continue;
      }
      final key = _bankIdentity(bank);
      if (seen.add(key)) {
        uniqueBanks.add(bank);
      }
    }

    int orderValue(BankAccount bank) {
      final order = bank.displayOrder;
      if (order == null) {
        return 1 << 20;
      }
      return order;
    }

    int safeCompare(String a, String b) =>
        a.toLowerCase().compareTo(b.toLowerCase());

    uniqueBanks.sort((a, b) {
      final orderDiff = orderValue(a).compareTo(orderValue(b));
      if (orderDiff != 0) {
        return orderDiff;
      }
      final nameDiff = safeCompare(a.bankName, b.bankName);
      if (nameDiff != 0) {
        return nameDiff;
      }
      return a.id.compareTo(b.id);
    });

    return uniqueBanks;
  }

  List<BankAccount> _filterBanksForDisplay(
    List<BankAccount> banks,
    EastYemenBankConfig? eastConfig,
  ) {
    if (banks.isEmpty) {
      return banks;
    }

    final List<BankAccount> filtered = <BankAccount>[];
    final Set<String> seenDisplayKeys = <String>{};

    for (final BankAccount bank in banks) {
      if (!bank.isActive) {
        continue;
      }

      final String normalizedName =
          _normalizeForComparison(bank.bankName, collapseWhitespace: true);
      final String normalizedAccountName =
          _normalizeForComparison(bank.accountName, collapseWhitespace: true);
      final String normalizedAccountNumber =
          _normalizeForComparison(bank.accountNumber, removeWhitespace: true);
      final String normalizedIban =
          _normalizeForComparison(bank.iban, removeWhitespace: true);
      final String normalizedFallbackLabel = _normalizeForComparison(
        _resolveBankDisplayName(bank),
        collapseWhitespace: true,
      );
      final bool hasDisplayableInfo = normalizedName.isNotEmpty ||
          normalizedAccountName.isNotEmpty ||
          normalizedAccountNumber.isNotEmpty ||
          normalizedIban.isNotEmpty;
      if (!hasDisplayableInfo) {
        continue;
      }

      if (eastConfig != null && _isDuplicateOfEastYemen(bank, eastConfig)) {
        continue;
      }

      final String displayKey = <String>[
        normalizedName,
        normalizedAccountName,
        normalizedAccountNumber,
        normalizedIban,
        normalizedFallbackLabel,
      ].join('|');

      if (!seenDisplayKeys.add(displayKey)) {
        continue;
      }

      filtered.add(bank);
    }

    return filtered;
  }

  String _normalizeForComparison(
    String? value, {
    bool removeWhitespace = false,
    bool collapseWhitespace = false,
  }) {
    if (value == null) {
      return '';
    }
    String normalized = value.trim();
    if (normalized.isEmpty) {
      return '';
    }
    if (collapseWhitespace) {
      normalized = normalized.replaceAll(RegExp(r'\s+'), ' ');
    }
    if (removeWhitespace) {
      normalized = normalized.replaceAll(RegExp(r'\s+'), '');
    }
    return normalized.toLowerCase();
  }

  bool _isDuplicateOfEastYemen(
    BankAccount bank,
    EastYemenBankConfig eastConfig,
  ) {
    if (!eastConfig.isEnabled) {
      return false;
    }

    final String bankName =
        _normalizeForComparison(bank.bankName, collapseWhitespace: true);
    final String eastName = _normalizeForComparison(eastConfig.displayName,
        collapseWhitespace: true);

    final String bankAccountNumber =
        _normalizeForComparison(bank.accountNumber, removeWhitespace: true);
    final String eastAccountNumber = _normalizeForComparison(
      eastConfig.accountNumber,
      removeWhitespace: true,
    );

    final String bankIban =
        _normalizeForComparison(bank.iban, removeWhitespace: true);
    final String eastIban = _normalizeForComparison(
      eastConfig.iban,
      removeWhitespace: true,
    );

    final String bankAccountName =
        _normalizeForComparison(bank.accountName, collapseWhitespace: true);
    final String eastAccountName = _normalizeForComparison(
      eastConfig.accountName,
      collapseWhitespace: true,
    );

    if (bankName.isNotEmpty && eastName.isNotEmpty && bankName == eastName) {
      return true;
    }
    if (bankAccountNumber.isNotEmpty &&
        eastAccountNumber.isNotEmpty &&
        bankAccountNumber == eastAccountNumber) {
      return true;
    }
    if (bankIban.isNotEmpty && eastIban.isNotEmpty && bankIban == eastIban) {
      return true;
    }
    if (bankAccountName.isNotEmpty &&
        eastAccountName.isNotEmpty &&
        bankAccountName == eastAccountName) {
      return true;
    }

    return false;
  }

  String _resolveBankDisplayName(BankAccount bank) {
    final String name = bank.bankName.trim();
    if (name.isNotEmpty) {
      return name;
    }
    final String? accountName = bank.accountName?.trim();
    if (accountName != null && accountName.isNotEmpty) {
      return accountName;
    }
    final String? accountNumber = bank.accountNumber?.trim();
    if (accountNumber != null && accountNumber.isNotEmpty) {
      return 'رقم الحساب: $accountNumber';
    }
    final String? iban = bank.iban?.trim();
    if (iban != null && iban.isNotEmpty) {
      return 'IBAN $iban';
    }
    return 'تفاصيل البنك غير متاحة.';
  }

  String _resolveGatewayForIntent(bool walletPurpose) {
    final String? current = _selectedMethod;
    final bool walletDisallowed = walletPurpose && current == _walletMethod;
    if (current != null && !walletDisallowed) {
      return current;
    }

    return _preferredGatewayForIntent(walletPurpose);
  }

  String _preferredGatewayForIntent(bool walletPurpose) {
    if (_eastGatewayAllowed && _eastYemenBank != null) {
      return _eastYemenMethod;
    }
    if (_walletGatewayAllowed && !walletPurpose) {
      return _walletMethod;
    }
    if (_manualGatewayAllowed && _banks.isNotEmpty) {
      return _manualBankMethod;
    }
    if (_eastGatewayAllowed) {
      return _eastYemenMethod;
    }
    if (_walletGatewayAllowed && !walletPurpose) {
      return _walletMethod;
    }
    if (_manualGatewayAllowed) {
      return _manualBankMethod;
    }
    return _walletMethod;
  }

  Future<bool> _ensurePaymentIntent() async {
    final currentIntent = _paymentIntentId?.trim();
    if (currentIntent != null && currentIntent.isNotEmpty) {
      if (currentIntent != _paymentIntentId) {
        if (mounted) {
          setState(() => _paymentIntentId = currentIntent);
        } else {
          _paymentIntentId = currentIntent;
        }
      }
      return true;
    }

    final purpose = _resolvedPurpose();
    final bool isWalletTopUp =
        purpose == _walletTopUpPurpose || purpose == 'wallet';

    final bool normalizedWalletTopUp =
        _isWalletTopUpPurpose(widget.args.normalizedPurpose);
    final bool walletPurpose = isWalletTopUp || normalizedWalletTopUp;

    final String? purposeParam;
    if (purpose == 'order' || purpose == 'package') {
      purposeParam = purpose;
    } else if (purpose == 'wifi_plan' || widget.args.wifiPlanId != null) {
      purposeParam = 'wifi_plan';
    } else if (isWalletTopUp) {
      purposeParam = _walletTopUpPurpose;
    } else if (purpose == 'service' || widget.args.serviceId != null) {
      purposeParam = 'service';
    } else {
      purposeParam = null;
    }

    final currency = widget.args.normalizedCurrency;

    if (walletPurpose && _selectedMethod == _walletMethod) {
      void assignFallback() {
        if (_eastGatewayAllowed && _eastYemenBank != null) {
          _selectedMethod = _eastYemenMethod;
          _selectedBankId = null;
        } else if (_manualGatewayAllowed && _banks.isNotEmpty) {
          _selectedMethod = _manualBankMethod;
          _selectedBankId ??= _banks.first.id;
        } else if (_eastGatewayAllowed) {
          _selectedMethod = _eastYemenMethod;
          _selectedBankId = null;
        } else {
          _selectedMethod = null;
          _selectedBankId = null;
        }
      }

      if (mounted) {
        setState(assignFallback);
      } else {
        assignFallback();
      }
    }

    final selectedMethod = _resolveGatewayForIntent(walletPurpose);

    final bool isOrderPurpose = purposeParam == 'order';

    final int? orderIdParam = (isOrderPurpose && widget.args.packageId > 0)
        ? widget.args.packageId
        : null;

    try {
      final settings = await _service.fetchManualPaymentSettings(
        token: widget.args.token,
        purpose: purposeParam,
        currency: currency,
        orderId: orderIdParam,
        paymentMethod: ManualPaymentService.paymentMethodForApi(selectedMethod),
        amount: isWalletTopUp ? widget.args.amount : null,
        serviceId: widget.args.serviceId ?? widget.args.itemId,
        wifiPlanId: widget.args.wifiPlanId,
        serviceRequestId: widget.args.serviceRequestId,
      );

      final updatedIntent = settings.paymentIntentId?.trim();
      final updatedTransaction = settings.paymentTransactionId?.trim();

      void assignUpdates() {
        if (updatedIntent != null && updatedIntent.isNotEmpty) {
          _paymentIntentId = updatedIntent;
        }
        if (updatedTransaction != null && updatedTransaction.isNotEmpty) {
          _paymentTransactionId = updatedTransaction;
        }
        if (_manualGatewayAllowed &&
            _banks.isEmpty &&
            settings.banks.isNotEmpty) {
          final List<BankAccount> deduped = _dedupeBanks(settings.banks);
          final EastYemenBankConfig? eastForFilter = _eastGatewayAllowed
              ? (_eastYemenBank ?? settings.eastYemenBank)
              : null;
          _banks = _filterBanksForDisplay(deduped, eastForFilter);
        }
        if (_eastGatewayAllowed &&
            settings.eastYemenBank != null &&
            settings.eastYemenBank!.isEnabled) {
          _eastYemenBank = settings.eastYemenBank;
        }
      }

      if (mounted) {
        setState(assignUpdates);
      } else {
        assignUpdates();
      }

      return updatedIntent != null && updatedIntent.isNotEmpty;
    } on ApiHttpException catch (err) {
      if (mounted) {
        final String message = _resolveApiErrorMessage(err);
        _showOverlayMessage(message, type: MessageType.error);
      }
      return false;
    } catch (err) {
      if (mounted) {
        _showOverlayMessage(err.toString(), type: MessageType.error);
      }
      return false;
    }
  }

  String? get _paymentCurrencyCode {
    final List<String?> candidates = <String?>[
      widget.args.normalizedCurrency,
      CurrencyUtils.normalizeCurrencyCode(widget.args.currency),
      _settingsCurrencyInfo.code,
      CurrencyUtils.normalizeCurrencyCode(_settingsCurrencyInfo.display),
      CurrencyUtils.normalizeCurrencyCode(_walletSummary?.currencyCode),
      CurrencyUtils.normalizeCurrencyCode(_walletSummary?.currency),
    ];
    for (final String? candidate in candidates) {
      if (candidate != null && candidate.isNotEmpty) {
        return candidate;
      }
    }
    return null;
  }

  String? get _paymentCurrencyLabel {
    final List<String?> candidates = <String?>[
      widget.args.currency,
      _settingsCurrencyInfo.display,
      _settingsCurrencyInfo.code,
      _walletSummary?.currency,
      _walletSummary?.currencyCode,
      _paymentCurrencyCode,
    ];
    for (final String? candidate in candidates) {
      final String? trimmed = candidate?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return null;
  }

  String? _currencyDisplayToken(String? value,
      {String? code, String? fallback}) {
    final String? trimmed = value?.trim();
    final String? normalized =
        CurrencyUtils.normalizeCurrencyCode(code ?? trimmed);

    return CurrencyUtils.displayToken(
          label: (trimmed == null || trimmed.isEmpty) ? null : trimmed,
          fallback: fallback ?? normalized ?? trimmed,
          code: normalized,
        ) ??
        fallback ??
        normalized ??
        trimmed;
  }

  String? get _walletCurrencyCode => CurrencyUtils.normalizeCurrencyCode(
        _walletSummary?.currencyCode ?? _walletSummary?.currency,
      );

  String? get _walletCurrencyLabel => _currencyDisplayToken(
        _walletSummary?.currency,
        code: _walletSummary?.currencyCode ?? _walletCurrencyCode,
        fallback: _walletCurrencyCode,
      );

  String? get _paymentCurrencyDisplay => _currencyDisplayToken(
        _paymentCurrencyLabel ?? _paymentCurrencyCode,
        code: _paymentCurrencyCode,
        fallback: _paymentCurrencyCode,
      );

  bool get _walletCurrencyMatchesPayment {
    final String? walletCurrency = _walletCurrencyCode;
    final String? paymentCurrency =
        CurrencyUtils.normalizeCurrencyCode(_paymentCurrencyCode);
    if (walletCurrency == null || paymentCurrency == null) {
      return true;
    }

    return walletCurrency == paymentCurrency;
  }

  Future<void> _pickReceipt() async {
    setState(() => _pickingReceipt = true);
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowMultiple: false,
        allowedExtensions: _allowedReceiptExtensions,
        withData: false,
      );
      if (res == null || res.files.isEmpty) return;

      final f = res.files.first;
      final path = f.path;
      if (path == null) return;

      final file = File(path);
      final bytes = await file.length();
      if (bytes > 5 * 1024 * 1024) {
        if (!mounted) return;
        UiUtils.showSoftSnackBar(
          context,
          message: 'حجم الملف يتجاوز 5 ميغابايت، يرجى اختيار ملف أصغر.',
        );
      }

      setState(() {
        _receiptFile = file;
        _receiptName = f.name;
      });
    } finally {
      if (mounted) setState(() => _pickingReceipt = false);
    }
  }

  bool get _senderOk => _senderCtrl.text.trim().isNotEmpty;

  bool get _receiptOk => _receiptFile != null;

  bool get _usingEastYemen => _selectedMethod == _eastYemenMethod;

  bool get _usingManualBank => _selectedMethod == _manualBankMethod;

  bool get _usingWallet => _selectedMethod == _walletMethod;

  bool get _walletSummaryReady =>
      _walletSummary != null && _walletError == null;

  bool get _walletHasEnoughBalance {
    final summary = _walletSummary;
    if (summary == null) {
      return false;
    }
    const double epsilon = 0.0001;
    return summary.balance + epsilon >= widget.args.amount;
  }

  bool get _walletCanPay =>
      _walletSummaryReady &&
      _walletCurrencyMatchesPayment &&
      _walletHasEnoughBalance;

  bool get _shouldShowSenderField => _usingManualBank;

  bool get _shouldShowTransferCodeField => _usingManualBank;

  bool get _transferCodeOk =>
      !_shouldShowTransferCodeField || _transferCodeCtrl.text.trim().isNotEmpty;

  bool get _readyToSubmit {
    if (_submitting) return false;
    if (_usingEastYemen) {
      return true;
    }
    if (_usingManualBank) {
      if (!_manualGatewayAllowed) return false;
      if (!_senderOk) return false;
      if (!_transferCodeOk) return false;

      return _selectedBankId != null && _receiptOk;
    }

    if (_usingWallet) {
      return _walletCanPay;
    }

    return false;
  }

  Future<void> _submit({String? eastYemenCode}) async {
    if (_usingManualBank) {
      setState(() => _attempted = true);
    } else {
      setState(() => _attempted = false);
    }
    if (_selectedMethod == null) {
      if (mounted) {
        UiUtils.showSoftSnackBar(
          context,
          message: 'الرجاء اختيار طريقة الدفع أولًا.',
        );
      }
      return;
    }

    if (_usingManualBank && !_receiptOk && mounted) {
      UiUtils.showSoftSnackBar(
        context,
        message: 'يرجى اختيار البنك وإرفاق إيصال التحويل قبل المتابعة.',
      );
      return;
    }

    final bool walletPurpose =
        _isWalletTopUpPurpose(widget.args.normalizedPurpose) ||
            _isWalletTopUpPurpose(_resolvedPurpose());

    if (_usingWallet && walletPurpose) {
      _showOverlayMessage(
        'لا يمكن الدفع من المحفظة لغرض شحن المحفظة. يرجى اختيار بوابة دفع أخرى.',
        type: MessageType.warning,
      );
      return;
    }
    if (_usingWallet) {
      if (!_walletSummaryReady) {
        _showOverlayMessage(
          'لا يمكن إتمام العملية قبل تحميل بيانات المحفظة. حاول مرة أخرى بعد لحظات.',
          type: MessageType.error,
        );
        return;
      }
      if (!_walletCurrencyMatchesPayment) {
        final String walletLabel = _walletCurrencyLabel ??
            _walletCurrencyCode ??
            'حدث خطأ غير متوقع. يرجى المحاولة لاحقًا.';
        final String paymentLabel = _paymentCurrencyDisplay ??
            _paymentCurrencyLabel ??
            _paymentCurrencyCode ??
            'حدث خطأ غير متوقع. يرجى المحاولة لاحقًا.';
        _showOverlayMessage(
          'عملة المحفظة ($walletLabel) تختلف عن عملة الدفع ($paymentLabel).',
          type: MessageType.error,
        );
        return;
      }
      if (!_walletHasEnoughBalance) {
        final String currency = _paymentCurrencyLabel ?? '';
        final amountText = widget.args.amount.toStringAsFixed(2);
        final String suffix = currency.isNotEmpty ? ' $currency' : '';
        _showOverlayMessage(
          'الرصيد غير كافٍ لدفع $amountText$suffix.',
          type: MessageType.error,
        );
        return;
      }
    }

    if (_usingManualBank && !_manualGatewayAllowed) {
      _showOverlayMessage(
        'تم تعطيل طرق التحويل اليدوية لهذا الطلب.',
        type: MessageType.error,
      );
      return;
    }

    if (!_readyToSubmit) return;
    final ensured = await _ensurePaymentIntent();
    final resolvedIntentId = _paymentIntentId?.trim();
    if (!ensured || resolvedIntentId == null || resolvedIntentId.isEmpty) {
      _showOverlayMessage(
        'حدث خطأ غير متوقع. يرجى المحاولة لاحقًا.',
        type: MessageType.error,
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final normalizedPurpose = widget.args.normalizedPurpose.toLowerCase();
      final bool isWalletTopUp = normalizedPurpose == _walletTopUpPurpose ||
          normalizedPurpose.contains('wallet');

      String? payableType;
      int? payableId;

      final int? serviceRequestIdArg = widget.args.serviceRequestId;
      final int? serviceIdArg = widget.args.serviceId ?? widget.args.itemId;

      final int? wifiPlanIdArg = widget.args.wifiPlanId;

      if (serviceRequestIdArg != null) {
        payableType = 'App\\Models\\ServiceRequest';
        payableId = serviceRequestIdArg;
      } else {
        switch (normalizedPurpose) {
          case 'order':
            payableType = 'order';
            payableId = widget.args.packageId;
            break;
          case 'package':
            payableType = 'package';
            payableId = widget.args.packageId;
            break;
          case 'wifi_plan':
            payableType = 'App\\Models\\Wifi\\WifiPlan';
            payableId = wifiPlanIdArg ?? widget.args.packageId;
            break;
          case _walletTopUpPurpose:
            payableType = ManualPaymentService.walletTopUpPurpose;
            payableId = null;
            break;
          case 'service':
            payableType = 'service';
            payableId = widget.args.serviceId ?? widget.args.itemId;
            break;

          default:
            if (isWalletTopUp) {
              payableType = ManualPaymentService.walletTopUpPurpose;
              payableId = null;
            } else if (wifiPlanIdArg != null) {
              payableType = 'App\\Models\\Wifi\\WifiPlan';
              payableId = wifiPlanIdArg;
            } else {
              payableType = 'package';
              payableId = widget.args.packageId;
            }
        }
      }

      final int? resolvedPackageId =
          widget.args.packageId > 0 ? widget.args.packageId : null;
      final int? resolvedServiceId =
          widget.args.serviceId ?? widget.args.itemId;

      String? purposeForApi;
      int? orderIdForApi;
      int? packageIdForApi;
      int? serviceIdForApi;
      int? wifiPlanIdForApi;
      if (normalizedPurpose == 'order') {
        purposeForApi = 'order';
        orderIdForApi = resolvedPackageId;
      } else if (normalizedPurpose == 'package') {
        purposeForApi = 'package';
        packageIdForApi = resolvedPackageId;
      } else if (normalizedPurpose == 'wifi_plan' || wifiPlanIdArg != null) {
        purposeForApi = 'wifi_plan';
        wifiPlanIdForApi = wifiPlanIdArg ?? resolvedPackageId;
      } else if (isWalletTopUp) {
        purposeForApi = ManualPaymentService.walletTopUpPurpose;
      } else if (normalizedPurpose == 'service') {
        purposeForApi = 'service';
        serviceIdForApi = resolvedServiceId;
      } else if (resolvedPackageId != null) {
        purposeForApi = 'package';
        packageIdForApi = resolvedPackageId;
      }

      final notesText = _notesCtrl.text.trim();
      final senderName = _shouldShowSenderField ? _senderCtrl.text.trim() : '';
      final transferCode =
          _shouldShowTransferCodeField ? _transferCodeCtrl.text.trim() : '';
      final String? submissionCurrencyCandidate = _paymentCurrencyCode;
      if ((submissionCurrencyCandidate ?? '').isEmpty) {
        _showOverlayMessage(
          'حدث خطأ غير متوقع. يرجى المحاولة لاحقًا.',
          type: MessageType.error,
        );
        return;
      }
      final String submissionCurrency = submissionCurrencyCandidate!;

      final userNote = notesText;

      final contextMetadata = widget.args.toContext()
        ..removeWhere((k, v) => v == null);

      final Map<String, dynamic> metadata = <String, dynamic>{
        'device': _deviceLabel(),
        'source': _sourceLabel(),
      };

      if (payableType case final String type) {
        metadata['payable_type'] = type;
      }
      if (payableId case final int id) {
        metadata['payable_id'] = id;
      }
      if (serviceRequestIdArg != null) {
        metadata['service_request_id'] = serviceRequestIdArg;
      }
      if (serviceIdArg != null) {
        metadata['service_id'] = serviceIdArg;
      }
      if (wifiPlanIdArg != null) {
        metadata['wifi_plan_id'] = wifiPlanIdArg;
      }

      if (senderName.isNotEmpty) metadata['sender_name'] = senderName;
      if (_usingManualBank && transferCode.isNotEmpty) {
        metadata.addAll({
          'transfer_code': transferCode,
          'transfer_reference': transferCode,
          'transfer_number': transferCode,
        });
      }
      if (contextMetadata.isNotEmpty) {
        metadata['context'] = contextMetadata;
      }

      metadata.removeWhere((k, v) {
        if (v == null) return true;
        if (v is String) return v.trim().isEmpty;
        if (v is Map) return v.isEmpty;
        return false;
      });

      final intentId = resolvedIntentId;
      final transactionId = _paymentTransactionId?.trim();

      final ManualPaymentSubmissionResult result;
      if (_usingEastYemen) {
        final trimmedCode = eastYemenCode?.trim();
        result = await _service.submitEastYemenPayment(
          token: widget.args.token,
          intentId: intentId,
          transactionId: transactionId,
          payableType: payableType,
          payableId: payableId,
          purpose: purposeForApi,
          orderId: orderIdForApi,
          packageId: packageIdForApi,
          serviceId: serviceIdForApi,
          wifiPlanId: wifiPlanIdForApi,
          serviceRequestId: widget.args.serviceRequestId,
          amount: widget.args.amount,
          currency: submissionCurrency,
          reference: (trimmedCode != null && trimmedCode.isNotEmpty)
              ? trimmedCode
              : null,
          userNote: userNote.isEmpty ? null : userNote,
          metadata: metadata.isEmpty ? null : metadata,
        );
      } else if (_usingWallet) {
        result = await _service.submitWalletPayment(
          token: widget.args.token,
          intentId: intentId,
          transactionId: transactionId,
          payableType: payableType,
          payableId: payableId,
          purpose: purposeForApi,
          orderId: orderIdForApi,
          packageId: packageIdForApi,
          serviceId: serviceIdForApi,
          serviceRequestId: widget.args.serviceRequestId,
          wifiPlanId: wifiPlanIdForApi,
          amount: widget.args.amount,
          currency: submissionCurrency,
          userNote: userNote.isEmpty ? null : userNote,
          metadata: metadata.isEmpty ? null : metadata,
        );
      } else {
        result = await _service.submitManualPayment(
          token: widget.args.token,
          bankId: _selectedBankId!,
          intentId: intentId,
          transactionId: transactionId,
          payableType: payableType,
          payableId: payableId,
          purpose: purposeForApi,
          orderId: orderIdForApi,
          packageId: packageIdForApi,
          serviceId: serviceIdForApi,
          wifiPlanId: wifiPlanIdForApi,
          serviceRequestId: widget.args.serviceRequestId,
          amount: widget.args.amount,
          currency: submissionCurrency,
          reference: transferCode.isNotEmpty ? transferCode : null,
          userNote: userNote.isEmpty ? null : userNote,
          transferredAt: DateTime.now().toUtc(),
          metadata: metadata.isEmpty ? null : metadata,
          receiptImagePath: _receiptFile!.path,
        );
      }

      final updatedIntentId = (result.paymentIntentId != null &&
              result.paymentIntentId!.trim().isNotEmpty)
          ? result.paymentIntentId!.trim()
          : null;
      final updatedTransactionId = (result.paymentTransactionId != null &&
              result.paymentTransactionId!.trim().isNotEmpty)
          ? result.paymentTransactionId!.trim()
          : null;

      if (updatedIntentId != null || updatedTransactionId != null) {
        if (mounted) {
          setState(() {
            if (updatedIntentId != null) {
              _paymentIntentId = updatedIntentId;
            }
            if (updatedTransactionId != null) {
              _paymentTransactionId = updatedTransactionId;
            }
          });
        } else {
          if (updatedIntentId != null) {
            _paymentIntentId = updatedIntentId;
          }
          if (updatedTransactionId != null) {
            _paymentTransactionId = updatedTransactionId;
          }
        }
      }

      if (!mounted) return;

      final bool ok = _resultIndicatesSuccess(result);

      final String successMessage = (() {
        final t = (result.message ?? '').trim();
        if (t.isNotEmpty && !_looksLikeErrorMessage(t)) return t;
        if (_usingEastYemen) {
          return 'تم تأكيد تحويل بنك الشرق بنجاح.';
        }
        if (_usingWallet) {
          return 'تم الدفع من المحفظة بنجاح.';
        }
        return 'تم إنشاء طلب التحويل البنكي بنجاح.';
      })();

      final String errorMessage = (() {
        final t = (result.message ?? '').trim();
        if (t.isNotEmpty) return t;
        return _usingEastYemen
            ? 'حدث خطأ غير متوقع. يرجى المحاولة لاحقًا.'
            : _usingWallet
                ? 'حدث خطأ غير متوقع. يرجى المحاولة لاحقًا.'
                : 'حدث خطأ غير متوقع. يرجى المحاولة لاحقًا.';
      })();

      final String? displayReference = (() {
        final candidates = [
          result.paymentTransactionId,
          result.manualPaymentId,
          result.paymentIntentId,
        ];
        for (final candidate in candidates) {
          final value = candidate?.trim();
          if (value != null && value.isNotEmpty) {
            return value;
          }
        }
        return null;
      })();

      final String successMessageWithReference = displayReference != null
          ? '$successMessage\nمرجع العملية: $displayReference'
          : successMessage;

      _showOverlayMessage(ok ? successMessageWithReference : errorMessage,
          type: ok ? MessageType.success : MessageType.error);

      if (ok) {
        if (_usingWallet) {
          _loadWalletSummary(forceReload: true);
        }

        Future.microtask(() {
          if (!mounted) return;
          final enriched = result.copyWith(
            subject: result.subject ?? _subject,
            next: result.next ?? _next,
          );
          final PaymentRouteResult? routeResult =
              _buildPaymentRouteResult(enriched);
          if (routeResult != null) {
            _closeWithResult(routeResult);
          } else {
            _closeWithResult(enriched);
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      _showOverlayMessage('حدث خطأ غير متوقع: $e', type: MessageType.error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  PaymentRouteResult? _buildPaymentRouteResult(
      ManualPaymentSubmissionResult result) {
    final int? transactionId = _extractPaymentTransactionId(result);
    final Map<String, dynamic>? deliveryPayload =
        _extractDeliveryPayload(result);

    if (_usingWallet) {
      if (transactionId != null) {
        return PaymentRouteResult.wallet(
          transactionId,
          delivery: deliveryPayload,
        );
      }
      return null;
    }

    final int? manualRequestId = _extractManualPaymentRequestId(result);
    if (manualRequestId != null) {
      return PaymentRouteResult.bank(manualRequestId);
    }

    if (transactionId != null) {
      return PaymentRouteResult.wallet(
        transactionId,
        delivery: deliveryPayload,
      );
    }

    return null;
  }

  Map<String, dynamic>? _extractDeliveryPayload(
      ManualPaymentSubmissionResult result) {
    Map<String, dynamic>? copyIfNotEmpty(Map<String, dynamic>? source) {
      if (source == null || source.isEmpty) {
        return null;
      }
      return Map<String, dynamic>.from(source);
    }

    final Map<String, dynamic>? direct = copyIfNotEmpty(result.delivery);
    if (direct != null) {
      return direct;
    }

    final dynamic rawDelivery = result.raw['delivery'];
    if (rawDelivery is Map<String, dynamic>) {
      return copyIfNotEmpty(rawDelivery);
    }
    if (rawDelivery is Map) {
      return copyIfNotEmpty(Map<String, dynamic>.from(rawDelivery));
    }

    return null;
  }

  int? _extractManualPaymentRequestId(ManualPaymentSubmissionResult result) {
    final int? direct = result.manualPaymentIdAsInt;
    if (direct != null) {
      return direct;
    }

    int? parseFrom(Map<String, dynamic>? source) {
      if (source == null || source.isEmpty) {
        return null;
      }
      for (final key in const [
        'manual_payment_request_id',
        'manualPaymentRequestId',
        'manual_payment_id',
        'manualPaymentId',
        'id',
      ]) {
        if (!source.containsKey(key)) continue;
        final parsed = _parseInt(source[key]);
        if (parsed != null) {
          return parsed;
        }
      }
      return null;
    }

    final Map<String, dynamic>? manualRequest = result.manualPaymentRequest;
    final int? fromManual = parseFrom(manualRequest);
    if (fromManual != null) {
      return fromManual;
    }

    final Map<String, dynamic>? subject = result.subject;
    final int? fromSubject = parseFrom(subject);
    if (fromSubject != null) {
      return fromSubject;
    }

    return parseFrom(result.raw);
  }

  int? _extractPaymentTransactionId(ManualPaymentSubmissionResult result) {
    final int? direct = result.paymentTransactionIdAsInt;
    if (direct != null) {
      return direct;
    }

    int? parseFrom(Map<String, dynamic>? source) {
      if (source == null || source.isEmpty) {
        return null;
      }
      for (final key in const [
        'payment_transaction_id',
        'paymentTransactionId',
        'transaction_id',
        'transactionId',
        'id',
      ]) {
        if (!source.containsKey(key)) continue;
        final parsed = _parseInt(source[key]);
        if (parsed != null) {
          return parsed;
        }
      }
      return null;
    }

    final Map<String, dynamic>? transaction = result.paymentTransaction;
    final int? fromTransaction = parseFrom(transaction);
    if (fromTransaction != null) {
      return fromTransaction;
    }

    final Map<String, dynamic>? manualRequest = result.manualPaymentRequest;
    final int? fromManual = parseFrom(manualRequest);
    if (fromManual != null) {
      return fromManual;
    }

    final Map<String, dynamic>? next = result.next;
    final int? fromNext = parseFrom(next);
    if (fromNext != null) {
      return fromNext;
    }

    return parseFrom(result.raw);
  }

  int? _parseInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    final String normalized =
        value is String ? value.trim() : value.toString().trim();
    if (normalized.isEmpty) {
      return null;
    }
    return int.tryParse(normalized);
  }

  Future<void> _handleConfirmPressed() async {
    if (_submitting) return;
    if (_usingEastYemen) {
      final code = await _promptEastYemenCode();
      if (code == null || code.isEmpty) {
        return;
      }
      await _submit(eastYemenCode: code);
    } else {
      await _submit();
    }
  }

  Future<String?> _promptEastYemenCode() async {
    final result = await showPurchaseCodeDialog(
      context,
      onShowGuide: () => _showEastYemenGuide(context),
    );

    final trimmed = result?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  Future<void> _showEastYemenGuide(BuildContext parentContext) async {
    await showModalBottomSheet<void>(
      context: parentContext,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final onSurface = theme.colorScheme.onSurface;
        final padding = MediaQuery.of(sheetContext).viewInsets.bottom + 24;

        return SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final content = Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'حدث خطأ غير متوقع. يرجى المحاولة لاحقًا.',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: onSurface,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'حدث خطأ غير متوقع. يرجى المحاولة لاحقًا.',
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: Icon(
                          Icons.close_rounded,
                          color: onSurface.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'حدث خطأ غير متوقع. يرجى المحاولة لاحقًا.',
                    style: TextStyle(
                      height: 1.5,
                      color: onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...[
                    'حدث خطأ غير متوقع. يرجى المحاولة لاحقًا.',
                    'حدث خطأ غير متوقع. يرجى المحاولة لاحقًا.',
                    'حدث خطأ غير متوقع. يرجى المحاولة لاحقًا.',
                    'حدث خطأ غير متوقع. يرجى المحاولة لاحقًا.',
                    'حدث خطأ غير متوقع. يرجى المحاولة لاحقًا.',
                    'حدث خطأ غير متوقع. يرجى المحاولة لاحقًا.',
                  ].map(
                    (step) => Padding(
                      padding: const EdgeInsetsDirectional.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('???????€??¬???? '),
                          Expanded(
                            child: Text(
                              step,
                              style: TextStyle(
                                height: 1.5,
                                color: onSurface.withValues(alpha: 0.9),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'حدث خطأ غير متوقع. يرجى المحاولة لاحقًا.',
                    style: TextStyle(
                      height: 1.5,
                      color: onSurface.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: const Text(
                          'حدث خطأ غير متوقع. يرجى المحاولة لاحقًا.'),
                    ),
                  ),
                ],
              );

              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 16, 20, padding),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: content,
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _resolveApiErrorMessage(ApiHttpException err) {
    final dynamic payload = err.payload;

    if (payload is Map) {
      final dynamic messageNode = payload['message'];
      if (messageNode is String && messageNode.trim().isNotEmpty) {
        return messageNode.trim();
      }

      final dynamic errorsNode = payload['errors'];
      if (errorsNode is Map) {
        for (final value in errorsNode.values) {
          if (value is List && value.isNotEmpty) {
            final dynamic firstValue = value.first;
            if (firstValue is String && firstValue.trim().isNotEmpty) {
              return firstValue.trim();
            }
          } else if (value is String && value.trim().isNotEmpty) {
            return value.trim();
          }
        }
      }
    }

    final dynamic errorMessage = err.errorMessage;
    if (errorMessage is String && errorMessage.trim().isNotEmpty) {
      return errorMessage.trim();
    }

    return err.toString();
  }

  bool _looksLikeErrorMessage(String text) {
    final normalized = text.trim().toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }
    const probes = <String>[
      'خطأ',
      'غير متوقع',
      'فشل',
      'لم يتم',
      'تعذر',
      'error',
      'fail',
      'unable',
      'unexpected',
    ];
    for (final probe in probes) {
      if (normalized.contains(probe)) {
        return true;
      }
    }
    return false;
  }

  bool _resultIndicatesSuccess(ManualPaymentSubmissionResult result) {
    if (result.success == true) {
      return true;
    }
    final String? status = result.status?.trim().toLowerCase();
    if (status != null &&
        status.isNotEmpty &&
        const {
          'succeed',
          'succeeded',
          'success',
          'approved',
          'completed',
          'done',
        }.contains(status)) {
      return true;
    }
    if (result.paymentTransactionIdAsInt != null) {
      return true;
    }
    final dynamic deliveryNode = result.delivery ?? result.raw['delivery'];
    if (deliveryNode is Map && deliveryNode.isNotEmpty) {
      return true;
    }
    return false;
  }

  void _showOverlayMessage(String message,
      {MessageType type = MessageType.success}) {
    _overlayMessageTimer?.cancel();
    _overlayMessageEntry?.remove();

    final buildContext = Constant.navigatorKey.currentContext ?? context;
    final overlay = Overlay.maybeOf(buildContext, rootOverlay: true);

    if (overlay == null) {
      UiUtils.showSoftSnackBar(
        buildContext,
        message: message,
        backgroundColor: type == MessageType.error
            ? Colors.red
            : Colors.black.withOpacity(.85),
        duration: Duration(seconds: type == MessageType.error ? 4 : 3),
      );
      return;
    }

    final theme = Theme.of(buildContext);
    final Color background = type == MessageType.error
        ? theme.colorScheme.error
        : theme.colorScheme.secondaryContainer;
    final Color foreground = type == MessageType.error
        ? theme.colorScheme.onError
        : theme.colorScheme.onSecondaryContainer;

    final entry = OverlayEntry(
      builder: (BuildContext context) {
        final media = MediaQuery.of(context);
        return Positioned(
          top: media.padding.top + 16,
          left: 16,
          right: 16,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(16),
            color: background,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(color: foreground),
                textAlign: TextAlign.start,
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(entry);
    _overlayMessageEntry = entry;
    _overlayMessageTimer = Timer(
      Duration(seconds: type == MessageType.error ? 5 : 3),
      () {
        if (_overlayMessageEntry == entry) {
          entry.remove();
          _overlayMessageEntry = null;
        }
      },
    );
  }

  Future<void> _copyValueToClipboard(String value,
      {required String label}) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;

    final overlayContext = Constant.navigatorKey.currentContext ?? context;

    UiUtils.showSoftSnackBar(
      overlayContext,
      message: 'القيمة المحددة: $label',
      duration: const Duration(seconds: 2),
    );
  }

  String _deviceLabel() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    if (Platform.isFuchsia) return 'fuchsia';
    return Platform.operatingSystem;
  }

  String _sourceLabel() => _deviceLabel();

  void _closeWithResult([Object? result]) {
    _allowRoutePop = true;
    if (mounted) {
      Navigator.of(context).pop(result);
    }
  }

  Future<bool> _showCloseConfirmation() async {
    if (!mounted) return false;
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'حدث خطأ غير متوقع. يرجى المحاولة لاحقًا.',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: onSurface,
            ),
          ),
          content: const Text('حدث خطأ غير متوقع. يرجى المحاولة لاحقًا.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('حدث خطأ غير متوقع. يرجى المحاولة لاحقًا.'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('حدث خطأ غير متوقع. يرجى المحاولة لاحقًا.'),
            ),
          ],
        );
      },
    );

    return confirmed == true;
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    return BlocProvider.value(
      value: _walletSummaryCubit,
      child: PopScope(
        canPop: _allowRoutePop,
        onPopInvokedWithResult: (bool didPop, Object? _) async {
          if (didPop || _allowRoutePop) {
            return;
          }
          final bool shouldClose = await _showCloseConfirmation();
          if (shouldClose && mounted) {
            _closeWithResult(false);
          }
        },
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: viewInsets.bottom),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: 0.95,
              child: buildBankTransferScreen(context),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  final AnimationController controller;
  final double height;
  final double? width;
  final double radius;

  const _ShimmerBox({
    required this.controller,
    required this.height,
    this.width,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF2A2A2A)
        : const Color(0xFFE9E9E9);
    final highlight = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF3A3A3A)
        : const Color(0xFFF4F4F4);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + controller.value * 2, 0),
              end: Alignment(1.0 + controller.value * 2, 0),
              colors: [base, highlight, base],
              stops: const [0.1, 0.3, 0.4],
            ),
          ),
        );
      },
    );
  }
}
