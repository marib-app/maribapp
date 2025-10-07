import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:marib/data/cubits/wallet/wallet_withdrawals_cubit.dart';
import 'package:marib/data/model/wallet/wallet_operation_options.dart';
import 'package:marib/data/model/wallet/wallet_withdrawal.dart';
import 'package:marib/ui/screens/item/add_item_screen/custom_filed_structure/custom_field.dart';
import 'package:marib/ui/screens/widgets/dynamic_field/dynamic_field.dart'
    as dynamic_field;
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/ui_utils.dart';

class WalletWithdrawalSheet extends StatefulWidget {
  const WalletWithdrawalSheet({
    super.key,
    required this.options,
    this.balance,
    this.currency,
  });

  final WalletOperationOptions options;
  final double? balance;
  final String? currency;

  @override
  State<WalletWithdrawalSheet> createState() => _WalletWithdrawalSheetState();
}

class _WalletWithdrawalSheetState extends State<WalletWithdrawalSheet> {
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

  double? _extractAmountValue() {
    final Map<String, dynamic> combined = {};
    dynamic_field.AbstractField.fieldsData.forEach((key, value) {
      combined[key.toString()] = value;
    });
    CustomField.fieldsData.forEach((key, value) {
      combined.putIfAbsent(key.toString(), () => value);
    });

    List<dynamic>? values;
    final preferredKey = widget.options.amountFieldId;
    if (preferredKey != null && combined.containsKey(preferredKey)) {
      values = combined[preferredKey] as List<dynamic>?;
    }
    values ??= combined.entries
        .firstWhere(
          (entry) => entry.key.toLowerCase().contains('amount'),
          orElse: () => const MapEntry<String, dynamic>('', null),
        )
        .value as List<dynamic>?;

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
      final normalized =
          value.replaceAll(RegExp(r'[^0-9.,-]'), '').replaceAll(',', '.');
      return double.tryParse(normalized);
    }
    return null;
  }

  Map<String, dynamic> _buildPayload() {
    final Map<String, dynamic> combined = {};
    dynamic_field.AbstractField.fieldsData.forEach((key, value) {
      combined[key.toString()] = value;
    });
    CustomField.fieldsData.forEach((key, value) {
      combined.putIfAbsent(key.toString(), () => value);
    });

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
      final match =
          RegExp(r'(?:custom_field|fields)_files\[(.+?)\]').firstMatch(key);
      final fieldKey = match != null ? match.group(1) : key;
      payload['fields_files[$fieldKey]'] = value;
    });

    if (widget.options.clientTag != null &&
        widget.options.clientTag!.isNotEmpty) {
      payload['client_tag'] = widget.options.clientTag;
    }

    final amountValue = _extractAmountValue();
    if (amountValue != null) {
      payload['amount'] = amountValue;
    }

    return payload;
  }

  bool _validateAmount(double? amount) {
    if (amount == null) {
      HelperUtils.showSnackBarMessage(context, 'يرجى إدخال مبلغ السحب');
      return false;
    }

    if (widget.options.minimumAmount != null &&
        amount < widget.options.minimumAmount!) {
      HelperUtils.showSnackBarMessage(
        context,
        'الحد الأدنى للسحب هو ${widget.options.minimumAmount} ${widget.currency ?? ''}'
            .trim(),
      );
      return false;
    }

    if (widget.options.maximumAmount != null &&
        amount > widget.options.maximumAmount!) {
      HelperUtils.showSnackBarMessage(
        context,
        'الحد الأقصى للسحب هو ${widget.options.maximumAmount} ${widget.currency ?? ''}'
            .trim(),
      );
      return false;
    }

    if (widget.balance != null && amount > widget.balance! + 0.0001) {
      HelperUtils.showSnackBarMessage(
        context,
        'المبلغ المطلوب يتجاوز رصيد المحفظة المتاح',
      );
      return false;
    }

    return true;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final amount = _extractAmountValue();
    if (!_validateAmount(amount)) {
      return;
    }

    final payload = _buildPayload();

    try {
      final cubit = context.read<WalletWithdrawalsCubit>();
      final result = await cubit.submitWithdrawal(payload);
      if (!mounted) return;
      Navigator.of(context).pop<WalletWithdrawal>(result);
      HelperUtils.showSnackBarMessage(context, 'تم إرسال طلب السحب بنجاح');
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
                        'طلب سحب',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      if (widget.balance != null)
                        Text(
                          'الرصيد المتاح: ${widget.balance!.toStringAsFixed(2)} ${widget.currency?.toUpperCase() ?? ''}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      if (widget.options.minimumAmount != null ||
                          widget.options.maximumAmount != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            _buildLimitsText(),
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: context.color.textLightColor,
                                    ),
                          ),
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
                          'لا توجد حقول متاحة لطلب السحب حالياً.',
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
                    child: BlocBuilder<WalletWithdrawalsCubit,
                        WalletWithdrawalsState>(
                      builder: (context, state) {
                        final bool submitting =
                            state is WalletWithdrawalsSuccess
                                ? state.isSubmitting
                                : state is WalletWithdrawalsLoading;
                        return UiUtils.buildButton(
                          context,
                          onPressed: () {
                            _submit();
                          },
                          buttonTitle: 'إرسال الطلب',
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

  String _buildLimitsText() {
    final parts = <String>[];
    if (widget.options.minimumAmount != null) {
      parts.add('حد أدنى ${widget.options.minimumAmount}');
    }
    if (widget.options.maximumAmount != null) {
      parts.add('حد أقصى ${widget.options.maximumAmount}');
    }
    if (parts.isEmpty) {
      return '';
    }
    final currency = widget.currency?.toUpperCase();
    if (currency != null && currency.isNotEmpty) {
      return parts.join(' - ') + ' $currency';
    }
    return parts.join(' - ');
  }
}
