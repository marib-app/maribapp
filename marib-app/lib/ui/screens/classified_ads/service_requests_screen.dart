import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:marib/data/cubits/service_requests_cubit.dart';
import 'package:marib/data/model/service_request_model.dart';









class ServiceRequestsScreen extends StatefulWidget {
  final Map<String, dynamic>? pending;
  final int? categoryId;

  const ServiceRequestsScreen({super.key, this.pending, this.categoryId});

  /// arguments: { pendingRequest?: Map }
  static Route route(RouteSettings settings) {
    final args = (settings.arguments is Map) ? settings.arguments as Map : const {};
    final Map<String, dynamic>? p = args['pendingRequest'] is Map
        ? (args['pendingRequest'] as Map).cast<String, dynamic>()
        : null;
    final int? categoryId = args['categoryId'] is int
        ? args['categoryId'] as int
        : int.tryParse('${args['categoryId'] ?? ''}');
    return BlurredRouter(
      builder: (_) => BlocProvider(
        create: (_) => ServiceRequestsCubit()
          ..fetchRequests(categoryId: categoryId),
        child: ServiceRequestsScreen(
          pending: p,
          categoryId: categoryId,
        ),
      ),      settings: settings,
    );
  }

  @override
  State<ServiceRequestsScreen> createState() => _ServiceRequestsScreenState();
}

class _ServiceRequestsScreenState extends State<ServiceRequestsScreen> {
  bool _pendingInjected = false;


  @override
  void initState() {
    super.initState();

  }

  Future<void> _refresh() async {
    await context.read<ServiceRequestsCubit>().refresh();

  }

