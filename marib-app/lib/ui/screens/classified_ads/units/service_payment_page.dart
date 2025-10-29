import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/service_requests_cubit.dart';
import 'package:marib/utils/currency_utils.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:marib/utils/hive_utils.dart';
import 'package:marib/utils/payment/bank_transfer_args.dart';
import 'package:marib/utils/payment/bank_transfer_screen.dart';
import 'package:marib/utils/payment/manual_payment_service.dart'
    show ManualPaymentSubmissionResult;
import 'package:marib/app/navigation/app_page_route.dart';
import 'package:marib/app/navigation/motion/route_motion.dart';

class ServicePaymentPage extends StatefulWidget {
  const ServicePaymentPage({super.key, this.args = const {}});
  final Map<String, dynamic> args;

  static Route route(RouteSettings settings) {
    final Map<String, dynamic> args =
        (settings.arguments as Map?)?.cast<String, dynamic>() ?? const {};

    return AppPageRoute.build(
      builder: (_) => ServicePaymentPage(args: args),
      settings: settings,
      motionPattern: AppMotionPattern.glide,
    );
  }

  @override
  State<ServicePaymentPage> createState() => _ServicePaymentPageState();
}

class _ServicePaymentPageState extends State<ServicePaymentPage> {
  late final int? _serviceId;
  late final int? _serviceRequestId;
  late final String _serviceTitle;
  late final double? _amount;
  late final String? _currency;
  late final String? _note;

  bool _submitting = false;

