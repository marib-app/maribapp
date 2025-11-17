import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:marib/app/navigation/app_page_route.dart';
import 'package:marib/app/navigation/motion/route_motion.dart';
import 'package:marib/app/routes.dart';
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
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text('merchant_store_panel'.translate(context)),
          bottom: TabBar(
            tabs: [
              Tab(text: 'merchant_home'.translate(context)),
              Tab(text: 'merchant_requests'.translate(context)),
              Tab(text: 'merchant_remittances'.translate(context)),
              Tab(text: 'merchant_settings'.translate(context)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _MerchantOverviewTab(),
            _MerchantOrdersTab(),
            _MerchantManualPaymentsTab(),
            _MerchantSettingsTab(),
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
                payment.orderNumber ?? 'طلب #${payment.id}',
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
                color:
                    context.color.territoryColor.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'المبلغ المحول',
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
                          'البنك: ${payment.manualBankName}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              _DetailSection(
                title: 'تفاصيل الحوالة',
                rows: paymentDetails,
              ),
              _DetailSection(
                title: 'بيانات الحساب البنكي',
                rows: bankDetails,
              ),
              if (userNote != null && userNote.trim().isNotEmpty)
                _NoteCard(title: 'ملاحظة العميل', note: userNote.trim()),
              if (adminNote != null && adminNote.trim().isNotEmpty)
                _NoteCard(title: 'ملاحظة سابقة', note: adminNote.trim()),
              if (attachmentButtons.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'المرفقات',
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
                  'ملاحظة التاجر',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _noteController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: 'اكتب سبب الرفض أو أي ملاحظات إضافية',
                    border: OutlineInputBorder(),
                  ),
                ),
                SwitchListTile.adaptive(
                  value: _notifyCustomer,
                  onChanged: (value) => setState(() => _notifyCustomer = value),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('إشعار العميل بالتحديث'),
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
                        label: const Text('تأكيد الحوالة'),
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
                        label: const Text('رفض الحوالة'),
                      ),
                    ),
                  ],
                )
              else
                Center(
                  child: Text(
                    'تم اتخاذ قرار بخصوص هذه الحوالة.',
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

    add('رقم الطلب', payment.orderNumber);
    add('الرقم المرجعي', payment.reference);
    if (payment.createdAt != null) {
      add('وقت الطلب', _formatDate(payment.createdAt));
    }
    add('حالة الحوالة', _manualPaymentStatusLabel(payment.status));
    add('حالة الدفع', _paymentStatusLabel(payment.paymentStatus));
    final transfer = payment.transferDetails;
    if (transfer != null) {
      add(
          'المبلغ من التحويل',
          _detailValue(transfer, [
            'amount_formatted',
            'amount',
          ]));
      add('العملة', _detailValue(transfer, ['currency']));
      add('اسم المودع', _detailValue(transfer, ['sender_name', 'payer_name']));
      add(
          'رقم العملية',
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
      add('اسم البنك', bank.bankName ?? bank.name);
      add('اسم المستفيد', bank.beneficiaryName ?? bank.accountName);
      add('رقم الحساب', bank.accountNumber);
      add('رقم الآيبان', bank.iban);
      add('ملاحظات', bank.note);
    }

    final transfer = payment.transferDetails;
    if (transfer != null) {
      add(
          'البنك المرسل',
          _detailValue(transfer, [
            'bank_name',
            'manual_bank_name',
          ]));
      add(
          'رقم الحساب المحول منه',
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
          label: Text(attachment.name ?? 'مرفق'),
        ),
      );
    }

    final receiptUrl = payment.receiptUrl;
    if (buttons.isEmpty && receiptUrl != null && receiptUrl.trim().isNotEmpty) {
      buttons.add(
        OutlinedButton.icon(
          onPressed: () => _openUrl(receiptUrl),
          icon: const Icon(Icons.receipt_long_outlined),
          label: const Text('عرض إيصال التحويل'),
        ),
      );
    }

    return buttons;
  }

  Future<void> _openUrl(String? url) async {
    final trimmed = (url ?? '').trim();
    if (trimmed.isEmpty) {
      HelperUtils.showSnackBarMessage(context, 'الرابط غير متاح.');
      return;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null) {
      HelperUtils.showSnackBarMessage(context, 'الرابط غير صالح.');
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      HelperUtils.showSnackBarMessage(context, 'تعذر فتح الرابط.');
    }
  }

  Future<void> _submit(String decision) async {
    if (!_canDecide || _submitting) {
      return;
    }

    final note = _noteController.text.trim();

    if (decision == 'rejected' && note.isEmpty) {
      HelperUtils.showSnackBarMessage(context, 'يرجى كتابة سبب الرفض.');
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
        decision == 'approved' ? 'تم قبول الحوالة بنجاح.' : 'تم رفض الحوالة.',
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

class _MerchantSettingsTab extends StatelessWidget {
  const _MerchantSettingsTab();

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
          _SettingsCard(
            title: 'بيانات المتجر',
            actions: [
              TextButton(
                onPressed: () =>
                    _openOnboarding(context, source: 'store_info', step: 0),
                child: const Text('تحديث البيانات'),
              ),
            ],
            child: _StoreIdentitySection(
              store: summary.store,
              status: summary.status,
            ),
          ),
          const SizedBox(height: 16),
          _SettingsCard(
            title: 'ساعات العمل',
            actions: [
              TextButton(
                onPressed: () =>
                    _openOnboarding(context, source: 'working_hours', step: 1),
                child: const Text('تعديل الأوقات'),
              ),
            ],
            child: _WorkingHoursSection(hours: summary.workingHours),
          ),
          const SizedBox(height: 16),
          _SettingsCard(
            title: 'طرق الدفع والحد الأدنى',
            actions: [
              TextButton(
                onPressed: () =>
                    _openOnboarding(context, source: 'payments', step: 3),
                child: const Text('إدارة طرق الدفع'),
              ),
            ],
            child: _PaymentOptionsSection(status: summary.status),
          ),
          const SizedBox(height: 16),
          _SettingsCard(
            title: 'سياسات المتجر',
            actions: [
              TextButton(
                onPressed: () =>
                    _openOnboarding(context, source: 'policies', step: 2),
                child: const Text('تعديل السياسات'),
              ),
            ],
            child: _PoliciesSection(policies: summary.policies),
          ),
        ];

        return RefreshIndicator(
          color: context.color.territoryColor,
          onRefresh: () => context.read<MerchantDashboardCubit>().refresh(),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: cards.length,
            itemBuilder: (context, index) => cards[index],
          ),
        );
      },
    );
  }

  static void _openOnboarding(
    BuildContext context, {
    required String source,
    required int step,
  }) {
    Navigator.pushNamed(
      context,
      Routes.merchantOnboarding,
      arguments: {
        'resumeFromStep': step,
        'from': 'merchant_settings_$source',
      },
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    required this.child,
    this.actions,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final theme = context.color;
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: context.font.large,
                      fontWeight: FontWeight.w700,
                      color: theme.textColorDark,
                    ),
                  ),
                ),
                if (actions != null && actions!.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    children: actions!,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _StoreIdentitySection extends StatelessWidget {
  const _StoreIdentitySection({
    required this.store,
    required this.status,
  });

  final MerchantStoreInfo store;
  final MerchantStoreStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = context.color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundImage: store.logoUrl != null && store.logoUrl!.isNotEmpty
                  ? NetworkImage(store.logoUrl!)
                  : null,
              child: store.logoUrl == null || store.logoUrl!.isEmpty
                  ? const Icon(Icons.storefront_outlined)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    store.name.isNotEmpty ? store.name : 'متجر بدون اسم',
                    style: TextStyle(
                      fontSize: context.font.large,
                      fontWeight: FontWeight.bold,
                      color: theme.textColorDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'الحالة الحالية: ${_orderStatusLabel(store.status)}',
                    style: TextStyle(
                        color: theme.textColorDark.withValues(alpha: 0.75)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _KeyValueRow(
          label: 'رقم المتجر',
          value: store.id != 0 ? store.id.toString() : 'غير متاح',
        ),
        _KeyValueRow(label: 'المنطقة الزمنية', value: store.timezone ?? '-'),
        if (status.closureReason != null &&
            status.closureReason!.trim().isNotEmpty)
          _KeyValueRow(label: 'سبب الإغلاق', value: status.closureReason!),
      ],
    );
  }
}
 
