import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:marib/app/app_scroll_behavior.dart';

import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/constant.dart';
import 'package:marib/utils/api.dart';

// ظ…ظˆط¯ظٹظ„ط§طھ ظˆط®ط¯ظ…ط§طھ
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

part 'bank_transfer_screen_ui.dart';

class BankTransferScreen extends StatefulWidget {
  final BankTransferArgs args;

  const BankTransferScreen({super.key, required this.args});

  /// ظٹط¹ط±ط¶ ظ†ط§ظپط°ط© ط§ظ„طھط­ظˆظٹظ„ ط§ظ„ط¨ظ†ظƒظٹ ظƒظ†ط§ظپط°ط© ط³ظپظ„ظٹط© ط§ط­طھط±ط§ظپظٹط©.
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
  int? _pressedBankId; // ظ„طھط£ط«ظٹط± ط§ظ„ط¶ط؛ط· (Scale)
  int? _highlightedAccountNameBankId; // طھط£ط«ظٹط± ط§ظ„ط¶ط؛ط· ط¹ظ„ظ‰ ط§ط³ظ… ط§ظ„ظ…ط³طھظپظٹط¯

  WalletSummary? _walletSummary;
  dynamic _walletError;
  String? _lastWalletEventKey;
  CurrencyParseResult _settingsCurrencyInfo = const CurrencyParseResult();

  String? _paymentIntentId;
  String? _paymentTransactionId;
  Map<String, dynamic>? _subject;
  Map<String, dynamic>? _next;

  static const String _manualBankMethod = 'manual_bank';
  static const String _eastYemenMethod = 'east_yemen_bank';
  static const String _walletMethod = 'wallet';
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

  // ط§ظ„ط­ظ‚ظˆظ„
  final _senderCtrl = TextEditingController(); // ط§ط³ظ… ط§ظ„ظ…ط±ط³ظ„
  final _transferCodeCtrl = TextEditingController(); // ط±ظ‚ظ… ط§ظ„ط­ظˆط§ظ„ط©
  final _notesCtrl = TextEditingController(); // ظ…ظ„ط§ط­ط¸ط§طھ
  bool _allowRoutePop = false; // ظ„ظ„ط³ظ…ط§ط­ ط¨ط¥ط؛ظ„ط§ظ‚ ط§ظ„ظ†ط§ظپط°ط© ط¹ظ†ط¯ ط§ظ„طھط£ظƒظٹط¯ ظپظ‚ط·

  File? _receiptFile;
  String? _receiptName;
  bool _pickingReceipt = false;
  bool _submitting = false;
  bool _attempted = false; // ظ„ط¥ط¸ظ‡ط§ط± ط®ط·ط£ ط¨ط³ظٹط· ط¥ط°ط§ ط£ظڈط±ط³ظ„ ط¨ط¯ظˆظ† ط§ط³ظ… ظ…ط±ط³ظ„

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

      setState(() {
        _banks = displayableBanks;
        _eastYemenBank = eastConfigForUi;

        _paymentIntentId = settings.paymentIntentId?.trim();
        _paymentTransactionId = settings.paymentTransactionId?.trim();
        _subject = settings.subject;
        _next = settings.next;
        _settingsCurrencyInfo = settingsCurrency;

        final normalizedGateway = widget.args.normalizedGateway;
        final bool walletAvailable = _walletSummaryReady;

        final bool walletPurpose = isWalletTopUp || normalizedWalletTopUp;
        final bool walletOptionAllowed = walletAvailable && !walletPurpose;

        if (normalizedGateway == _eastYemenMethod && _eastYemenBank != null) {
          _selectedMethod = _eastYemenMethod;
          _selectedBankId = null;
        } else if (normalizedGateway == _walletMethod && walletOptionAllowed) {
          _selectedMethod = _walletMethod;
          _selectedBankId = null;
        } else if (normalizedGateway == _manualBankMethod &&
            _banks.isNotEmpty) {
          _selectedMethod = _manualBankMethod;
          _selectedBankId = _banks.first.id;
        } else if (_eastYemenBank != null) {
          _selectedMethod = _eastYemenMethod;
          _selectedBankId = null;
        } else if (walletOptionAllowed) {
          _selectedMethod = _walletMethod;
          _selectedBankId = null;
        } else if (_banks.isNotEmpty) {
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
          } else if (_banks.isNotEmpty) {
            _selectedMethod = _manualBankMethod;
            _selectedBankId = _banks.first.id;
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
      return 'ط­ط³ط§ط¨ ط±ظ‚ظ… $accountNumber';
    }
    final String? iban = bank.iban?.trim();
    if (iban != null && iban.isNotEmpty) {
      return 'IBAN $iban';
    }
    return 'ظˆط³ظٹظ„ط© ط¯ظپط¹';
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
        if (_eastYemenBank != null) {
          _selectedMethod = _eastYemenMethod;
          _selectedBankId = null;
        } else if (_banks.isNotEmpty) {
          _selectedMethod = _manualBankMethod;
          _selectedBankId ??= _banks.first.id;
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

    final selectedMethod = (_selectedMethod == null ||
            (walletPurpose && _selectedMethod == _walletMethod))
        ? _manualBankMethod
        : _selectedMethod!;

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
        if (_banks.isEmpty && settings.banks.isNotEmpty) {
          _banks = settings.banks;
        }
        if (_eastYemenBank == null && settings.eastYemenBank != null) {
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ط­ط¬ظ… ط§ظ„ط¥ظٹطµط§ظ„ ظٹطھط¬ط§ظˆط² 5MB')),
        );
        return;
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ط§ظ„ط±ط¬ط§ط، ط§ط®طھظٹط§ط± ظˆط³ظٹظ„ط© ط¯ظپط¹')),
        );
      }
      return;
    }

