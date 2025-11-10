import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:marib/app/navigation/app_page_route.dart';
import 'package:marib/app/navigation/motion/route_motion.dart';
import 'package:marib/data/cubits/merchant/merchant_dashboard_cubit.dart';
import 'package:marib/data/cubits/merchant/merchant_manual_payments_cubit.dart';
import 'package:marib/data/cubits/merchant/merchant_orders_cubit.dart';
import 'package:marib/data/model/merchant/merchant_dashboard_summary.dart';
import 'package:marib/data/model/merchant/merchant_manual_payment.dart';
import 'package:marib/data/model/merchant/merchant_order.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';
import 'package:url_launcher/url_launcher.dart';

class MerchantDashboardScreen extends StatelessWidget {
  const MerchantDashboardScreen({super.key});

  static Route route(RouteSettings settings) {
    return AppPageRoute.build(
      settings: settings,
      motionPattern: AppMotionPattern.glide,
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => MerchantDashboardCubit()..load()),
          BlocProvider(create: (_) => MerchantOrdersCubit()..load()),
          BlocProvider(create: (_) => MerchantManualPaymentsCubit()..load()),
        ],
        child: const MerchantDashboardScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('merchant_store_panel'.translate(context)),
          bottom: TabBar(
            tabs: [
              Tab(text: 'merchant_home'.translate(context)),
              Tab(text: 'merchant_requests'.translate(context)),
              Tab(text: 'merchant_remittances'.translate(context)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _MerchantOverviewTab(),
            _MerchantOrdersTab(),
            _MerchantManualPaymentsTab(),
          ],
        ),
      ),
    );
  }
}

class _MerchantOverviewTab extends StatelessWidget {
  const _MerchantOverviewTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MerchantDashboardCubit, MerchantDashboardState>(
      builder: (context, state) {
        if (state is MerchantDashboardLoading ||
            state is MerchantDashboardInitial) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is MerchantDashboardFailure) {
          return _ErrorView(
            error: state.error,
            onRetry: () => context.read<MerchantDashboardCubit>().load(),
          );
        }

        final summary = (state as MerchantDashboardSuccess).summary;
        final cards = <Widget>[
          _MetricsGrid(summary: summary),
          const SizedBox(height: 16),
          _StatusCard(status: summary.status),
          const SizedBox(height: 16),
          _WorkingHoursCard(hours: summary.workingHours),
          const SizedBox(height: 16),
          if (summary.policies.isNotEmpty)
            _PoliciesCard(policies: summary.policies),
          if (summary.policies.isNotEmpty) const SizedBox(height: 16),
          _StaffCard(staff: summary.staff),
        ];

        return RefreshIndicator(
          color: context.color.territoryColor,
          onRefresh: () => context.read<MerchantDashboardCubit>().refresh(),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            physics: const AlwaysScrollableScrollPhysics(),
            itemBuilder: (_, index) => cards[index],
            separatorBuilder: (_, __) => const SizedBox.shrink(),
            itemCount: cards.length,
          ),
        );
      },
    );
  }
}

class _MerchantOrdersTab extends StatefulWidget {
  const _MerchantOrdersTab();

  @override
  State<_MerchantOrdersTab> createState() => _MerchantOrdersTabState();
}

