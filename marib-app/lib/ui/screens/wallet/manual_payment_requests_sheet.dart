import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:marib/data/cubits/wallet/manual_payment_requests_cubit.dart';
import 'package:marib/utils/payment/manual_payment.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/data/model/wallet/manual_payment_requests_summary.dart';

class ManualPaymentRequestsSheet extends StatefulWidget {
  const ManualPaymentRequestsSheet({super.key});

  @override
  State<ManualPaymentRequestsSheet> createState() => _ManualPaymentRequestsSheetState();
}

class _ManualPaymentRequestsSheetState extends State<ManualPaymentRequestsSheet> {
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
                child: BlocBuilder<ManualPaymentRequestsCubit, ManualPaymentRequestsState>(
                  builder: (context, state) {
                    if (state is ManualPaymentRequestsLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (state is ManualPaymentRequestsFailure) {
                      return _ErrorView(
                        message: state.error.toString(),
                        onRetry: () => context.read<ManualPaymentRequestsCubit>().loadInitial(),
                      );
                    }
                    if (state is ManualPaymentRequestsSuccess) {
                      final summary = state.summary;
                      final hasSummary = summary != null;
                      final requests = state.requests;
                      final hasRequests = requests.isNotEmpty;
                      final headerCount = hasSummary ? 1 : 0;
                      final emptyCount = hasRequests ? 0 : 1;
                      final loadingCount = state.isLoadingMore ? 1 : 0;
                      final totalItems =
                          headerCount + (hasRequests ? requests.length : 0) + emptyCount + loadingCount;


                      return RefreshIndicator(
                        color: context.color.territoryColor,
                        onRefresh: _refresh,
                        child: ListView.builder(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                          padding: const EdgeInsets.only(bottom: 12),
                          itemCount: totalItems,

                          itemBuilder: (context, index) {
                            var currentIndex = index;

                            if (hasSummary) {
                              if (currentIndex == 0) {
                                return Padding(
                                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
                                  child: _ManualPaymentSummarySection(summary: summary!),
                                );
                              }
                              currentIndex -= 1;
                            }

                            if (!hasRequests) {
                              if (currentIndex == 0) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 24),
                                  child: _EmptyView(onRefresh: _refresh),
                                );
                              }
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }

                            if (currentIndex >= requests.length) {

                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }
                            final request = requests[currentIndex];
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



class _ManualPaymentSummarySection extends StatelessWidget {
  const _ManualPaymentSummarySection({required this.summary});

  final ManualPaymentRequestsSummary summary;

  @override
  Widget build(BuildContext context) {
    final statuses = summary.orderedStatuses(const ['pending', 'under_review', 'approved', 'rejected']);
    final cards = <_SummaryCardConfig>[
      _SummaryCardConfig(
        key: 'total',
        title: 'إجمالي الطلبات',
        status: summary.total,
        color: context.color.territoryColor,
        icon: Icons.receipt_long_outlined,
      ),
      for (final status in statuses)
        _SummaryCardConfig(
          key: status.key,
          title: _summaryTitleForKey(status.key),
          status: status,
          color: _summaryColorForKey(context, status.key),
          icon: _summaryIconForKey(status.key),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'نظرة عامة على الطلبات اليدوية',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth;
            const spacing = 12.0;
            final crossAxisCount = _summaryCrossAxisCount(maxWidth);
            final itemWidth = crossAxisCount == 1
                ? maxWidth
                : (maxWidth - spacing * (crossAxisCount - 1)) / crossAxisCount;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: cards
                  .map(
                    (card) => SizedBox(
                  width: itemWidth,
                  child: _ManualPaymentSummaryCard(
                    title: card.title,
                    status: card.status,
                    color: card.color,
                    icon: card.icon,
                  ),
                ),
              )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _ManualPaymentSummaryCard extends StatelessWidget {
  const _ManualPaymentSummaryCard({
    required this.title,
    required this.status,
    required this.color,
    required this.icon,
  });

  final String title;
  final ManualPaymentRequestsSummaryStatus status;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final countFormat = NumberFormat.decimalPattern('ar');
    final amountFormat = NumberFormat.decimalPattern('ar');
    final amountsLabel = _formatSummaryAmounts(status, amountFormat);

    return Card(
      elevation: 0,
      color: color.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: color.withOpacity(0.12),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              countFormat.format(status.count),
              style: theme.textTheme.headlineSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'عدد الطلبات',
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.color.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'إجمالي المبالغ',
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.color.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              amountsLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.color.textDefaultColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCardConfig {
  _SummaryCardConfig({
    required this.key,
    required this.title,
    required this.status,
    required this.color,
    required this.icon,
  });

  final String key;
  final String title;
  final ManualPaymentRequestsSummaryStatus status;
  final Color color;
  final IconData icon;
}

class _ManualPaymentTile extends StatelessWidget {
  const _ManualPaymentTile({required this.payment, required this.dateFormat});

  final ManualPayment payment;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    final statusColor = _manualPaymentStatusColor(context, payment.paymentStatus);

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
                    payment.manualReference ?? payment.transactionIdentifier ?? '#${payment.manualPaymentId ?? ''}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    payment.paymentStatus.capitalize(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: statusColor),
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
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
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

int _summaryCrossAxisCount(double maxWidth) {
  if (maxWidth >= 960) {
    return 4;
  }
  if (maxWidth >= 720) {
    return 3;
  }
  if (maxWidth >= 520) {
    return 2;
  }
  return 1;
}

String _summaryTitleForKey(String key) {
  switch (key) {
    case 'pending':
      return 'بانتظار التحقق';
    case 'under_review':
      return 'قيد المراجعة';
    case 'approved':
      return 'مدفوع';
    case 'rejected':
      return 'مرفوض';
    default:
      return '—';
  }
}

IconData _summaryIconForKey(String key) {
  switch (key) {
    case 'pending':
      return Icons.hourglass_bottom_outlined;
    case 'under_review':
      return Icons.search_outlined;
    case 'approved':
      return Icons.verified_outlined;
    case 'rejected':
      return Icons.highlight_off_outlined;
    default:
      return Icons.receipt_long_outlined;
  }
}

Color _summaryColorForKey(BuildContext context, String key) {
  switch (key) {
    case 'pending':
      return _manualPaymentStatusColor(context, 'pending');
    case 'under_review':
      return _manualPaymentStatusColor(context, 'under_review');
    case 'approved':
      return _manualPaymentStatusColor(context, 'approved');
    case 'rejected':
      return _manualPaymentStatusColor(context, 'rejected');
    default:
      return context.color.territoryColor;
  }
}

String _formatSummaryAmounts(
    ManualPaymentRequestsSummaryStatus status,
    NumberFormat format,
    ) {
  if (status.amounts.isEmpty) {
    return '—';
  }
  return status.amounts.entries
      .map((entry) => '${format.format(entry.value)} ${entry.key}')
      .join(' + ');
}

Color _manualPaymentStatusColor(BuildContext context, String status) {
  final normalized = status.toLowerCase();
  if (normalized.contains('success') || normalized.contains('approved') || normalized.contains('paid')) {
    return Colors.green.shade600;
  }
  if (normalized.contains('rejected') || normalized.contains('failed') || normalized.contains('declined')) {
    return Colors.red.shade600;
  }
  if (normalized.contains('review')) {
    return Colors.blue.shade600;
  }
  if (normalized.contains('pending') || normalized.contains('await') || normalized.contains('wait')) {
    return Colors.orange.shade600;
  }
  return context.color.textDefaultColor;
}