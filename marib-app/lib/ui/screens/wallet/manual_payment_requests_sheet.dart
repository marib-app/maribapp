import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:marib/data/cubits/wallet/manual_payment_requests_cubit.dart';
import 'package:marib/utils/payment/manual_payment.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/ui_utils.dart';

class ManualPaymentRequestsSheet extends StatefulWidget {
  const ManualPaymentRequestsSheet({super.key});

  @override
  State<ManualPaymentRequestsSheet> createState() =>
      _ManualPaymentRequestsSheetState();
}

class _ManualPaymentRequestsSheetState
    extends State<ManualPaymentRequestsSheet> {
  final ScrollController _scrollController = ScrollController();
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm');

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 120) {
      context.read<ManualPaymentRequestsCubit>().loadMore();
    }
  }

  Future<void> _refresh() async {
    await context.read<ManualPaymentRequestsCubit>().refresh();
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: context.color.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'طلبات الدفع اليدوي',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: BlocBuilder<ManualPaymentRequestsCubit,
                    ManualPaymentRequestsState>(
                  builder: (context, state) {
                    if (state is ManualPaymentRequestsLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (state is ManualPaymentRequestsFailure) {
                      return _ErrorView(
                        message: state.error.toString(),
                        onRetry: () => context
                            .read<ManualPaymentRequestsCubit>()
                            .loadInitial(),
                      );
                    }
                    if (state is ManualPaymentRequestsSuccess) {
                      if (state.requests.isEmpty) {
                        return _EmptyView(onRefresh: _refresh);
                      }
                      return RefreshIndicator(
                        color: context.color.territoryColor,
                        onRefresh: _refresh,
                        child: ListView.builder(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics()),
                          itemCount: state.requests.length +
                              (state.isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= state.requests.length) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child:
                                    Center(child: CircularProgressIndicator()),
                              );
                            }
                            final request = state.requests[index];
                            return _ManualPaymentTile(
                              payment: request,
                              dateFormat: _dateFormat,
                            );
                          },
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ManualPaymentTile extends StatelessWidget {
  const _ManualPaymentTile({required this.payment, required this.dateFormat});

  final ManualPayment payment;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(context, payment.paymentStatus);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    payment.manualReference ??
                        payment.transactionIdentifier ??
                        '#${payment.manualPaymentId ?? ''}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    payment.paymentStatus.capitalize(),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${payment.amount.toStringAsFixed(2)} ${payment.currency.toUpperCase()}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'بوابة الدفع: ${payment.paymentGateway}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              'تاريخ الإنشاء: ${dateFormat.format(payment.createdAt.toLocal())}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (payment.statusMessage?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  payment.statusMessage!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (payment.receiptUrl?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  payment.receiptUrl!,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: context.color.primaryColor),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(BuildContext context, String status) {
    final normalized = status.toLowerCase();
    if (normalized.contains('success') || normalized.contains('approved')) {
      return Colors.green.shade600;
    }
    if (normalized.contains('pending') || normalized.contains('review')) {
      return Colors.orange.shade600;
    }
    if (normalized.contains('rejected') || normalized.contains('failed')) {
      return Colors.red.shade600;
    }
    return context.color.textDefaultColor;
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'تعذر تحميل الطلبات اليدوية',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            UiUtils.buildButton(
              context,
              onPressed: onRetry,
              buttonTitle: 'إعادة المحاولة',
              height: 44,
              radius: 8,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: context.color.territoryColor,
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Column(
              children: [
                Text(
                  'لا توجد طلبات دفع يدوية بعد',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'عند إرسال طلب دفع يدوي سيظهر هنا لمتابعة حالته.',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