class _MerchantOrdersTabState extends State<_MerchantOrdersTab> {
  final ScrollController _scrollController = ScrollController();
  String _selectedStatus = _orderStatusFilters.first.value;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 120) {
      context.read<MerchantOrdersCubit>().loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MerchantOrdersCubit, MerchantOrdersState>(
      builder: (context, state) {
        if (state is MerchantOrdersLoading || state is MerchantOrdersInitial) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is MerchantOrdersFailure) {
          return _ErrorView(
            error: state.error,
            onRetry: () => context.read<MerchantOrdersCubit>().load(
                  status: _selectedStatus,
                ),
          );
        }

        final success = state as MerchantOrdersSuccess;
        final orders = success.orders;

        return RefreshIndicator(
          color: context.color.territoryColor,
          onRefresh: () => context.read<MerchantOrdersCubit>().refresh(),
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _StatusFilterChips(
                filters: _orderStatusFilters,
                value: _selectedStatus,
                onChanged: (value) {
                  setState(() => _selectedStatus = value);
                  context.read<MerchantOrdersCubit>().load(status: value);
                },
              ),
              const SizedBox(height: 12),
              if (orders.isEmpty)
                const _EmptyState(
                  messageKey: 'merchant_there_are_no_requests_currently',
                )
              else
                ...orders.map((order) => _OrderListTile(order: order)),
              if (success.isLoadingMore)
                const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _MerchantManualPaymentsTab extends StatefulWidget {
  const _MerchantManualPaymentsTab();

  @override
  State<_MerchantManualPaymentsTab> createState() =>
      _MerchantManualPaymentsTabState();
}

class _MerchantManualPaymentsTabState
    extends State<_MerchantManualPaymentsTab> {
  final ScrollController _scrollController = ScrollController();
  String _selectedStatus = _manualPaymentStatusFilters.first.value;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 120) {
      context.read<MerchantManualPaymentsCubit>().loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MerchantManualPaymentsCubit,
        MerchantManualPaymentsState>(
      builder: (context, state) {
        if (state is MerchantManualPaymentsLoading ||
            state is MerchantManualPaymentsInitial) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is MerchantManualPaymentsFailure) {
          return _ErrorView(
            error: state.error,
            onRetry: () => context
                .read<MerchantManualPaymentsCubit>()
                .load(status: _selectedStatus),
          );
        }

        final success = state as MerchantManualPaymentsSuccess;
        final requests = success.requests;

        return RefreshIndicator(
          color: context.color.territoryColor,
          onRefresh: () =>
              context.read<MerchantManualPaymentsCubit>().refresh(),
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _StatusFilterChips(
                filters: _manualPaymentStatusFilters,
                value: _selectedStatus,
                onChanged: (value) {
                  setState(() => _selectedStatus = value);
                  context
                      .read<MerchantManualPaymentsCubit>()
                      .load(status: value);
                },
              ),
              const SizedBox(height: 12),
              if (requests.isEmpty)
                const _EmptyState(
                  messageKey: 'merchant_there_are_no_transfers_currently',
                )
              else
                ...requests.map(
                  (payment) => _ManualPaymentTile(
                    payment: payment,
                    onTap: () => _openPaymentSheet(context, payment),
                  ),
                ),
              if (success.isLoadingMore)
                const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        );
      },
    );
  }

  void _openPaymentSheet(
    BuildContext context,
    MerchantManualPayment payment,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (modalContext) => _ManualPaymentDetailSheet(payment: payment),
    );
  }
}

class _ManualPaymentDetailSheet extends StatefulWidget {
  const _ManualPaymentDetailSheet({required this.payment});

  final MerchantManualPayment payment;

  @override
  State<_ManualPaymentDetailSheet> createState() =>
      _ManualPaymentDetailSheetState();
}

class _ManualPaymentDetailSheetState extends State<_ManualPaymentDetailSheet> {
  final TextEditingController _noteController = TextEditingController();
  bool _notifyCustomer = true;
  bool _submitting = false;
  String? _pendingDecision;