    if (_usingManualBank && !_receiptOk && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ط§ظ„ط±ط¬ط§ط، ط¥ط±ظپط§ظ‚ ط¥ظٹطµط§ظ„ ط§ظ„طھط­ظˆظٹظ„')),
      );
    }

    final bool walletPurpose =
        _isWalletTopUpPurpose(widget.args.normalizedPurpose) ||
            _isWalletTopUpPurpose(_resolvedPurpose());

    if (_usingWallet && walletPurpose) {
      _showOverlayMessage(
        'ظ„ط§ ظٹظ…ظƒظ† ط§ط³طھط®ط¯ط§ظ… ط§ظ„ظ…ط­ظپط¸ط© ظ„ط´ط­ظ† ط§ظ„ط±طµظٹط¯. ط§ظ„ط±ط¬ط§ط، ط§ط®طھظٹط§ط± طھط­ظˆظٹظ„ ط¨ظ†ظƒظٹ.',
        type: MessageType.warning,
      );
      return;
    }

    if (_usingWallet) {
      if (!_walletSummaryReady) {
        _showOverlayMessage(
          'طھط¹ط°ظ‘ط± طھط­ظ…ظٹظ„ ط±طµظٹط¯ ط§ظ„ظ…ط­ظپط¸ط©. ظٹط±ط¬ظ‰ طھط­ط¯ظٹط« ط§ظ„ط¨ط·ط§ظ‚ط© ظˆط§ظ„ظ…ط­ط§ظˆظ„ط© ظ…ط¬ط¯ط¯ظ‹ط§.',
          type: MessageType.error,
        );
        return;
      }
      if (!_walletCurrencyMatchesPayment) {
        final String walletLabel =
            _walletCurrencyLabel ?? _walletCurrencyCode ?? 'ط§ظ„ظ…ط­ظپط¸ط©';
        final String paymentLabel = _paymentCurrencyDisplay ??
            _paymentCurrencyLabel ??
            _paymentCurrencyCode ??
            'ط§ظ„ط¹ظ…ظ„ظٹط© ط§ظ„ط­ط§ظ„ظٹط©';
        _showOverlayMessage(
          'ظ„ط§ ظٹظ…ظƒظ† ط§ط³طھط®ط¯ط§ظ… ط§ظ„ظ…ط­ظپط¸ط© ط¨ط¹ظ…ظ„ط© $walletLabel ظ„ظ‡ط°ظ‡ ط§ظ„ط¹ظ…ظ„ظٹط© ط§ظ„طھظٹ ط¹ظ…ظ„طھظ‡ط§ $paymentLabel.',
          type: MessageType.error,
        );
        return;
      }
      if (!_walletHasEnoughBalance) {
        final String currency = _paymentCurrencyLabel ?? '';

        final amountText = widget.args.amount.toStringAsFixed(2);
        final String suffix = currency.isNotEmpty ? ' $currency' : '';
        _showOverlayMessage(
          'ط±طµظٹط¯ ط§ظ„ظ…ط­ظپط¸ط© ط؛ظٹط± ظƒط§ظپظچ ظ„ط¯ظپط¹ $amountText$suffix.',
          type: MessageType.error,
        );
        return;
      }
    }

    if (!_readyToSubmit) return;

    final ensured = await _ensurePaymentIntent();
    final resolvedIntentId = _paymentIntentId?.trim();
    if (!ensured || resolvedIntentId == null || resolvedIntentId.isEmpty) {
      _showOverlayMessage(
        'طھط¹ط°ظ‘ط± طھظ‡ظٹط¦ط© ط¹ظ…ظ„ظٹط© ط§ظ„ط¯ظپط¹. ظٹط±ط¬ظ‰ ط¥ط¹ط§ط¯ط© طھط­ظ…ظٹظ„ ط´ط§ط´ط© ط§ظ„طھط­ظˆظٹظ„ ظˆط§ظ„ظ…ط­ط§ظˆظ„ط© ظ…ط¬ط¯ط¯ظ‹ط§.',
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
      if (normalizedPurpose == 'order') {
        purposeForApi = 'order';
        orderIdForApi = resolvedPackageId;
      } else if (normalizedPurpose == 'package') {
        purposeForApi = 'package';
        packageIdForApi = resolvedPackageId;
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
          'طھط¹ط°ظ‘ط± طھط­ط¯ظٹط¯ ط¹ظ…ظ„ط© ط§ظ„ط·ظ„ط¨. ظٹط±ط¬ظ‰ ط§ظ„ظ…ط­ط§ظˆظ„ط© ظ„ط§ط­ظ‚ظ‹ط§.',
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

      final bool ok = result.success == true;

      final String successMessage = (() {
        final t = (result.message ?? '').trim();
        if (t.isNotEmpty) return t;
        return _usingEastYemen
            ? 'طھظ… ط¥ظƒظ…ط§ظ„ ط§ظ„ط¯ظپط¹ ط¹ط¨ط± ط¨ظˆط§ط¨ط© ط¨ظ†ظƒ ط§ظ„ط´ط±ظ‚ ط¨ظ†ط¬ط§ط­.'
            : _usingWallet
                ? 'طھظ… ط®طµظ… ط§ظ„ظ…ط¨ظ„ط؛ ظ…ظ† ط§ظ„ظ…ط­ظپط¸ط© ظˆط¥ظƒظ…ط§ظ„ ط§ظ„ط¹ظ…ظ„ظٹط© ط¨ظ†ط¬ط§ط­.'
                : 'طھظ… ط¥ط±ط³ط§ظ„ ط·ظ„ط¨ ط§ظ„ط¯ظپط¹طŒ ظٹطھظ… طھط­ظˆظٹظ„ظƒ ظ„ظ…طھط§ط¨ط¹ط© ط§ظ„ط·ظ„ط¨';
      })();

      final String errorMessage = (() {
        final t = (result.message ?? '').trim();
        if (t.isNotEmpty) return t;
        return _usingEastYemen
            ? 'طھط¹ط°ظ‘ط± ط¥ظƒظ…ط§ظ„ ط§ظ„ط¯ظپط¹ ط¹ط¨ط± ط¨ظˆط§ط¨ط© ط¨ظ†ظƒ ط§ظ„ط´ط±ظ‚. ط­ط§ظˆظ„ ظ…ط±ط© ط£ط®ط±ظ‰.'
            : _usingWallet
                ? 'طھط¹ط°ظ‘ط± ط®طµظ… ط§ظ„ظ…ط¨ظ„ط؛ ظ…ظ† ط§ظ„ظ…ط­ظپط¸ط©. ط­ط§ظˆظ„ ظ…ط±ط© ط£ط®ط±ظ‰.'
                : 'طھط¹ط°ظ‘ط± ط¥ط±ط³ط§ظ„ ط·ظ„ط¨ ط§ظ„ط¯ظپط¹. ط­ط§ظˆظ„ ظ…ط±ط© ط£ط®ط±ظ‰.';
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
          ? '$successMessage\nط±ظ‚ظ… ط§ظ„ط¹ظ…ظ„ظٹط©: $displayReference'
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
          _closeWithResult(enriched);
        });
      }
    } catch (e) {
      if (!mounted) return;
      _showOverlayMessage('طھط¹ط°ظ‘ط± ط¥ط±ط³ط§ظ„ ط§ظ„ط·ظ„ط¨: $e', type: MessageType.error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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
                          'طھط¹ظ„ظٹظ…ط§طھ ط§ظ„ط¯ظپط¹ ط¹ط¨ط± ط¨ظˆط§ط¨ط© ط¨ظ†ظƒ ط§ظ„ط´ط±ظ‚ ط§ظ„ط¥ظ„ظƒطھط±ظˆظ†ظٹط©',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: onSurface,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'ط¥ط؛ظ„ط§ظ‚',
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
                    'ظ…ظ„ط§ط­ط¸ط©: ظ„ط¥طھظ…ط§ظ… ط§ظ„ط¯ظپط¹ ط¹ط¨ط± ظ‡ط°ظ‡ ط§ظ„ط¨ظˆط§ط¨ط©طŒ ظٹط¬ط¨ ط£ظ† ظٹظƒظˆظ† ظ„ط¯ظٹظƒ ط­ط³ط§ط¨ ظ…ظپط¹ظ„ ظ„ط¯ظ‰ ط¨ظ†ظƒ ط§ظ„ط´ط±ظ‚.',
                    style: TextStyle(
                      height: 1.5,
                      color: onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...[
                    'ط§ظپطھط­ طھط·ط¨ظٹظ‚ ط¨ظ†ظƒ ط§ظ„ط´ط±ظ‚ ط§ظ„ظٹظ…ظ†ظٹ ط¹ظ„ظ‰ ظ‡ط§طھظپظƒ.',
                    'ظ…ظ† ط§ظ„ظˆط§ط¬ظ‡ط© ط§ظ„ط±ط¦ظٹط³ظٹط©طŒ ط§ط®طھط± ط£ظٹظ‚ظˆظ†ط© ط§ظ„طھط³ظˆظ‚.',
                    'ظ…ظ† ظ‚ط§ط¦ظ…ط© ط§ظ„طھط·ط¨ظٹظ‚ط§طھطŒ ط§ط®طھط± "ظ…ط§ط±ط¨ ط¨ظٹظ† ظٹط¯ظٹظƒ".',
                    'ط³ظٹط¸ظ‡ط± ظ„ظƒ ظƒظˆط¯ ط§ظ„ط´ط±ط§ط، ط§ظ„ط®ط§طµ ط¨ط¹ظ…ظ„ظٹط© ط§ظ„ط¯ظپط¹.',
                    'ط§ظ†ط³ط® ط§ظ„ظƒظˆط¯ ظˆط£ط¯ط®ظ„ظ‡ ظپظٹ طھط·ط¨ظٹظ‚ ظ…ط§ط±ط¨ ط¨ظٹظ† ظٹط¯ظٹظƒ ظ„طھط£ظƒظٹط¯ ط§ظ„ط¹ظ…ظ„ظٹط©.',
                    'ط§ط¶ط؛ط· ط¹ظ„ظ‰ ط²ط± طھط£ظƒظٹط¯ ظ„ط¥ظƒظ…ط§ظ„ ط¹ظ…ظ„ظٹط© ط§ظ„ط¯ظپط¹.',
                  ].map(
                    (step) => Padding(
                      padding: const EdgeInsetsDirectional.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('â€¢ '),
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
                    'طھظ†ظˆظٹظ‡: ط¨ظ…ط¬ط±ط¯ ط¥ط¯ط®ط§ظ„ ظƒظˆط¯ ط§ظ„ط´ط±ط§ط، ظˆطھط£ظƒظٹط¯ ط§ظ„ط¹ظ…ظ„ظٹط©طŒ ط³ظٹطھظ… ط®طµظ… ط§ظ„ظ…ط¨ظ„ط؛ ظ…ط¨ط§ط´ط±ط© ظ…ظ† ط­ط³ط§ط¨ظƒ ظپظٹ ط¨ظ†ظƒ ط§ظ„ط´ط±ظ‚طŒ ظƒظ…ط§ ط³ظٹطھظ… طھظ†ظپظٹط° ط¹ظ…ظ„ظٹط© ط§ظ„ط´ط±ط§ط، طھظ„ظ‚ط§ط¦ظٹط§ظ‹.',
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
                      child: const Text('ظپظ‡ظ…طھ ط§ظ„طھط¹ظ„ظٹظ…ط§طھ'),
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

  void _showOverlayMessage(String message,
      {MessageType type = MessageType.success}) {
    _overlayMessageTimer?.cancel();
    _overlayMessageEntry?.remove();

    final buildContext =
        Constant.navigatorKey.currentContext ?? context;
    final overlay = Overlay.maybeOf(buildContext, rootOverlay: true);

    if (overlay == null) {
      final messenger = ScaffoldMessenger.maybeOf(buildContext);
      messenger?.showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: type == MessageType.error ? Colors.red : null,
          duration: Duration(seconds: type == MessageType.error ? 4 : 3),
        ),
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

    HelperUtils.showSnackBarMessage(
      overlayContext,
      'طھظ… ظ†ط³ط® $label',
      //  type: MessageType.info,
      messageDuration: 2,
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
            'طھط£ظƒظٹط¯ ط§ظ„ط¥ط؛ظ„ط§ظ‚',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: onSurface,
            ),
          ),
          content: const Text('ظ‡ظ„ ط£ظ†طھ ظ…طھط£ظƒط¯ ظ…ظ† ط±ط؛ط¨طھظƒ ظپظٹ ط¥ط؛ظ„ط§ظ‚ ظ†ط§ظپط°ط© ط§ظ„ط¯ظپط¹طں'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('ظ…طھط§ط¨ط¹ط©'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('ط¥ط؛ظ„ط§ظ‚'),
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

/* ========================= ط´ظٹظ…ط± ط®ظپظٹظپ ط¨ط¯ظˆظ† ط¨ط§ظƒط¬ ========================= */

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