class _WorkingHoursSection extends StatelessWidget {
  const _WorkingHoursSection({required this.hours});

  final List<MerchantWorkingHour> hours;

  static const List<String> _weekdayLabels = <String>[
    'الأحد',
    'الإثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
  ];

  @override
  Widget build(BuildContext context) {
    if (hours.isEmpty) {
      return const Text('لم يتم تعيين ساعات العمل بعد.');
    }

    return Column(
      children: hours.map((hour) {
        final String dayLabel = hour.weekday >= 0 && hour.weekday <= 6
            ? _weekdayLabels[hour.weekday]
            : 'اليوم ${hour.weekday}';
        final String value = hour.isOpen
            ? '${hour.opensAt ?? '--'} - ${hour.closesAt ?? '--'}'
            : 'مغلق';
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: _KeyValueRow(label: dayLabel, value: value),
        );
      }).toList(),
    );
  }
}

class _PaymentOptionsSection extends StatelessWidget {
  const _PaymentOptionsSection({required this.status});

  final MerchantStoreStatus status;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      _PaymentFlag(label: 'التوصيل', value: status.allowDelivery),
      _PaymentFlag(label: 'الاستلام', value: status.allowPickup),
      _PaymentFlag(label: 'حوالات يدوية', value: status.allowManualPayments),
      _PaymentFlag(label: 'المحفظة', value: status.allowWallet),
      _PaymentFlag(label: 'الدفع عند الاستلام', value: status.allowCod),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(spacing: 8, runSpacing: 8, children: chips),
        const SizedBox(height: 16),
        _KeyValueRow(
          label: 'الحد الأدنى للطلب',
          value: status.minOrderAmount != null
              ? NumberFormat.currency(symbol: 'ر.ي')
                  .format(status.minOrderAmount)
              : 'غير محدد',
        ),
      ],
    );
  }
}