  bool get _canDecide =>
      widget.payment.status == 'pending' ||
      widget.payment.status == 'under_review';

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final payment = widget.payment;
    final theme = Theme.of(context);
    final amountText = _formatCurrency(payment.amount, payment.currency);
    final paymentDetails = _buildPaymentDetailRows(payment);
    final bankDetails = _buildBankDetailRows(payment);
    final attachmentButtons = _buildAttachmentButtons(payment);
    final userNote = payment.userNote;
    final adminNote = payment.adminNote;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                payment.orderNumber ?? 'ط·ظ„ط¨ #${payment.id}',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                _formatDate(payment.createdAt),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _StatusTag(
                    label: _manualPaymentStatusLabel(payment.status),
                    color: _manualPaymentStatusColor(payment.status, context),
                  ),
                  const SizedBox(width: 8),
                  _StatusTag(
                    label: _paymentStatusLabel(payment.paymentStatus),
                    color: _paymentStatusColor(payment.paymentStatus, context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                color: context.color.territoryColor.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ط§ظ„ظ…ط¨ظ„ط؛ ط§ظ„ظ…ط­ظˆظ„',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        amountText,
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (payment.manualBankName != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'ط§ظ„ط¨ظ†ظƒ: ${payment.manualBankName}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              _DetailSection(
                title: 'طھظپط§طµظٹظ„ ط§ظ„ط­ظˆط§ظ„ط©',
                rows: paymentDetails,
              ),
              _DetailSection(
                title: 'ط¨ظٹط§ظ†ط§طھ ط§ظ„ط­ط³ط§ط¨ ط§ظ„ط¨ظ†ظƒظٹ',
                rows: bankDetails,
              ),
              if (userNote != null && userNote.trim().isNotEmpty)
                _NoteCard(title: 'ظ…ظ„ط§ط­ط¸ط© ط§ظ„ط¹ظ…ظٹظ„', note: userNote.trim()),
              if (adminNote != null && adminNote.trim().isNotEmpty)
                _NoteCard(title: 'ظ…ظ„ط§ط­ط¸ط© ط³ط§ط¨ظ‚ط©', note: adminNote.trim()),
              if (attachmentButtons.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'ط§ظ„ظ…ط±ظپظ‚ط§طھ',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: attachmentButtons,
                ),
              ],
              if (_canDecide) ...[
                const SizedBox(height: 16),
                Text(
                  'ظ…ظ„ط§ط­ط¸ط© ط§ظ„طھط§ط¬ط±',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _noteController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: 'ط§ظƒطھط¨ ط³ط¨ط¨ ط§ظ„ط±ظپط¶ ط£ظˆ ط£ظٹ ظ…ظ„ط§ط­ط¸ط§طھ ط¥ط¶ط§ظپظٹط©',
                    border: OutlineInputBorder(),
                  ),
                ),
                SwitchListTile.adaptive(
                  value: _notifyCustomer,
                  onChanged: (value) => setState(() => _notifyCustomer = value),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('ط¥ط´ط¹ط§ط± ط§ظ„ط¹ظ…ظٹظ„ ط¨ط§ظ„طھط­ط¯ظٹط«'),
                ),
              ],
              if (_submitting) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
              const SizedBox(height: 16),
              if (_canDecide)
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed:
                            _submitting ? null : () => _submit('approved'),
                        icon: _pendingDecision == 'approved'
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_circle_outline),
                        label: const Text('طھط£ظƒظٹط¯ ط§ظ„ط­ظˆط§ظ„ط©'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            _submitting ? null : () => _submit('rejected'),
                        icon: _pendingDecision == 'rejected'
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.clear_outlined),
                        label: const Text('ط±ظپط¶ ط§ظ„ط­ظˆط§ظ„ط©'),
                      ),
                    ),
                  ],
                )
              else
                Center(
                  child: Text(
                    'طھظ… ط§طھط®ط§ط° ظ‚ط±ط§ط± ط¨ط®طµظˆطµ ظ‡ط°ظ‡ ط§ظ„ط­ظˆط§ظ„ط©.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<_DetailRowData> _buildPaymentDetailRows(
    MerchantManualPayment payment,
  ) {
    final rows = <_DetailRowData>[];
    void add(String label, String? value) {
      final normalized = value?.trim();
      if (normalized == null || normalized.isEmpty) return;
      rows.add(_DetailRowData(label, normalized));
    }

    add('ط±ظ‚ظ… ط§ظ„ط·ظ„ط¨', payment.orderNumber);
    add('ط§ظ„ط±ظ‚ظ… ط§ظ„ظ…ط±ط¬ط¹ظٹ', payment.reference);
    if (payment.createdAt != null) {
      add('ظˆظ‚طھ ط§ظ„ط·ظ„ط¨', _formatDate(payment.createdAt));
    }
    add('ط­ط§ظ„ط© ط§ظ„ط­ظˆط§ظ„ط©', _manualPaymentStatusLabel(payment.status));
    add('ط­ط§ظ„ط© ط§ظ„ط¯ظپط¹', _paymentStatusLabel(payment.paymentStatus));
    final transfer = payment.transferDetails;
    if (transfer != null) {
      add(
          'ط§ظ„ظ…ط¨ظ„ط؛ ظ…ظ† ط§ظ„طھط­ظˆظٹظ„',
          _detailValue(transfer, [
            'amount_formatted',
            'amount',
          ]));
      add('ط§ظ„ط¹ظ…ظ„ط©', _detailValue(transfer, ['currency']));
      add('ط§ط³ظ… ط§ظ„ظ…ظˆط¯ط¹', _detailValue(transfer, ['sender_name', 'payer_name']));
      add(
          'ط±ظ‚ظ… ط§ظ„ط¹ظ…ظ„ظٹط©',
          _detailValue(transfer, [
            'reference',
            'manual_reference',
            'transaction_reference',
          ]));
    }

    return rows;
  }

  List<_DetailRowData> _buildBankDetailRows(
    MerchantManualPayment payment,
  ) {
    final rows = <_DetailRowData>[];
    void add(String label, String? value) {
      final normalized = value?.trim();
      if (normalized == null || normalized.isEmpty) return;
      rows.add(_DetailRowData(label, normalized));
    }

    final bank = payment.manualBank;

    if (bank != null) {
      add('ط§ط³ظ… ط§ظ„ط¨ظ†ظƒ', bank.bankName ?? bank.name);
      add('ط§ط³ظ… ط§ظ„ظ…ط³طھظپظٹط¯', bank.beneficiaryName ?? bank.accountName);
      add('ط±ظ‚ظ… ط§ظ„ط­ط³ط§ط¨', bank.accountNumber);
      add('ط±ظ‚ظ… ط§ظ„ط¢ظٹط¨ط§ظ†', bank.iban);
      add('ظ…ظ„ط§ط­ط¸ط§طھ', bank.note);
    }

    final transfer = payment.transferDetails;
    if (transfer != null) {
      add(
          'ط§ظ„ط¨ظ†ظƒ ط§ظ„ظ…ط±ط³ظ„',
          _detailValue(transfer, [
            'bank_name',
            'manual_bank_name',
          ]));
      add(
          'ط±ظ‚ظ… ط§ظ„ط­ط³ط§ط¨ ط§ظ„ظ…ط­ظˆظ„ ظ…ظ†ظ‡',
          _detailValue(transfer, [
            'from_account',
            'source_account',
          ]));
    }

    return rows;
  }

  List<Widget> _buildAttachmentButtons(MerchantManualPayment payment) {
    final buttons = <Widget>[];

    for (final attachment in payment.attachments) {
      final url = attachment.url;
      if (url == null) continue;
      buttons.add(
        OutlinedButton.icon(
          onPressed: () => _openUrl(url),
          icon: const Icon(Icons.attach_file),
          label: Text(attachment.name ?? 'ظ…ط±ظپظ‚'),
        ),
      );
    }

    final receiptUrl = payment.receiptUrl;
    if (buttons.isEmpty && receiptUrl != null && receiptUrl.trim().isNotEmpty) {
      buttons.add(
        OutlinedButton.icon(
          onPressed: () => _openUrl(receiptUrl),
          icon: const Icon(Icons.receipt_long_outlined),
          label: const Text('ط¹ط±ط¶ ط¥ظٹطµط§ظ„ ط§ظ„طھط­ظˆظٹظ„'),
        ),
      );
    }

    return buttons;
  }

  Future<void> _openUrl(String? url) async {
    final trimmed = (url ?? '').trim();
    if (trimmed.isEmpty) {
      HelperUtils.showSnackBarMessage(context, 'ط§ظ„ط±ط§ط¨ط· ط؛ظٹط± ظ…طھط§ط­.');
      return;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null) {
      HelperUtils.showSnackBarMessage(context, 'ط§ظ„ط±ط§ط¨ط· ط؛ظٹط± طµط§ظ„ط­.');
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      HelperUtils.showSnackBarMessage(context, 'طھط¹ط°ط± ظپطھط­ ط§ظ„ط±ط§ط¨ط·.');
    }
  }

  Future<void> _submit(String decision) async {
    if (!_canDecide || _submitting) {
      return;
    }

    final note = _noteController.text.trim();

    if (decision == 'rejected' && note.isEmpty) {
      HelperUtils.showSnackBarMessage(context, 'ظٹط±ط¬ظ‰ ظƒطھط§ط¨ط© ط³ط¨ط¨ ط§ظ„ط±ظپط¶.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _pendingDecision = decision;
    });

    try {
      await context.read<MerchantManualPaymentsCubit>().decide(
            manualPaymentId: widget.payment.id,
            decision: decision,
            note: note.isEmpty ? null : note,
            notifyCustomer: _notifyCustomer,
          );

      if (!mounted) return;

      Navigator.of(context).maybePop();
      HelperUtils.showSnackBarMessage(
        context,
        decision == 'approved' ? 'طھظ… ظ‚ط¨ظˆظ„ ط§ظ„ط­ظˆط§ظ„ط© ط¨ظ†ط¬ط§ط­.' : 'طھظ… ط±ظپط¶ ط§ظ„ط­ظˆط§ظ„ط©.',
        type: MessageType.success,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _pendingDecision = null;
      });
      HelperUtils.showSnackBarMessage(context, error.toString());
    }
  }
}

