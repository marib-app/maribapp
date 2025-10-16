import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/constant.dart';
// موديلات وخدمات
import 'package:marib/utils/payment/bank_account.dart';
import 'package:marib/utils/payment/manual_payment_service.dart';
import 'package:marib/utils/payment/bank_transfer_args.dart';
import 'package:marib/ui/screens/cart/order_step.dart';

import 'package:marib/ui/screens/Transaction_screen.dart';

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




part 'bank_transfer_screen_ui.dart';





class BankTransferScreen extends StatefulWidget {
  final BankTransferArgs args;
  const BankTransferScreen({super.key, required this.args});

  static Route route(RouteSettings settings) {
    final args = settings.arguments as BankTransferArgs;
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => BankTransferScreen(args: args),
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

  List<BankAccount> _banks = [];
  EastYemenBankConfig? _eastYemenBank;
  String? _selectedMethod;

  bool _loadingBanks = false;
  bool _loadingWallet = false;

  int? _selectedBankId;
  int? _pressedBankId; // لتأثير الضغط (Scale)
  int? _highlightedAccountNameBankId; // تأثير الضغط على اسم المستفيد
  bool _walletBalancePressed = false; // تأثير الضغط على رصيد المحفظة

  WalletSummary? _walletSummary;
  dynamic _walletError;
  String? _lastWalletEventKey;
  CurrencyParseResult _settingsCurrencyInfo = const CurrencyParseResult();

  String? _paymentIntentId;
  String? _paymentTransactionId;

  static const String _manualBankMethod = 'manual_bank';
  static const String _eastYemenMethod = 'east_yemen_bank';
  static const String _walletMethod = 'wallet';

  static const int _eastYemenPressedKey = -1000;
  static const int _walletPressedKey = -1001;



  // الحقول
  final _senderCtrl = TextEditingController(); // اسم المرسل
  final _notesCtrl = TextEditingController(); // ملاحظات

  File? _receiptFile;
  String? _receiptName;
  bool _pickingReceipt = false;
  bool _submitting = false;
  bool _attempted = false; // لإظهار خطأ بسيط إذا أُرسل بدون اسم مرسل

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
    _walletUpdateSub = NotificationService.walletNotifications.listen(_handleWalletUpdate);

    _loadBanks();
    _loadWalletSummary();

  }