  String _fmt(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          leading: const BackButton(),
          title: const Text('طلبات خدماتي'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'قيد المراجعة'),
              Tab(text: 'مقبولة'),
              Tab(text: 'مرفوضة'),
            ],
          ),
        ),
        body: BlocListener<ServiceRequestsCubit, ServiceRequestsState>(
          listenWhen: (_, current) => current is ServiceRequestsLoadSuccess,
          listener: (context, state) {
            if (!_pendingInjected && widget.pending != null &&
                state is ServiceRequestsLoadSuccess) {
              context.read<ServiceRequestsCubit>().addOrUpdateFromMap(widget.pending!);
              _pendingInjected = true;
            }
          },
          child: BlocBuilder<ServiceRequestsCubit, ServiceRequestsState>(
            builder: (context, state) {
              if (state is ServiceRequestsLoadFailure) {
                return _ErrorView(
                  error: '${state.error}',
                  onRetry: () =>
                      context.read<ServiceRequestsCubit>().fetchRequests(
                        categoryId: widget.categoryId,
                      ),
                );
              }

              final bool loading = state is ServiceRequestsLoadInProgress ||
                  state is ServiceRequestsInitial;
              final review = state is ServiceRequestsLoadSuccess
                  ? state.review
                  : <ServiceRequestModel>[];
              final approved = state is ServiceRequestsLoadSuccess
                  ? state.approved
                  : <ServiceRequestModel>[];
              final rejected = state is ServiceRequestsLoadSuccess
                  ? state.rejected
                  : <ServiceRequestModel>[];

              return Column(
                children: [
                  if (widget.pending != null)
                    _PendingBanner(pending: widget.pending!),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _refresh,
                      child: TabBarView(
                        children: [
                          _RequestsList(
                            items: review,
                            emptyText: 'لا توجد طلبات قيد المراجعة',
                            loading: loading && review.isEmpty,
                            onTap: _showDetails,
                            fmt: _fmt,
                          ),
                          _RequestsList(
                            items: approved,
                            emptyText: 'لا توجد طلبات مقبولة',
                            loading: loading && approved.isEmpty,
                            onTap: _showDetails,
                            fmt: _fmt,
                          ),
                          _RequestsList(
                            items: rejected,
                            emptyText: 'لا توجد طلبات مرفوضة',
                            loading: loading && rejected.isEmpty,
                            onTap: _showDetails,
                            fmt: _fmt,
                          ),
                        ],
                      ),

                    ),
            ),
            ],
            );
          },
          ),
        ),
      ),
    );
  }







  void _showDetails(ServiceRequestModel vm) {
    dynamic customFields;
    final customFieldsJson = vm.customFieldsJson();
    if (customFieldsJson != null && customFieldsJson.isNotEmpty) {
      try {
        customFields = jsonDecode(customFieldsJson);
      } catch (_) {
        customFields = customFieldsJson;
      }
    }


    final jsonPretty = const JsonEncoder.withIndent('  ').convert({
      'id': vm.id,
      'title': vm.serviceTitle ?? 'خدمة',
      'status': vm.status,
      'submittedAt': vm.submittedAt?.toIso8601String(),
      if (vm.amount != null) 'amount': vm.amount,
      if (vm.currency?.isNotEmpty == true) 'currency': vm.currency,
      if (customFields != null) 'custom_fields': customFields,

    });

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(vm.serviceTitle ?? 'خدمة',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),


                const SizedBox(height: 6),
                Row(
                  children: [
                    _StatusChip(status: vm.status),
                    const SizedBox(width: 8),
                    Text(vm.submittedAt != null
                        ? _fmt(vm.submittedAt!)
                        : '—'),

                  ],
                ),
                if ((vm.amount ?? 0) > 0) ...[
                  const SizedBox(height: 8),
                  Text('المبلغ: ${vm.amount} ${vm.currency ?? ''}'),
                ],
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                const Text('البيانات (مؤقتًا):', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    jsonPretty,
                    textDirection: TextDirection.ltr,
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إغلاق'),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/* ============================ Widgets & VM ============================ */

class _RequestsList extends StatelessWidget {
  final List<ServiceRequestModel> items;
  final String emptyText;
  final bool loading;
  final void Function(ServiceRequestModel) onTap;
  final String Function(DateTime) fmt;

  const _RequestsList({
    required this.items,
    required this.emptyText,
    required this.loading,
    required this.onTap,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (items.isEmpty) {
      return Center(child: Text(emptyText));
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final e = items[i];
        return InkWell(
          onTap: () => onTap(e),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _TitleSubtitle(
                    title: e.serviceTitle ?? 'خدمة',
                    subtitle: e.submittedAt != null ? fmt(e.submittedAt!) : '—',
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _StatusChip(status: e.status),
                    if ((e.amount ?? 0) > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('${e.amount} ${e.currency ?? ''}'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}




class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              error,
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





class _TitleSubtitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _TitleSubtitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final fs = Theme.of(context).textTheme.bodyMedium?.fontSize ?? 14.0;
    return DefaultTextStyle(
      style: TextStyle(fontSize: fs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(subtitle),
        ],
      ),
    );
  }
}

class _PendingBanner extends StatelessWidget {
  final Map<String, dynamic> pending;

  const _PendingBanner({required this.pending});

  @override
  Widget build(BuildContext context) {
    final title = (pending['serviceTitle'] ?? 'خدمة').toString();
    final amount = pending['amount'];
    final currency = pending['currency'];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(.06),
        border: Border.all(color: Colors.green.withOpacity(.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'تم إرسال طلبك لـ "$title". ستظهر حالته هنا.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (amount != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text('${amount} ${currency ?? ''}'),
            ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status; // review | approved | rejected

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color c;
    String t;
    switch (status) {
      case 'approved':
        c = Colors.green;
        t = 'مقبولة';
        break;
      case 'rejected':
        c = Colors.red;
        t = 'مرفوضة';
        break;
      default:
        c = Colors.amber;
        t = 'قيد المراجعة';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(.12),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: c.withOpacity(.5)),
      ),
      child: Text(t, style: TextStyle(color: c, fontWeight: FontWeight.w600)),
    );
  }
}