class _ManualPaymentTile extends StatelessWidget {
  const _ManualPaymentTile({
    required this.payment,
    required this.onTap,
  });

  final MerchantManualPayment payment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final createdAt = _formatDate(payment.createdAt);
    final amountText = _formatCurrency(payment.amount, payment.currency);

    return Card(
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          payment.orderNumber ?? 'ط·ظ„ط¨ #${payment.id}',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          payment.manualBankName ?? 'ط­ظˆط§ظ„ط© ط¨ظ†ظƒظٹط©',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _StatusTag(
                        label: _manualPaymentStatusLabel(payment.status),
                        color:
                            _manualPaymentStatusColor(payment.status, context),
                      ),
                      _StatusTag(
                        label: _paymentStatusLabel(payment.paymentStatus),
                        color:
                            _paymentStatusColor(payment.paymentStatus, context),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'ط§ظ„ظ…ط¨ظ„ط؛: $amountText',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                'ط§ظ„طھط§ط±ظٹط®: $createdAt',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderListTile extends StatelessWidget {
  const _OrderListTile({required this.order});

  final MerchantOrder order;

  @override
  Widget build(BuildContext context) {
    final createdAt = _formatDate(order.createdAt);
    final totalText = _formatCurrency(order.total, order.currency);

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.orderNumber,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  createdAt,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'ط§ظ„ظ…ط¬ظ…ظˆط¹: $totalText',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatusTag(
                  label: _orderStatusLabel(order.status),
                  color: _statusColor(order.status, context),
                ),
                _StatusTag(
                  label: _paymentStatusLabel(order.paymentStatus),
                  color: _paymentStatusColor(order.paymentStatus, context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _DetailRowData {
  const _DetailRowData(this.label, this.value);

  final String label;
  final String value;
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.rows});

  final String title;
  final List<_DetailRowData> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            child: Column(
              children: rows
                  .map((row) => _DetailRow(data: row))
                  .toList(growable: false),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.data});

  final _DetailRowData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          SelectableText(
            data.value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.title, required this.note});

  final String title;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                note,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusFilterChips extends StatelessWidget {
  const _StatusFilterChips({
    required this.filters,
    required this.value,
    required this.onChanged,
  });

  final List<_StatusFilter> filters;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final selected = filter.value == value;
          return Padding(
            padding: const EdgeInsetsDirectional.only(end: 8.0),
            child: ChoiceChip(
              label: Text(filter.label),
              selected: selected,
              onSelected: (_) => onChanged(filter.value),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _StatusFilter {
  const _StatusFilter({required this.label, required this.value});

  final String label;
  final String value;
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.messageKey});

  final String messageKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 48,
            color: context.color.secondaryColor,
          ),
          const SizedBox(height: 12),
          Text(
            messageKey.translate(context),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.summary});

  final MerchantDashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final cards = <_MetricCardData>[
      _MetricCardData(
        titleKey: 'merchant_today',
        snapshot: summary.overview.today,
        color: context.color.territoryColor.withOpacity(0.14),
      ),
      _MetricCardData(
        titleKey: 'merchant_last_7_days',
        snapshot: summary.overview.week,
        color: Colors.indigo.withOpacity(0.1),
      ),
      _MetricCardData(
        titleKey: 'merchant_last_30_days',
        snapshot: summary.overview.month,
        color: Colors.teal.withOpacity(0.1),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ط£ط¯ط§ط، ط§ظ„ظ…طھط¬ط±',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 680;
            final crossAxisCount = isWide ? 3 : 1;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: isWide ? 1.4 : 1.2,
              ),
              itemCount: cards.length,
              itemBuilder: (_, index) => _MetricCard(data: cards[index]),
            );
          },
        ),
      ],
    );
  }
}

