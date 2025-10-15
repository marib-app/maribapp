import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:marib/data/cubits/wallet/wallet_transfers_cubit.dart';
import 'package:marib/data/model/wallet/wallet_operation_options.dart';
import 'package:marib/ui/screens/item/add_item_screen/custom_filed_structure/custom_field.dart';
import 'package:marib/ui/screens/widgets/dynamic_field/dynamic_field.dart' as dynamic_field;
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/utils/currency_utils.dart';
import 'package:marib/data/model/wallet/wallet_summary.dart';
import 'package:marib/data/model/wallet/wallet_summary.dart';
import 'package:marib/data/cubits/wallet/wallet_summary_cubit.dart';
import 'package:bloc/bloc.dart';

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
  final List<CustomFieldBuilder> _fields = [];

  @override
  void initState() {
    super.initState();
    _initialiseFields();
  }

  void _initialiseFields() {
    dynamic_field.AbstractField.fieldsData.clear();
    dynamic_field.AbstractField.files.clear();
    CustomField.fieldsData.clear();
    CustomField.files.clear();

    for (final rawField in widget.options.fields) {
      final fieldMap = Map<String, dynamic>.from(rawField);
      final builder = CustomFieldBuilder(fieldMap);
      builder.stateUpdater(setState);
      builder.init();
      _fields.add(builder);
    }
  }

  @override
  void dispose() {
    dynamic_field.AbstractField.fieldsData.clear();
    dynamic_field.AbstractField.files.clear();
    CustomField.fieldsData.clear();
    CustomField.files.clear();
    super.dispose();
  }

  Map<String, dynamic> _combinedFieldsData() {
    final Map<String, dynamic> combined = {};
    dynamic_field.AbstractField.fieldsData.forEach((key, value) {
      combined[key.toString()] = value;
    });
    CustomField.fieldsData.forEach((key, value) {
      combined.putIfAbsent(key.toString(), () => value);
    });
    return combined;
  }

  double? _extractAmountValue(Map<String, dynamic> combined) {
    List<dynamic>? values;
    final preferredKey = widget.options.amountFieldId;
    if (preferredKey != null && combined.containsKey(preferredKey)) {
      values = combined[preferredKey] as List<dynamic>?;
    }
    values ??= combined.entries.firstWhere(
          (entry) => entry.key.toLowerCase().contains('amount'),
      orElse: () => const MapEntry<String, dynamic>('', null),
    ).value as List<dynamic>?;

    if (values == null || values.isEmpty) {
      return null;
    }

    for (final raw in values) {
      final parsed = _toDouble(raw);
      if (parsed != null) {
        return parsed;
      }
    }
    return null;
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) {
      final normalized = value.replaceAll(RegExp(r'[^0-9.,-]'), '').replaceAll(',', '.');
      return double.tryParse(normalized);
    }
    return null;
  }

  Map<String, dynamic> _buildPayload(Map<String, dynamic> combined) {
    final Map<String, dynamic> payload = {};

    combined.forEach((key, value) {
      final List<dynamic> values = value is List ? value : <dynamic>[value];
      final cleaned = values
          .map((v) => v is String ? v.trim() : v)
          .where((v) => v != null && (v is! String || v.isNotEmpty))
          .toList();
      if (cleaned.isEmpty) return;

      if (cleaned.length == 1) {
        payload['fields[$key]'] = cleaned.first;
      } else {
        for (var i = 0; i < cleaned.length; i++) {
          payload['fields[$key][$i]'] = cleaned[i];
        }
        payload['fields[$key]'] = cleaned.join(',');
      }
    });

    final Map<String, dynamic> combinedFiles = {};
    dynamic_field.AbstractField.files.forEach((key, value) {
      combinedFiles[key.toString()] = value;
    });
    CustomField.files.forEach((key, value) {
      combinedFiles.putIfAbsent(key.toString(), () => value);
    });

    combinedFiles.forEach((key, value) {
      final match = RegExp(r'(?:custom_field|fields)_files\[(.+?)\]').firstMatch(key);
      final fieldKey = match != null ? match.group(1) : key;
      payload['fields_files[$fieldKey]'] = value;
    });

    if (widget.options.clientTag != null && widget.options.clientTag!.isNotEmpty) {
      payload['client_tag'] = widget.options.clientTag;
    }

    final amountValue = _extractAmountValue(combined);
    if (amountValue != null) {
      payload['amount'] = amountValue;
    }

    final String? activeCurrency = _resolveActiveCurrency();
    if (activeCurrency != null && !payload.containsKey('currency')) {
      payload['currency'] = activeCurrency;
    }


    return payload;
  }



  String? _resolveActiveCurrency() {
    final String? fromProp = CurrencyUtils.normalizeCurrencyCode(widget.currency);
    if (fromProp != null) {
      return fromProp;
    }

    final WalletSummaryCubit? summaryCubit =
    _maybeReadCubit<WalletSummaryCubit>(context);
    final WalletSummaryState? summaryState = summaryCubit?.state;

    WalletSummary? summary;
    if (summaryState is WalletSummaryLoadSuccess) {
      summary = summaryState.summary;
    } else if (summaryState is WalletSummaryLoading &&
        summaryState.previous != null) {
      summary = summaryState.previous!.summary;
    }

    if (summary != null) {
      final String? directCode = summary.currencyCode;
      if (directCode != null && directCode.trim().isNotEmpty) {
        return CurrencyUtils.normalizeCurrencyCode(directCode) ?? directCode;
      }

      final String? normalized =
      CurrencyUtils.normalizeCurrencyCode(summary.currency);
      if (normalized != null) {
        return normalized;
      }

      final parsed = CurrencyUtils.parseCurrency(summary.raw);
      final String? parsedCode = parsed.code ??
          CurrencyUtils.normalizeCurrencyCode(parsed.display);
      if (parsedCode != null) {
        return parsedCode;
      }
    }

    return null;
  }

  T? _maybeReadCubit<T>(BuildContext context) {
    try {
      return BlocProvider.of<T>(context, listen: false);
    } catch (_) {
      return null;
    }
  }

  bool _validateAmount(double? amount) {
    if (amount == null) {
      HelperUtils.showSnackBarMessage(context, 'يرجى تحديد المبلغ المراد تحويله');
      return false;
    }

    if (widget.options.minimumAmount != null && amount < widget.options.minimumAmount!) {
      HelperUtils.showSnackBarMessage(
        context,
        'قيمة التحويل أقل من الحد الأدنى المسموح',
      );
      return false;
    }

    if (widget.options.maximumAmount != null && amount > widget.options.maximumAmount!) {
      HelperUtils.showSnackBarMessage(
        context,
        'قيمة التحويل تتجاوز الحد الأعلى المسموح',
      );
      return false;
    }

    if (widget.balance != null && amount > widget.balance! + 0.0001) {
      HelperUtils.showSnackBarMessage(context, 'لا يتوفر رصيد كافٍ لإكمال التحويل');
      return false;
    }

    return true;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final combined = _combinedFieldsData();
    final amount = _extractAmountValue(combined);
    if (!_validateAmount(amount)) {
      return;
    }

    final payload = _buildPayload(combined);

    try {
      final cubit = context.read<WalletTransfersCubit>();
      final response = await cubit.submitTransfer(payload);
      if (!mounted) return;
      Navigator.of(context).pop<Map<String, dynamic>>(response);
      final message = response['message']?.toString() ?? 'تم إرسال التحويل بنجاح';
      HelperUtils.showSnackBarMessage(context, message);
    } catch (e) {
      if (!mounted) return;
      HelperUtils.showSnackBarMessage(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
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
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      if (widget.balance != null)
                        Text(
                          'الرصيد المتاح: ${widget.balance!.toStringAsFixed(2)} ${widget.currency?.toUpperCase() ?? ''}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
                if (_fields.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'لا توجد حقول لإتمام عملية التحويل حالياً.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, index) {
                        final field = _fields[index];
                        field.stateUpdater(setState);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: field.build(context),
                        );
                      },
                      childCount: _fields.length,
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
                            _submit();
                          },
                          buttonTitle: 'تنفيذ التحويل',
                          titleWhenProgress: 'جاري الإرسال...',
                          isInProgress: submitting,
                          disabled: submitting,
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
}