  @override
  void dispose() {
    _senderCtrl.dispose();
    _notesCtrl.dispose();
    _shimmerCtl.dispose();
    _walletSummarySub?.cancel();
    _walletUpdateSub?.cancel();
    _walletSummaryCubit.close();

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
      });
      return;
    }
    if (state is WalletSummaryFailure) {
      setState(() {
        _loadingWallet = false;
        _walletError = state.error;
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
      if (normalized.contains('order')) {
        return 'order';
      }

      if (normalized.contains('wallet')) {
        return 'wallet';
      }

      if (normalized == 'general') {
        return 'general';
      }
      return 'package';
    }

    final packageType = widget.args.packageType.trim().toLowerCase();
    if (packageType.contains('order')) {
      return 'order';
    }

    if (packageType.contains('wallet')) {
      return 'wallet';
    }

    if (packageType.isEmpty) {
      return 'general';
    }
    return 'package';
  }



  Future<void> _loadBanks() async {
    setState(() => _loadingBanks = true);
    try {
      final purpose = _resolvedPurpose();
      final purposeParam =
      (purpose == 'order' || purpose == 'package') ? purpose : null;

      final currency = widget.args.normalizedCurrency;


      final settings = await _service.fetchManualPaymentSettings(
        token: widget.args.token,
        purpose: purposeParam,

        currency: currency,
        orderId: widget.args.packageId,
        paymentMethod:
        ManualPaymentService.paymentMethodForApi(_manualBankMethod),

      );

      final List<CurrencyParseResult> currencyCandidates = <CurrencyParseResult>[
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

      setState(() {
        _banks = settings.banks;
        _eastYemenBank = settings.eastYemenBank;
        _paymentIntentId = settings.paymentIntentId?.trim();
        _paymentTransactionId = settings.paymentTransactionId?.trim();
        _settingsCurrencyInfo = settingsCurrency;

        final normalizedGateway = widget.args.normalizedGateway;
        final bool walletAvailable = _walletSummaryReady;

        if (normalizedGateway == _eastYemenMethod && _eastYemenBank != null) {
          _selectedMethod = _eastYemenMethod;
          _selectedBankId = null;
        } else if (normalizedGateway == _walletMethod && walletAvailable) {
          _selectedMethod = _walletMethod;
          _selectedBankId = null;

        } else if (normalizedGateway == _manualBankMethod && _banks.isNotEmpty) {
          _selectedMethod = _manualBankMethod;
          _selectedBankId = _banks.first.id;
        } else if (_eastYemenBank != null) {

          _selectedMethod = _eastYemenMethod;
          _selectedBankId = null;
        } else if (walletAvailable) {
          _selectedMethod = _walletMethod;
          _selectedBankId = null;
        } else if (_banks.isNotEmpty) {
          _selectedMethod = _manualBankMethod;
          _selectedBankId = _banks.first.id;
        } else {
          _selectedMethod = null;
          _selectedBankId = null;
        }
        if (_selectedMethod == null && normalizedGateway == _walletMethod) {
          _selectedMethod = _walletMethod;
          _selectedBankId = null;
        }
        _pressedBankId = null;
        _attempted = false;
      });
    } finally {
      if (mounted) setState(() => _loadingBanks = false);
    }
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
    final purposeParam =
    (purpose == 'order' || purpose == 'package') ? purpose : null;
    final currency = widget.args.normalizedCurrency;
    final selectedMethod = _selectedMethod ?? _manualBankMethod;

    try {
      final settings = await _service.fetchManualPaymentSettings(
        token: widget.args.token,
        purpose: purposeParam,
        currency: currency,
        orderId: widget.args.packageId,
        paymentMethod:
        ManualPaymentService.paymentMethodForApi(selectedMethod),
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
    } catch (_) {
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

  String _maskRight(String? v, {int take = 4}) {
    if (v == null || v.isEmpty) return '';
    final t = v.replaceAll(' ', '');
    if (t.length <= take) return t;
    return '•••• ${t.substring(t.length - take)}';
  }

  Future<void> _pickReceipt() async {
    setState(() => _pickingReceipt = true);
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowMultiple: false,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf', 'heic'],
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
          const SnackBar(content: Text('حجم الإيصال يتجاوز 5MB')),
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

  bool get _walletSummaryReady => _walletSummary != null && _walletError == null;

  bool get _walletHasEnoughBalance {
    final summary = _walletSummary;
    if (summary == null) {
      return false;
    }
    const double epsilon = 0.0001;
    return summary.balance + epsilon >= widget.args.amount;
  }


  bool get _shouldShowSenderField => _usingManualBank;


  bool get _readyToSubmit {
    if (_submitting) return false;
    if (_usingEastYemen) {
      return true;
    }
    if (_usingManualBank) {
      if (!_senderOk) return false;
      return _selectedBankId != null && _receiptOk;
    }

    if (_usingWallet) {
      return _walletSummaryReady && _walletHasEnoughBalance;
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
          const SnackBar(content: Text('الرجاء اختيار وسيلة دفع')),
        );
      }
      return;
    }

    if (_usingManualBank && !_receiptOk && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إرفاق إيصال التحويل')),
      );
    }


    if (_usingWallet) {
      if (!_walletSummaryReady) {
        _showOverlayMessage(
          'تعذّر تحميل رصيد المحفظة. يرجى تحديث البطاقة والمحاولة مجددًا.',
          type: MessageType.error,
        );
        return;
      }
      if (!_walletHasEnoughBalance) {
        final String currency = _paymentCurrencyLabel ?? '';

        final amountText = widget.args.amount.toStringAsFixed(2);
        final String suffix = currency.isNotEmpty ? ' $currency' : '';
        _showOverlayMessage(
          'رصيد المحفظة غير كافٍ لدفع $amountText$suffix.',
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
        'تعذّر تهيئة عملية الدفع. يرجى إعادة تحميل شاشة التحويل والمحاولة مجددًا.',
        type: MessageType.error,
      );
      return;
    }



    setState(() => _submitting = true);
    try {
      final normalizedPurpose = widget.args.normalizedPurpose;
      String? payableType;
      int? payableId;

      switch (normalizedPurpose) {
        case 'order':
          payableType = 'order';
          payableId = widget.args.packageId;
          break;
        case 'wallet':
          payableType = 'wallet_top_up';
          payableId = null;
          break;
        default:
          payableType = 'package';
          payableId = widget.args.packageId;
      }


      final int? resolvedId = widget.args.packageId > 0 ? widget.args.packageId : null;
      String? purposeForApi;
      int? orderIdForApi;
      int? packageIdForApi;
      if (normalizedPurpose == 'order') {
        purposeForApi = 'order';
        orderIdForApi = resolvedId;
      } else if (normalizedPurpose == 'package') {
        purposeForApi = 'package';
        packageIdForApi = resolvedId;
      } else if (resolvedId != null) {
        purposeForApi = 'package';
        packageIdForApi = resolvedId;
      }

      final notesText = _notesCtrl.text.trim();
      final senderName = _shouldShowSenderField ? _senderCtrl.text.trim() : '';

      final String? submissionCurrency = _paymentCurrencyCode;
      if (submissionCurrency == null || submissionCurrency.isEmpty) {
        _showOverlayMessage(
          'تعذّر تحديد عملة الطلب. يرجى المحاولة لاحقًا.',
          type: MessageType.error,
        );
        return;
      }

      final userNoteSections = <String>[];
      if (notesText.isNotEmpty) userNoteSections.add(notesText);
      if (senderName.isNotEmpty) userNoteSections.add('اسم المرسل: $senderName');
      final userNote = userNoteSections.join('\n');

      final contextMetadata = widget.args.toContext()
        ..removeWhere((k, v) => v == null);

      final metadata = <String, dynamic>{
        'device': _deviceLabel(),
        'source': _sourceLabel(),
        if (payableType != null) 'payable_type': payableType,
        if (payableId != null) 'payable_id': payableId,
        if (senderName.isNotEmpty) 'sender_name': senderName,
        if (contextMetadata.isNotEmpty) 'context': contextMetadata,
      }..removeWhere((k, v) {
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
          amount: widget.args.amount,
          currency: submissionCurrency,
          reference:
          (trimmedCode != null && trimmedCode.isNotEmpty) ? trimmedCode : null,
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
          amount: widget.args.amount,
          currency: submissionCurrency,
          reference: null,
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
            ? 'تم إكمال الدفع عبر بوابة بنك الشرق بنجاح.'
            : _usingWallet
            ? 'تم خصم المبلغ من المحفظة وإكمال العملية بنجاح.'
            : 'تم إرسال طلب الدفع، يتم تحويلك لمتابعة الطلب';

      })();

      final String errorMessage = (() {
        final t = (result.message ?? '').trim();
        if (t.isNotEmpty) return t;
        return _usingEastYemen
            ? 'تعذّر إكمال الدفع عبر بوابة بنك الشرق. حاول مرة أخرى.'
            : _usingWallet
            ? 'تعذّر خصم المبلغ من المحفظة. حاول مرة أخرى.'
            : 'تعذّر إرسال طلب الدفع. حاول مرة أخرى.';


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
          ? '$successMessage\nرقم العملية: $displayReference'
          : successMessage;


      _showOverlayMessage(ok ? successMessageWithReference : errorMessage,
          type: ok ? MessageType.success : MessageType.error);

      if (ok) {

        if (_usingWallet) {
          _loadWalletSummary(forceReload: true);
        }

        Future.microtask(() {
          if (!mounted) return;
          final bool isOrderPurpose = _resolvedPurpose() == 'order';

          if (isOrderPurpose) {
            Navigator.of(context).pushAndRemoveUntil(
              OrderStepsScreen.route(
                RouteSettings(
                  name: 'order-step',
                  arguments: {'order_id': widget.args.packageId},
                ),
              ),
                  (route) => route.isFirst,
            );
          } else {
            Navigator.of(context).pushAndRemoveUntil(
              TransactionScreen.route(
                const RouteSettings(name: 'transactions'),
              ),
                  (route) => route.isFirst,
            );
          }

        });
      }
    } catch (e) {
      if (!mounted) return;
      _showOverlayMessage('تعذّر إرسال الطلب: $e', type: MessageType.error);
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
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, padding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'تعليمات الدفع عبر بوابة بنك الشرق الإلكترونية',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'إغلاق',
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: Icon(Icons.close_rounded,
                          color: onSurface.withOpacity(.65)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'ملاحظة: لإتمام الدفع عبر هذه البوابة، يجب أن يكون لديك حساب مفعل لدى بنك الشرق.',
                  style: TextStyle(
                    height: 1.5,
                    color: onSurface.withOpacity(.8),
                  ),
                ),
                const SizedBox(height: 16),
                ...[
                  'افتح تطبيق بنك الشرق اليمني على هاتفك.',
                  'من الواجهة الرئيسية، اختر أيقونة التسوق.',
                  'من قائمة التطبيقات، اختر "مارب بين يديك".',
                  'سيظهر لك كود الشراء الخاص بعملية الدفع.',
                  'انسخ الكود وأدخله في تطبيق مارب بين يديك لتأكيد العملية.',
                  'اضغط على زر تأكيد لإكمال عملية الدفع.',
                ].map(
                      (step) => Padding(
                    padding: const EdgeInsetsDirectional.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• '),
                        Expanded(
                          child: Text(
                            step,
                            style: TextStyle(
                              height: 1.5,
                              color: onSurface.withOpacity(.9),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'تنويه: بمجرد إدخال كود الشراء وتأكيد العملية، سيتم خصم المبلغ مباشرة من حسابك في بنك الشرق، كما سيتم تنفيذ عملية الشراء تلقائياً.',
                  style: TextStyle(
                    height: 1.5,
                    color: onSurface.withOpacity(.85),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: const Text('فهمت التعليمات'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showOverlayMessage(String message, {MessageType type = MessageType.success}) {
    void show(BuildContext c) {
      final m = ScaffoldMessenger.maybeOf(c);
      if (m != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          m.showSnackBar(SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
            backgroundColor: type == MessageType.error ? Colors.red : null,
            duration: Duration(seconds: type == MessageType.error ? 4 : 3),
          ));
        });
      }
    }

    // جرّب السياقات بالترتيب
    final ctxs = <BuildContext?>[
      context,
      Navigator.of(context, rootNavigator: true).context,
      Constant.navigatorKey.currentContext,
    ];
    for (final c in ctxs) {
      if (c != null) { show(c); return; }
    }
  }





  Future<void> _copyValueToClipboard(String value,
      {required String label}) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;

    final overlayContext = Constant.navigatorKey.currentContext ?? context;
    if (overlayContext == null) return;

    HelperUtils.showSnackBarMessage(
      overlayContext,
      'تم نسخ $label',
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


  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: _walletSummaryCubit,
    child: buildBankTransferScreen(context),
  );
}




/* ========================= شيمر خفيف بدون باكج ========================= */

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