class _MetricCardData {
  const _MetricCardData({
    required this.titleKey,
    required this.snapshot,
    required this.color,
  });

  final String titleKey;
  final MerchantMetricSnapshot snapshot;
  final Color color;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.data});

  final _MetricCardData data;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: data.color,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data.titleKey.translate(context),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _MetricValue(label: 'ط§ظ„ط·ظ„ط¨ط§طھ', value: data.snapshot.orders),
                _MetricValue(
                    label: 'ط§ظ„ط¥ظٹط±ط§ط¯',
                    valueText: NumberFormat.currency(symbol: 'ط±.ظٹ')
                        .format(data.snapshot.revenue)),
                _MetricValue(label: 'ط§ظ„ط²ظٹط§ط±ط§طھ', value: data.snapshot.visits),
                _MetricValue(
                    label: 'ظ…ط´ط§ظ‡ط¯ط§طھ ط§ظ„ظ…ظ†طھط¬ط§طھ',
                    value: data.snapshot.productViews),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricValue extends StatelessWidget {
  const _MetricValue({
    required this.label,
    this.value,
    this.valueText,
  }) : assert(valueText != null || value != null);

  final String label;
  final int? value;
  final String? valueText;

  @override
  Widget build(BuildContext context) {
    final displayValue = valueText ?? NumberFormat.compact().format(value ?? 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          displayValue,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status});

  final MerchantStoreStatus status;

  @override
  Widget build(BuildContext context) {
    final bool browseOnly = status.closureMode == 'browse_only';
    final bool isClosed = status.isManuallyClosed || !status.isOpenNow;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 12,
                  color: status.isOpenNow ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  status.isOpenNow ? 'ط§ظ„ظ…طھط¬ط± ظ…ظپطھظˆط­' : 'ط§ظ„ظ…طھط¬ط± ظ…ط؛ظ„ظ‚ ط­ط§ظ„ظٹط§ظ‹',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            if (!status.isOpenNow && status.nextOpenAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  'ظٹظپطھط­ ظپظٹ: ${status.nextOpenAt}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const Divider(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _StatusBadge(
                  label: 'ط­ط§ظ„ط© ط§ظ„ظ†ط¸ط§ظ…',
                  value: browseOnly ? 'طھطµظپط­ ظپظ‚ط·' : 'ظƒط§ظ…ظ„',
                ),
                _StatusBadge(
                  label: 'ط­ط¯ ط§ظ„ط·ظ„ط¨',
                  value: status.minOrderAmount != null
                      ? NumberFormat.currency(symbol: 'ط±.ظٹ')
                          .format(status.minOrderAmount)
                      : 'ط؛ظٹط± ظ…ط­ط¯ط¯',
                ),
                _StatusBadge(
                  label: 'ط§ظ„طھظˆطµظٹظ„',
                  value: status.allowDelivery ? 'ظ…ظپط¹ظ„' : 'ظ…ظˆظ‚ظˆظپ',
                ),
                _StatusBadge(
                  label: 'ط§ظ„ط§ط³طھظ„ط§ظ…',
                  value: status.allowPickup ? 'ظ…ظپط¹ظ„' : 'ظ…ظˆظ‚ظˆظپ',
                ),
                _StatusBadge(
                  label: 'ط­ظˆط§ظ„ط§طھ ظٹط¯ظˆظٹط©',
                  value: status.allowManualPayments ? 'ظ…ط³ظ…ظˆط­' : 'ظ…ظˆظ‚ظˆظپ',
                ),
                _StatusBadge(
                  label: 'ط§ظ„ط¯ظپط¹ ط¨ط§ظ„ظ…ط­ظپط¸ط©',
                  value: status.allowWallet ? 'ظ…ط³ظ…ظˆط­' : 'ظ…ظˆظ‚ظˆظپ',
                ),
                _StatusBadge(
                  label: 'ط§ظ„ط¯ظپط¹ ط¹ظ†ط¯ ط§ظ„ط§ط³طھظ„ط§ظ…',
                  value: status.allowCod ? 'ظ…ط³ظ…ظˆط­' : 'ظ…ظˆظ‚ظˆظپ',
                ),
              ],
            ),
            if (isClosed && status.closureReason != null) ...[
              const SizedBox(height: 12),
              Text(
                'ط³ط¨ط¨ ط§ظ„ط¥ط؛ظ„ط§ظ‚: ${status.closureReason}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.color.secondaryColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _WorkingHoursCard extends StatelessWidget {
  const _WorkingHoursCard({required this.hours});

  final List<MerchantWorkingHour> hours;

  static const List<String> weekdayLabels = <String>[
    'ط§ظ„ط£ط­ط¯',
    'ط§ظ„ط¥ط«ظ†ظٹظ†',
    'ط§ظ„ط«ظ„ط§ط«ط§ط،',
    'ط§ظ„ط£ط±ط¨ط¹ط§ط،',
    'ط§ظ„ط®ظ…ظٹط³',
    'ط§ظ„ط¬ظ…ط¹ط©',
    'ط§ظ„ط³ط¨طھ',
  ];

  @override
  Widget build(BuildContext context) {
    final sortedHours = hours.toList()
      ..sort((a, b) => a.weekday.compareTo(b.weekday));

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ط³ط§ط¹ط§طھ ط§ظ„ط¹ظ…ظ„',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ...sortedHours.map((hour) {
              final label = weekdayLabels[hour.weekday.clamp(0, 6)];
              String range = 'ظ…ط؛ظ„ظ‚';
              if (hour.isOpen &&
                  hour.opensAt != null &&
                  hour.closesAt != null) {
                range = '${hour.opensAt} - ${hour.closesAt}';
              }
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(label),
                trailing: Text(range),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _PoliciesCard extends StatelessWidget {
  const _PoliciesCard({required this.policies});

  final List<MerchantPolicy> policies;

  @override
  Widget build(BuildContext context) {
    final entries = policies
        .map((policy) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(policy.title ?? policy.type),
              subtitle: Text(policy.content),
            ))
        .toList();

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ط§ظ„ط³ظٹط§ط³ط§طھ',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ...entries,
          ],
        ),
      ),
    );
  }
}