  @override
  void initState() {
    super.initState();

    int? parseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isEmpty) return null;
        return int.tryParse(trimmed);
      }
      return null;
    }

    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is num) return value.toDouble();
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isEmpty) return null;
        return double.tryParse(trimmed);
      }
      return null;
    }

    String? parseString(dynamic value) {
      if (value == null) return null;
      final String stringified = value.toString().trim();
      return stringified.isEmpty ? null : stringified;
    }

    final Map<String, dynamic> data = widget.args;

    _serviceId =
        parseInt(data['serviceId'] ?? data['service_id'] ?? data['itemId']);
    _serviceRequestId = parseInt(
      data['service_request_id'] ??
          data['serviceRequestId'] ??
          data['request_id'],
    );
    _serviceTitle =
        parseString(data['serviceTitle'] ?? data['title']) ?? 'دفع خدمة';
    _amount = parseDouble(data['amount'] ?? data['price'] ?? data['total']);
    _currency =
        parseString(data['currency'] ?? data['currency_code'] ?? data['code']);
    _note = parseString(
      data['note'] ?? data['price_note'] ?? data['payment_note'],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String amountLabel = _formatAmount(_amount, _currency);

    return Scaffold(
      appBar: AppBar(
        title: const Text('دفع خدمة'),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _serviceTitle,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: theme.colorScheme.surfaceVariant,
                ),
              ),
              child: ListTile(
                title: const Text('المبلغ المستحق'),
                subtitle: Text(
                  amountLabel,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            if (_note != null && _note!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                color: theme.colorScheme.primaryContainer.withOpacity(0.35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ملاحظة حول الدفع',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _note!,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _handlePayPressed,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.payment),
                label: Text(_submitting ? 'Processing...' : 'Pay'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: theme.textTheme.titleMedium,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePayPressed() async {
    if (_submitting) return;

    final int? serviceId = _serviceId;
    final int? serviceRequestId = _serviceRequestId;
    final double? amount = _amount;

    if (serviceId == null) {
      HelperUtils.showSnackBarMessage(
        context,
        'Unable to determine the service for payment.',
      );
      return;
    }

    if (amount == null || amount <= 0) {
      HelperUtils.showSnackBarMessage(
        context,
        'Payment amount is missing or invalid.',
      );
      return;
    }

    if (serviceRequestId == null) {
      HelperUtils.showSnackBarMessage(
        context,
        'Service request id is missing.',
      );
      return;
    }

    final String token = HiveUtils.getJWT();
    if (token.trim().isEmpty) {
      HelperUtils.showSnackBarMessage(
        context,
        'Please sign in to continue with the payment.',
      );
      return;
    }

    setState(() => _submitting = true);

    final String? normalizedCurrency =
        (_currency != null && _currency!.trim().isNotEmpty)
            ? _currency!.trim().toUpperCase()
            : null;

    final BankTransferArgs args = BankTransferArgs(
      token: token,
      packageId: serviceId,
      amount: amount,
      currency: normalizedCurrency,
      packageType: 'service',
      itemId: serviceId,
      purpose: 'service',
      serviceId: serviceId,
      serviceTitle: _serviceTitle,
      priceNote: _note,
      serviceRequestId: serviceRequestId,
    );

    final dynamic result = await BankTransferScreen.show(context, args);

    if (!mounted) {
      return;
    }

    setState(() => _submitting = false);

    if (result == null || result == false) {
      return;
    }

    final String? transactionId = _extractPaymentTransactionId(result);
    final Map<String, dynamic>? subject = _extractSubject(result);
    final Map<String, dynamic>? next = _extractNext(result);

    if (transactionId == null) {
      HelperUtils.showSnackBarMessage(
        context,
        'Unable to determine payment transaction.',
      );
      return;
    }

    HelperUtils.showSnackBarMessage(
      context,
      'Payment submitted successfully.',
    );

    ServiceRequestsCubit? serviceRequestsCubit;
    try {
      serviceRequestsCubit = context.read<ServiceRequestsCubit>();
    } catch (_) {
      serviceRequestsCubit = null;
    }
    if (serviceRequestsCubit != null) {
      for (final ServiceRequestFilter filter in ServiceRequestFilter.values) {
        serviceRequestsCubit.refresh(filter);
      }
    }

    final Map<String, dynamic> resultPayload = {
      'payment_transaction_id': transactionId,
      'service_id': serviceId,
      'service_request_id': serviceRequestId,
      if (subject != null) 'subject': subject,
      if (next != null) 'next': next,
    };

    Navigator.of(context, rootNavigator: true).pushNamed(
      Routes.transactionHistory,
      arguments: {'focus_transaction_id': transactionId},
    );

    Navigator.of(context).maybePop(resultPayload);
  }

  String _formatAmount(double? amount, String? currency) {
    if (amount == null) {
      return '—';
    }

    final String displayCurrency =
        currency?.trim().isNotEmpty == true ? currency!.trim() : 'YER';

    final String preferred =
        CurrencyUtils.preferredDisplayFor(displayCurrency) ?? displayCurrency;

    final String formatted =
        amount % 1 == 0 ? amount.toStringAsFixed(0) : amount.toStringAsFixed(2);

    return '$formatted $preferred';
  }

  String? _extractPaymentTransactionId(dynamic result) {
    String? fromValue(dynamic value) {
      if (value == null) return null;
      if (value is ManualPaymentSubmissionResult) {
        final List<dynamic> candidates = [
          value.paymentTransactionId,
          value.manualPaymentId,
          value.paymentTransaction,
          value.manualPaymentRequest,
          value.raw,
        ];

        for (final candidate in candidates) {
          final normalized = fromValue(candidate);
          if (normalized != null && normalized.isNotEmpty) {
            return normalized;
          }
        }
        return null;
      }

      if (value is Map || value is Map<String, dynamic>) {
        final map = _normalizeMap(value);
        final List<dynamic> candidates = [
          map['payment_transaction_id'],
          map['paymentTransactionId'],
          map['transaction_id'],
          map['id'],
          map['payment_transaction'],
          map['transaction'],
        ];

        for (final candidate in candidates) {
          final normalized = fromValue(candidate);
          if (normalized != null && normalized.isNotEmpty) {
            return normalized;
          }
        }
        return null;
      }

      final String? normalized = value is String
          ? value.trim().isEmpty
              ? null
              : value.trim()
          : value is num
              ? value.toString()
              : null;
      return normalized;
    }

    return fromValue(result);
  }

  Map<String, dynamic>? _extractSubject(dynamic value) {
    if (value is ManualPaymentSubmissionResult) {
      return value.subject;
    }

    final map = _normalizeMap(value);
    if (map == null) return null;

    final subject = map['subject'];
    return _normalizeMap(subject);
  }

  Map<String, dynamic>? _extractNext(dynamic value) {
    if (value is ManualPaymentSubmissionResult) {
      return value.next;
    }

    final map = _normalizeMap(value);
    if (map == null) return null;

    final next = map['next'];
    return _normalizeMap(next);
  }

  Map<String, dynamic> _normalizeMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }
    if (value is Map) {
      return value.map((dynamic key, dynamic val) =>
          MapEntry<String, dynamic>(key.toString(), val));
    }
    return <String, dynamic>{};
  }
}