class _PoliciesSection extends StatelessWidget {
  const _PoliciesSection({required this.policies});

  final List<MerchantPolicy> policies;

  @override
  Widget build(BuildContext context) {
    if (policies.isEmpty) {
      return const Text('لم تتم إضافة سياسات حتى الآن.');
    }

    return Column(
      children: policies
          .map(
            (policy) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    policy.title ?? 'سياسة بدون عنوان',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: context.color.textColorDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    (policy.content?.isNotEmpty == true)
                        ? policy.content!
                        : 'لا يوجد محتوى متاح.',
                    style: TextStyle(
                      color: context.color.textColorDark.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = context.color;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: theme.textColorDark,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: theme.textColorDark.withValues(alpha: 0.85),
            ),
          ),
        ),
      ],
    );
  }
}

class _PaymentFlag extends StatelessWidget {
  const _PaymentFlag({required this.label, required this.value});

  final String label;
  final bool value;

  @override
  Widget build(BuildContext context) {
    final Color color = value ? Colors.green : Colors.redAccent;
    final Color bg = color.withValues(alpha: 0.12);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(value ? Icons.check_circle : Icons.block, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color)),
        ],
      ),
    );
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
                          payment.orderNumber ?? 'طلب #${payment.id}',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          payment.manualBankName ?? 'حوالة بنكية',
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
                'المبلغ: $amountText',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                'التاريخ: $createdAt',
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
              'المجموع: $totalText',
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
                color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
                border: Border.all(color: color.withValues(alpha: 0.4)),
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

class _MetricsGrid extends StatefulWidget {
  const _MetricsGrid({required this.summary});

  final MerchantDashboardSummary summary;

  @override
  State<_MetricsGrid> createState() => _MetricsGridState();
}

class _MetricsGridState extends State<_MetricsGrid> {
  late final List<_MetricCardData> _periods;
  late _MetricCardData _selected;

  @override
  void initState() {
    super.initState();
    _periods = <_MetricCardData>[
      _MetricCardData(
        titleKey: 'merchant_today',
        snapshot: widget.summary.overview.today,
        color: context.color.territoryColor,
      ),
      _MetricCardData(
        titleKey: 'merchant_last_7_days',
        snapshot: widget.summary.overview.week,
        color: Colors.indigo,
      ),
      _MetricCardData(
        titleKey: 'merchant_last_30_days',
        snapshot: widget.summary.overview.month,
        color: Colors.teal,
      ),
    ];
    _selected = _periods.first;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'merchant_overview_stats'.translate(context),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _periods.map((period) {
              final bool isSelected = identical(period, _selected);
              return Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: ChoiceChip(
                  elevation: isSelected ? 1 : 0,
                  label: Text(period.titleKey.translate(context)),
                  selected: isSelected,
                  selectedColor: period.color.withValues(alpha: 0.15),
                  avatar: isSelected
                      ? Icon(Icons.check, size: 16, color: period.color)
                      : null,
                  onSelected: (_) => setState(() => _selected = period),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        _MetricSummaryCard(data: _selected),
      ],
    );
  }
}
class _MetricSummaryCard extends StatelessWidget {
  const _MetricSummaryCard({required this.data});