class _StaffCard extends StatelessWidget {
  const _StaffCard({required this.staff});

  final MerchantStaffInfo? staff;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ط¨ط±ظٹط¯ ظ„ظˆط­ط© ط§ظ„ظ…طھط¬ط±',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (staff == null)
              Text(
                'ظ„ظ… ظٹطھظ… ط­ط¬ط² ط¨ط±ظٹط¯ ط¨ط¹ط¯. ظٹظ…ظƒظ†ظƒ ط¥ظ†ط´ط§ط¤ظ‡ ظ…ظ† ط¥ط¹ط¯ط§ط¯ط§طھ ط§ظ„ظ…طھط¬ط±.',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    staff!.email,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ط§ظ„ط­ط§ظ„ط©: ${staff!.status}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            const SizedBox(height: 8),
            Text(
              'ط§ط³طھط®ط¯ظ… ظ‡ط°ط§ ط§ظ„ط¨ط±ظٹط¯ ظ„طھط³ط¬ظٹظ„ ط§ظ„ط¯ط®ظˆظ„ ط¥ظ„ظ‰ ظ„ظˆط­ط© ط§ظ„طھط­ظƒظ… ط§ظ„ظ…ط®طµطµط© ظ„ظ„ظ…طھط¬ط± ظˆظ…طھط§ط¨ط¹ط© ط§ظ„ط·ظ„ط¨ط§طھ.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final dynamic error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 42, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              'طھط¹ط°ط± طھط­ظ…ظٹظ„ ط¨ظٹط§ظ†ط§طھ ط§ظ„ظ…طھط¬ط±',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              error?.toString() ?? '',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('ط¥ط¹ط§ط¯ط© ط§ظ„ظ…ط­ط§ظˆظ„ط©'),
            ),
          ],
        ),
      ),
    );
  }
}

