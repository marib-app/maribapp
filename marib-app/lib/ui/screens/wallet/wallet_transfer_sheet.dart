import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:marib/data/cubits/wallet/wallet_transfers_cubit.dart';
import 'package:marib/data/model/wallet/wallet_operation_options.dart';
import 'package:marib/data/cubits/wallet/wallet_summary_cubit.dart';
import 'package:marib/data/model/wallet/wallet_recipient.dart';
import 'package:marib/data/model/wallet/wallet_summary.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/currency_utils.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:marib/utils/api.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/utils/payment/manual_payment_service.dart';




class WalletTransferSheet extends StatefulWidget {
  const WalletTransferSheet({
    super.key,
    required this.options,
    this.balance,
    this.currency,
  });

  final WalletOperationOptions options;
  final double? balance;
  final String? currency;

  @override
  State<WalletTransferSheet> createState() => _WalletTransferSheetState();
}

class _WalletTransferSheetState extends State<WalletTransferSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _recipientIdController;
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;

  final FocusNode _recipientFocus = FocusNode();
  final FocusNode _amountFocus = FocusNode();
  final FocusNode _notesFocus = FocusNode();

  bool _lookupInProgress = false;

  @override
  void initState() {
    super.initState();
    _recipientIdController = TextEditingController();
    _amountController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _recipientIdController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    _recipientFocus.dispose();
    _amountFocus.dispose();
    _notesFocus.dispose();
    super.dispose();
  }

  String? _validateRecipient(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'يرجى إدخال معرف المستلم';
    }

    final id = int.tryParse(trimmed);
    if (id == null || id <= 0) {
      return 'معرف المستلم يجب أن يكون رقماً صحيحاً';
    }

    return null;
  }

  String? _validateAmountField(String? value) {
    final amount = _parseAmount(value);
    if (amount == null || amount <= 0) {
      return 'يرجى إدخال مبلغ صالح';
    }

    final String? constraintMessage = _amountConstraintMessage(amount);
    if (constraintMessage != null) {
      return constraintMessage;
    }
    return null;
  }

  String? _validateNotes(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    if (value.trim().length > 1000) {
      return 'يمكن أن تحتوي الملاحظات على 1000 حرف كحد أقصى';
    }
    return null;
  }

  double? _parseAmount(String? value) {
    if (value == null) {
      return null;
    }
    final normalized = value.replaceAll(RegExp(r'[^0-9.,-]'), '').replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  String? _amountConstraintMessage(double amount) {
    final double? minimum = widget.options.minimumAmount;
    if (minimum != null && amount < minimum) {
      return 'قيمة التحويل أقل من الحد الأدنى المسموح';
    }

    final double? maximum = widget.options.maximumAmount;
    if (maximum != null && amount > maximum) {
      return 'قيمة التحويل تتجاوز الحد الأعلى المسموح';
    }

    final double? balance = widget.balance;
    if (balance != null && amount > balance + 0.0001) {
      return 'لا يتوفر رصيد كافٍ لإكمال التحويل';
    }
    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }



    final recipientId = int.tryParse(_recipientIdController.text.trim());
    final double? amount = _parseAmount(_amountController.text.trim());
    if (recipientId == null || amount == null) {
      HelperUtils.showSnackBarMessage(context, 'يرجى التحقق من بيانات التحويل');
      return;
    }

    final constraintMessage = _amountConstraintMessage(amount);
    if (constraintMessage != null) {
      HelperUtils.showSnackBarMessage(context, constraintMessage);
      return;
    }

    final notes = _notesController.text.trim();

    WalletRecipient recipient;
    setState(() {
      _lookupInProgress = true;
    });

    try {
      final transfersCubit = context.read<WalletTransfersCubit>();
      recipient = await transfersCubit.fetchRecipient(recipientId);
    } catch (error) {
      if (!mounted) return;
      HelperUtils.showSnackBarMessage(
        context,
        error.toString(),
      );
      setState(() {
        _lookupInProgress = false;
      });
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _lookupInProgress = false;
    });

    final confirmed = await _showConfirmationDialog(
      recipient,
      amount,
      _currencyLabel(),
      notes.isEmpty ? null : notes,
    );

    if (!confirmed || !mounted) {
      return;
    }
    final String clientTag = _resolveClientTag();

    final payload = <String, dynamic>{
      'recipient_id': recipient.id,
      'amount': amount,
      'client_tag': clientTag,
      if (notes.isNotEmpty) 'notes': notes,
    };

    final submissionCurrency = _resolveSubmissionCurrency();
    if (submissionCurrency != null) {
      payload['currency'] = submissionCurrency;
    }

    try {
      final cubit = context.read<WalletTransfersCubit>();
      final response = await cubit.submitTransfer(payload);
      if (!mounted) return;
      Navigator.of(context).pop<Map<String, dynamic>>(response);
      final message = response['message']?.toString() ?? 'تم إرسال التحويل بنجاح';
      HelperUtils.showSnackBarMessage(context, message);
    } catch (error) {
      if (!mounted) return;
      HelperUtils.showSnackBarMessage(context, error.toString());
    }
  }



  String _resolveClientTag() {
    final String? provided = widget.options.clientTag?.trim();
    if (provided != null && provided.isNotEmpty) {
      return provided;
    }
    return Api.generateIdempotencyKey();
  }



  Future<bool> _showConfirmationDialog(
      WalletRecipient recipient,
      double amount,
      String? currencyLabel,
      String? notes,
      ) async {
    final theme = Theme.of(context);

    final amountText = formatWalletTransferAmount(
      amount: amount,
      submissionCurrency: _resolveSubmissionCurrency(),
      currencyLabel: currencyLabel,
    );



    return await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: context.color.backgroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            'تأكيد التحويل',
            style: theme.textTheme.titleMedium,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildConfirmationRow('اسم المستلم', recipient.name, theme),
              const SizedBox(height: 8),
              _buildConfirmationRow(
                'رقم الجوال',
                recipient.mobile ?? 'غير متاح',
                theme,
              ),
              const SizedBox(height: 8),
              _buildConfirmationRow(
                'المبلغ',
                currencyLabel == null ? amountText : '$amountText $currencyLabel',
                theme,
              ),
              if (notes != null) ...[
                const SizedBox(height: 8),
                _buildConfirmationRow('الملاحظات', notes, theme),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
              child: const Text('تأكيد'),
            ),
          ],
        );
      },
    ) ??
        false;
  }

  Widget _buildConfirmationRow(String label, String value, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.textTheme.bodySmall?.color?.withOpacity(0.7) ??
                theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.bodyLarge,
        ),
      ],
    );
  }

  String? _currencyLabel() {
    final direct = widget.currency ?? widget.options.currency;
    final normalized = CurrencyUtils.normalizeCurrencyCode(direct);
    final summary = _activeSummary();
    if (summary != null && (direct == null || direct.isEmpty)) {
      final label = summary.currency;
      final code = summary.currencyCode ?? CurrencyUtils.normalizeCurrencyCode(summary.currency);
      return CurrencyUtils.displayToken(
        label: label,
        fallback: code,
        code: code,
      ) ??
          code ??
          label;
    }

    if (direct == null || direct.isEmpty) {
      return normalized;
    }

    return CurrencyUtils.displayToken(
      label: direct,
      fallback: normalized,
      code: normalized,
    ) ??
        normalized ??
        direct;
  }

  String? _resolveSubmissionCurrency() {
    final fromOptions = CurrencyUtils.normalizeCurrencyCode(widget.options.currency);
    if (fromOptions != null) {
      return fromOptions;
    }
    final fromWidget = CurrencyUtils.normalizeCurrencyCode(widget.currency);
    if (fromWidget != null) {
      return fromWidget;
    }

    return _resolveActiveCurrency();
  }

  WalletSummary? _activeSummary() {
    final WalletSummaryCubit? summaryCubit = _maybeReadCubit<WalletSummaryCubit>(context);
    final WalletSummaryState? summaryState = summaryCubit?.state;

    if (summaryState is WalletSummaryLoadSuccess) {
      return summaryState.summary;
    }
    if (summaryState is WalletSummaryLoading && summaryState.previous != null) {
      return summaryState.previous!.summary;
    }
    return null;
  }

  String? _resolveActiveCurrency() {
    final String? fromProp = CurrencyUtils.normalizeCurrencyCode(widget.currency);
    if (fromProp != null) {
      return fromProp;
    }

    final WalletSummary? summary = _activeSummary();


    if (summary != null) {
      final String? directCode = summary.currencyCode;
      if (directCode != null && directCode.trim().isNotEmpty) {
        return CurrencyUtils.normalizeCurrencyCode(directCode) ?? directCode;
      }

      final String? normalized = CurrencyUtils.normalizeCurrencyCode(summary.currency);

      if (normalized != null) {
        return normalized;
      }

      final parsed = CurrencyUtils.parseCurrency(summary.raw);
      final String? parsedCode = parsed.code ?? CurrencyUtils.normalizeCurrencyCode(parsed.display);

      if (parsedCode != null) {
        return parsedCode;
      }
    }

    return null;
  }

  T? _maybeReadCubit<T extends StateStreamableSource<Object?>>(BuildContext context) {
    try {
      return BlocProvider.of<T>(context, listen: false);
    } catch (_) {
      return null;
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyLabel = _currencyLabel();
    final submissionCurrency = _resolveSubmissionCurrency();

    return DraggableScrollableSheet(
      expand: false,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: context.color.backgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          ),
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Form(
            key: _formKey,
            child: CustomScrollView(
              controller: scrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 48,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: context.color.borderColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Text(
                        'تحويل رصيد',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      if (widget.balance != null)
                        Text(
                          'الرصيد المتاح: ${formatWalletTransferAmount(
                            amount: widget.balance!,
                            submissionCurrency: submissionCurrency,
                            currencyLabel: currencyLabel,
                          )} ${currencyLabel ?? ''}',

                          style: theme.textTheme.bodyMedium,
                        ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
          SliverToBoxAdapter(
            child: Column(
              children: [
              TextFormField(
              controller: _recipientIdController,
              focusNode: _recipientFocus,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'معرف المستلم',
                hintText: 'أدخل رقم المستخدم',
                        ),
              validator: _validateRecipient,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
              ],
              onFieldSubmitted: (_) {
                _amountFocus.requestFocus();
              },
                      ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amountController,
                  focusNode: _amountFocus,
                  textInputAction: TextInputAction.next,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'المبلغ',
                    hintText: buildWalletTransferAmountPlaceholder(
                      submissionCurrency: submissionCurrency,
                      currencyLabel: currencyLabel,
                    ),

                    suffixText: currencyLabel,
                  ),
                  validator: _validateAmountField,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  onFieldSubmitted: (_) {
                    _notesFocus.requestFocus();
                  },
                ),
                if (widget.options.minimumAmount != null ||
                    widget.options.maximumAmount != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        _amountHintText(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withOpacity(0.7) ??
                              theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  focusNode: _notesFocus,
                  textInputAction: TextInputAction.newline,
                  keyboardType: TextInputType.multiline,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات (اختياري)',
                    hintText: 'أدخل أي ملاحظات إضافية',
                  ),
                  validator: _validateNotes,
                ),
              ],
                  ),
          ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: BlocBuilder<WalletTransfersCubit, WalletTransfersState>(
                      builder: (context, state) {
                        final submitting = state is WalletTransferSubmitting;
                        return UiUtils.buildButton(
                          context,
                          onPressed: () {
                            if (submitting || _lookupInProgress) {
                              return;
                            }
                            unawaited(_submit());
                          },

                          buttonTitle: 'تنفيذ التحويل',
                          titleWhenProgress: 'جاري الإرسال...',
                          isInProgress: submitting,
                          disabled: submitting || _lookupInProgress,
                          showProgressTitle: true,
                          height: 48,
                          radius: 8,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _amountHintText() {
    return buildWalletTransferHintText(
      minimum: widget.options.minimumAmount,
      maximum: widget.options.maximumAmount,
      submissionCurrency: _resolveSubmissionCurrency(),
      currencyLabel: _currencyLabel(),
    );
  }
}


@visibleForTesting
String formatWalletTransferAmount({
  required double amount,
  required String? submissionCurrency,
  required String? currencyLabel,
}) {
  final String? formattingCurrency =
  (submissionCurrency ?? currencyLabel)?.trim();

  if (formattingCurrency == null || formattingCurrency.isEmpty) {
    return amount.toStringAsFixed(2);
  }

  return formatManualPaymentAmount(amount, formattingCurrency);
}

@visibleForTesting
String buildWalletTransferAmountPlaceholder({
  required String? submissionCurrency,
  required String? currencyLabel,
}) {
  final String? formattingCurrency =
  (submissionCurrency ?? currencyLabel)?.trim();

  if (formattingCurrency == null || formattingCurrency.isEmpty) {
    return '0.00';
  }




  return formatManualPaymentAmount(0, formattingCurrency);
}

@visibleForTesting
String buildWalletTransferHintText({
  required double? minimum,
  required double? maximum,
  required String? submissionCurrency,
  required String? currencyLabel,
}) {
  final buffer = StringBuffer();

  if (minimum != null) {
    buffer.write(
      'الحد الأدنى: ${formatWalletTransferAmount(
        amount: minimum,
        submissionCurrency: submissionCurrency,
        currencyLabel: currencyLabel,
      )}',
    );
  }

  if (maximum != null) {
    if (buffer.isNotEmpty) {
      buffer.write(' • ');
    }
    buffer.write(
      'الحد الأعلى: ${formatWalletTransferAmount(
        amount: maximum,
        submissionCurrency: submissionCurrency,
        currencyLabel: currencyLabel,
      )}',
    );
  }

  return buffer.toString();
}