  final _MetricCardData data;

  @override
  Widget build(BuildContext context) {
    final snapshot = data.snapshot;
    final accent = data.color;
    final NumberFormat compact = NumberFormat.compact(locale: 'ar');
    final NumberFormat currency = NumberFormat.compactCurrency(
      locale: 'ar',
      symbol: 'ر.ي',
      decimalDigits: snapshot.revenue % 1 == 0 ? 0 : 2,
    );

    final stats = <_MetricStatTile>[
      _MetricStatTile(
        icon: Icons.shopping_bag_outlined,
        label: 'merchant_metric_orders'.translate(context),
        value: compact.format(snapshot.orders),
        color: Colors.indigo,
      ),
      _MetricStatTile(
        icon: Icons.visibility_outlined,
        label: 'merchant_metric_visits'.translate(context),
        value: compact.format(snapshot.visits),
        color: Colors.orange,
      ),
      _MetricStatTile(
        icon: Icons.remove_red_eye_outlined,
        label: 'merchant_metric_product_views'.translate(context),
        value: compact.format(snapshot.productViews),
        color: Colors.teal,
      ),
      _MetricStatTile(
        icon: Icons.add_shopping_cart_outlined,
        label: 'merchant_metric_add_to_cart'.translate(context),
        value: compact.format(snapshot.addToCart),
        color: Colors.pinkAccent,
      ),
    ];

    return Card(
      elevation: 0.6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data.titleKey.translate(context),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '${'merchant_metric_range'.translate(context)}: ${_formatRange(data.snapshot)}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            _RevenueHighlight(
              value: currency.format(snapshot.revenue),
              accent: accent,
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 520;
                final tileWidth =
                    isWide ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: stats
                      .map((tile) => SizedBox(width: tileWidth, child: tile))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatRange(MerchantMetricSnapshot snapshot) {
    final DateTime? start = DateTime.tryParse(snapshot.from);
    final DateTime? end = DateTime.tryParse(snapshot.to);
    if (start == null || end == null) {
      if (snapshot.from.isEmpty && snapshot.to.isEmpty) {
        return 'غير متاح';
      }
      return '${snapshot.from} - ${snapshot.to}';
    }
    final formatter = DateFormat('dd MMM', 'ar');
    return '${formatter.format(start.toLocal())} - ${formatter.format(end.toLocal())}';
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

class _RevenueHighlight extends StatelessWidget {
  const _RevenueHighlight({required this.value, required this.accent});

  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: accent.withValues(alpha: 0.15),
            foregroundColor: accent,
            child: const Icon(Icons.payments_outlined),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'merchant_metric_revenue'.translate(context),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700, color: accent),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricStatTile extends StatelessWidget {
  const _MetricStatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.1),
            foregroundColor: color,
            child: Icon(icon, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
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
                  status.isOpenNow ? 'المتجر مفتوح' : 'المتجر مغلق حالياً',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            if (!status.isOpenNow && status.nextOpenAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  'يفتح في: ${status.nextOpenAt}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const Divider(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _StatusBadge(
                  label: 'حالة النظام',
                  value: browseOnly ? 'تصفح فقط' : 'كامل',
                ),
                _StatusBadge(
                  label: 'حد الطلب',
                  value: status.minOrderAmount != null
                      ? NumberFormat.currency(symbol: 'ر.ي')
                          .format(status.minOrderAmount)
                      : 'غير محدد',
                ),
                _StatusBadge(
                  label: 'التوصيل',
                  value: status.allowDelivery ? 'مفعل' : 'موقوف',
                ),
                _StatusBadge(
                  label: 'الاستلام',
                  value: status.allowPickup ? 'مفعل' : 'موقوف',
                ),
                _StatusBadge(
                  label: 'حوالات يدوية',
                  value: status.allowManualPayments ? 'مسموح' : 'موقوف',
                ),
                _StatusBadge(
                  label: 'الدفع بالمحفظة',
                  value: status.allowWallet ? 'مسموح' : 'موقوف',
                ),
                _StatusBadge(
                  label: 'الدفع عند الاستلام',
                  value: status.allowCod ? 'مسموح' : 'موقوف',
                ),
              ],
            ),
            if (isClosed && status.closureReason != null) ...[
              const SizedBox(height: 12),
              Text(
                'سبب الإغلاق: ${status.closureReason}',
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
        color:
            context.color.secondaryColor.withValues(alpha: 0.15),
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
    'الأحد',
    'الإثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
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
              'ساعات العمل',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ...sortedHours.map((hour) {
              final label = weekdayLabels[hour.weekday.clamp(0, 6)];
              String range = 'مغلق';
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
              'السياسات',
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
              'بريد لوحة المتجر',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (staff == null)
              Text(
                'لم يتم حجز بريد بعد. يمكنك إنشاؤه من إعدادات المتجر.',
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
                    'الحالة: ${staff!.status}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            const SizedBox(height: 8),
            Text(
              'استخدم هذا البريد لتسجيل الدخول إلى لوحة التحكم المخصصة للمتجر ومتابعة الطلبات.',
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
              'تعذر تحميل بيانات المتجر',
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
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}

const List<_StatusFilter> _orderStatusFilters = [
  _StatusFilter(label: 'الكل', value: ''),
  _StatusFilter(label: 'بانتظار الدفع', value: 'pending'),
  _StatusFilter(label: 'دفعة مقدمة', value: 'deposit_paid'),
  _StatusFilter(label: 'قيد المراجعة', value: 'under_review'),
  _StatusFilter(label: 'مؤكد', value: 'confirmed'),
  _StatusFilter(label: 'جار التحضير', value: 'preparing'),
  _StatusFilter(label: 'جار المعالجة', value: 'processing'),
  _StatusFilter(label: 'جاهز للتسليم', value: 'ready_for_delivery'),
  _StatusFilter(label: 'قيد التوصيل', value: 'out_for_delivery'),
  _StatusFilter(label: 'تم التسليم', value: 'delivered'),
  _StatusFilter(label: 'تسوية نهائية', value: 'final_settlement'),
  _StatusFilter(label: 'ملغي', value: 'canceled'),
  _StatusFilter(label: 'مسترد', value: 'returned'),
];

const List<_StatusFilter> _manualPaymentStatusFilters = [
  _StatusFilter(label: 'الكل', value: ''),
  _StatusFilter(label: 'بانتظار المراجعة', value: 'pending'),
  _StatusFilter(label: 'قيد المراجعة', value: 'under_review'),
  _StatusFilter(label: 'تم القبول', value: 'approved'),
  _StatusFilter(label: 'مرفوض', value: 'rejected'),
];

const Map<String, String> _orderStatusLabelMap = {
  'pending': 'بانتظار الدفع',
  'deposit_paid': 'دفعة مقدمة',
  'under_review': 'قيد المراجعة',
  'confirmed': 'مؤكد',
  'processing': 'جار المعالجة',
  'preparing': 'جار التحضير',
  'ready_for_delivery': 'جاهز للتسليم',
  'out_for_delivery': 'قيد التوصيل',
  'delivered': 'تم التسليم',
  'final_settlement': 'تسوية نهائية',
  'failed': 'فشل',
  'canceled': 'ملغي',
  'on_hold': 'معلق',
  'returned': 'مسترد',
};

const Map<String, String> _paymentStatusLabelMap = {
  'pending': 'بانتظار الدفع',
  'awaiting_payment': 'بانتظار الدفع',
  'under_review': 'قيد المراجعة',
  'paid': 'مدفوع',
  'confirmed': 'تم التأكيد',
  'refunded': 'تم الاسترداد',
  'failed': 'فشل',
  'canceled': 'ملغي',
};

const Map<String, String> _manualPaymentStatusLabelMap = {
  'pending': 'بانتظار المراجعة',
  'under_review': 'قيد المراجعة',
  'approved': 'مقبول',
  'rejected': 'مرفوض',
};

String _orderStatusLabel(String? status) {
  if (status == null || status.isEmpty) {
    return 'غير محدد';
  }
  return _orderStatusLabelMap[status] ?? status;
}

String _paymentStatusLabel(String? status) {
  if (status == null || status.isEmpty) {
    return 'غير محدد';
  }
  return _paymentStatusLabelMap[status] ?? status;
}

String _manualPaymentStatusLabel(String? status) {
  if (status == null || status.isEmpty) {
    return 'غير محدد';
  }
  return _manualPaymentStatusLabelMap[status] ?? status;
}

String _formatCurrency(double amount, String currency) {
  final normalizedCurrency = currency.trim().isEmpty ? 'ر.ي' : currency;
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
    return 'غير متاح';
  }
  return DateFormat('dd MMM yyyy، hh:mm a', 'ar').format(dateTime.toLocal());
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
        .join('، ');
    return joined.isEmpty ? null : joined;
  }
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}