const List<_StatusFilter> _orderStatusFilters = [
  _StatusFilter(label: 'ط§ظ„ظƒظ„', value: ''),
  _StatusFilter(label: 'ط¨ط§ظ†طھط¸ط§ط± ط§ظ„ط¯ظپط¹', value: 'pending'),
  _StatusFilter(label: 'ط¯ظپط¹ط© ظ…ظ‚ط¯ظ…ط©', value: 'deposit_paid'),
  _StatusFilter(label: 'ظ‚ظٹط¯ ط§ظ„ظ…ط±ط§ط¬ط¹ط©', value: 'under_review'),
  _StatusFilter(label: 'ظ…ط¤ظƒط¯', value: 'confirmed'),
  _StatusFilter(label: 'ط¬ط§ط± ط§ظ„طھط­ط¶ظٹط±', value: 'preparing'),
  _StatusFilter(label: 'ط¬ط§ظ‡ط² ظ„ظ„طھط³ظ„ظٹظ…', value: 'ready_for_delivery'),
  _StatusFilter(label: 'ظ‚ظٹط¯ ط§ظ„طھظˆطµظٹظ„', value: 'out_for_delivery'),
  _StatusFilter(label: 'طھظ… ط§ظ„طھط³ظ„ظٹظ…', value: 'delivered'),
  _StatusFilter(label: 'ظ…ظ„ط؛ظٹ', value: 'canceled'),
  _StatusFilter(label: 'ظ…ط³طھط±ط¯', value: 'returned'),
];

const List<_StatusFilter> _manualPaymentStatusFilters = [
  _StatusFilter(label: 'ط§ظ„ظƒظ„', value: ''),
  _StatusFilter(label: 'ط¨ط§ظ†طھط¸ط§ط± ط§ظ„ظ…ط±ط§ط¬ط¹ط©', value: 'pending'),
  _StatusFilter(label: 'ظ‚ظٹط¯ ط§ظ„طھط­ظ‚ظ‚', value: 'under_review'),
  _StatusFilter(label: 'طھظ… ط§ظ„ظ‚ط¨ظˆظ„', value: 'approved'),
  _StatusFilter(label: 'ظ…ط±ظپظˆط¶', value: 'rejected'),
];

const Map<String, String> _orderStatusLabelMap = {
  'pending': 'ط¨ط§ظ†طھط¸ط§ط± ط§ظ„ط¯ظپط¹',
  'deposit_paid': 'ط¯ظپط¹ط© ظ…ظ‚ط¯ظ…ط©',
  'under_review': 'ظ‚ظٹط¯ ط§ظ„ظ…ط±ط§ط¬ط¹ط©',
  'confirmed': 'ظ…ط¤ظƒط¯',
  'processing': 'طھط­طھ ط§ظ„ظ…ط¹ط§ظ„ط¬ط©',
  'preparing': 'ط¬ط§ط± ط§ظ„طھط­ط¶ظٹط±',
  'ready_for_delivery': 'ط¬ط§ظ‡ط² ظ„ظ„طھط³ظ„ظٹظ…',
  'out_for_delivery': 'ظ‚ظٹط¯ ط§ظ„طھظˆطµظٹظ„',
  'delivered': 'طھظ… ط§ظ„طھط³ظ„ظٹظ…',
  'final_settlement': 'طھط³ظˆظٹط© ظ†ظ‡ط§ط¦ظٹط©',
  'failed': 'ظپط´ظ„',
  'canceled': 'ظ…ظ„ط؛ظٹ',
  'on_hold': 'ظ…ط¹ظ„ظ‚',
  'returned': 'ظ…ط³طھط±ط¯',
};

const Map<String, String> _paymentStatusLabelMap = {
  'pending': 'ط¨ط§ظ†طھط¸ط§ط± ط§ظ„ط¯ظپط¹',
  'awaiting_payment': 'ط¨ط§ظ†طھط¸ط§ط± ط§ظ„ط¯ظپط¹',
  'under_review': 'ظ‚ظٹط¯ ط§ظ„ظ…ط±ط§ط¬ط¹ط©',
  'paid': 'ظ…ط¯ظپظˆط¹',
  'confirmed': 'طھظ… ط§ظ„طھط£ظƒظٹط¯',
  'refunded': 'طھظ… ط§ظ„ط§ط³طھط±ط¯ط§ط¯',
  'failed': 'ظپط´ظ„',
  'canceled': 'ظ…ظ„ط؛ظٹ',
};

const Map<String, String> _manualPaymentStatusLabelMap = {
  'pending': 'ط¨ط§ظ†طھط¸ط§ط± ط§ظ„ظ…ط±ط§ط¬ط¹ط©',
  'under_review': 'ظ‚ظٹط¯ ط§ظ„طھط­ظ„ظٹظ„',
  'approved': 'ظ…ظ‚ط¨ظˆظ„',
  'rejected': 'ظ…ط±ظپظˆط¶',
};

String _orderStatusLabel(String? status) {
  if (status == null || status.isEmpty) {
    return 'ط؛ظٹط± ظ…ط­ط¯ط¯';
  }
  return _orderStatusLabelMap[status] ?? status;
}

String _paymentStatusLabel(String? status) {
  if (status == null || status.isEmpty) {
    return 'ط؛ظٹط± ظ…ط­ط¯ط¯';
  }
  return _paymentStatusLabelMap[status] ?? status;
}

String _manualPaymentStatusLabel(String? status) {
  if (status == null || status.isEmpty) {
    return 'ط؛ظٹط± ظ…ط­ط¯ط¯';
  }
  return _manualPaymentStatusLabelMap[status] ?? status;
}

String _formatCurrency(double amount, String currency) {
  final normalizedCurrency = currency.trim().isEmpty ? 'ط±.ظٹ' : currency;
  final decimals = amount % 1 == 0 ? 0 : 2;
  final formatter = NumberFormat.currency(
    locale: 'ar',
    symbol: normalizedCurrency,
    decimalDigits: decimals,
  );
  return formatter.format(amount);
}

String _formatDate(DateTime? dateTime) {
  if (dateTime == null) {
    return 'ط؛ظٹط± ظ…طھط§ط­';
  }
  return DateFormat('dd MMM yyyyطŒ hh:mm a', 'ar').format(dateTime.toLocal());
}

Color _statusColor(String? status, BuildContext context) {
  switch (status) {
    case 'pending':
    case 'deposit_paid':
    case 'under_review':
      return Colors.orange;
    case 'confirmed':
    case 'processing':
    case 'preparing':
    case 'ready_for_delivery':
    case 'out_for_delivery':
    case 'final_settlement':
      return context.color.territoryColor;
    case 'delivered':
      return Colors.green;
    case 'failed':
    case 'canceled':
    case 'returned':
      return Colors.redAccent;
    default:
      return context.color.secondaryColor;
  }
}

Color _paymentStatusColor(String? status, BuildContext context) {
  switch (status) {
    case 'paid':
    case 'confirmed':
      return Colors.green;
    case 'pending':
    case 'awaiting_payment':
    case 'under_review':
      return Colors.orange;
    case 'failed':
    case 'canceled':
      return Colors.redAccent;
    case 'refunded':
      return Colors.blueGrey;
    default:
      return context.color.secondaryColor;
  }
}

Color _manualPaymentStatusColor(String? status, BuildContext context) {
  switch (status) {
    case 'approved':
      return Colors.green;
    case 'rejected':
      return Colors.redAccent;
    case 'under_review':
    case 'pending':
      return Colors.orange;
    default:
      return context.color.secondaryColor;
  }
}

String? _detailValue(Map<String, dynamic> details, List<String> keys) {
  for (final key in keys) {
    final value = details[key];
    final normalized = _stringify(value);
    if (normalized != null) {
      return normalized;
    }
  }
  return null;
}

String? _stringify(dynamic value) {
  if (value == null) return null;
  if (value is num) {
    return value.toString();
  }
  if (value is Iterable) {
    final joined = value
        .map(_stringify)
        .whereType<String>()
        .where((element) => element.isNotEmpty)
        .join('طŒ ');
    return joined.isEmpty ? null : joined;
  }
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

