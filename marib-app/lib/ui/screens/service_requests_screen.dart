import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:marib/data/cubits/service_requests_cubit.dart';
import 'package:marib/data/model/service_request_model.dart';

class ServiceRequestsScreen extends StatefulWidget {
  const ServiceRequestsScreen({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(
      builder: (_) => const ServiceRequestsScreen(),
    );
  }

  @override
  State<ServiceRequestsScreen> createState() => _ServiceRequestsScreenState();
}

class _ServiceRequestsScreenState extends State<ServiceRequestsScreen>
    with SingleTickerProviderStateMixin {
  late final ServiceRequestsCubit _cubit;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _cubit = ServiceRequestsCubit();
    _tabController = TabController(
      length: ServiceRequestFilter.values.length,
      vsync: this,
    );
    _tabController.addListener(_handleTabChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cubit.changeStatus(ServiceRequestFilter.review);
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _cubit.close();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      return;
    }
    final ServiceRequestFilter filter =
        ServiceRequestFilter.values[_tabController.index];
    _cubit.changeStatus(filter);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ServiceRequestsCubit>.value(
      value: _cubit,
      child: BlocListener<ServiceRequestsCubit, ServiceRequestsState>(
        listenWhen: (previous, current) =>
            previous.selectedStatus != current.selectedStatus,
        listener: (context, state) {
          final int index =
              ServiceRequestFilter.values.indexOf(state.selectedStatus);
          if (_tabController.index != index) {
            _tabController.animateTo(index);
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('طلبات الخدمات'),
            centerTitle: true,
          ),
          body: Column(
            children: [
              _ServiceRequestTabBar(controller: _tabController),
              const SizedBox(height: 8),
              BlocSelector<ServiceRequestsCubit, ServiceRequestsState, int>(
                selector: (state) =>
                    state.pages[state.selectedStatus]?.total ?? 0,
                builder: (context, total) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'إجمالي الطلبات: $total',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: ServiceRequestFilter.values
                      .map((filter) => _ServiceRequestTab(filter: filter))
                      .toList(growable: false),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceRequestTabBar extends StatelessWidget {
  const _ServiceRequestTabBar({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: controller,
        labelColor: Theme.of(context).colorScheme.primary,
        unselectedLabelColor: Theme.of(context).textTheme.bodyMedium?.color,
        indicator: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        tabs: ServiceRequestFilter.values.map((filter) {
          return Tab(text: _labelForFilter(filter));
        }).toList(growable: false),
      ),
    );
  }

  String _labelForFilter(ServiceRequestFilter filter) {
    return switch (filter) {
      ServiceRequestFilter.review => 'بانتظار المراجعة',
      ServiceRequestFilter.approved => 'مقبولة',
      ServiceRequestFilter.rejected => 'مرفوضة',
    };
  }
}

class _ServiceRequestTab extends StatelessWidget {
  const _ServiceRequestTab({required this.filter});

  final ServiceRequestFilter filter;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ServiceRequestsCubit, ServiceRequestsState,
        ServiceRequestPageState>(
      selector: (state) =>
          state.pages[filter] ?? ServiceRequestPageState.initial(),
      builder: (context, pageState) {
        if (pageState.isLoading && !pageState.hasLoaded) {
          return const Center(child: CircularProgressIndicator());
        }
        if (pageState.hasError && !pageState.hasLoaded) {
          return _EmptyState(
            message: 'تعذر تحميل الطلبات. حاول مرة أخرى.',
            actionLabel: 'إعادة المحاولة',
            onAction: () =>
                context.read<ServiceRequestsCubit>().changeStatus(filter),
          );
        }

        return NotificationListener<ScrollNotification>(
          onNotification: (notification) => _onScrollNotification(
            context,
            notification,
            pageState,
          ),
          child: RefreshIndicator(
            onRefresh: () =>
                context.read<ServiceRequestsCubit>().refresh(filter),
            child: _buildList(context, pageState),
          ),
        );
      },
    );
  }

  bool _onScrollNotification(
    BuildContext context,
    ScrollNotification notification,
    ServiceRequestPageState state,
  ) {
    if (notification.metrics.maxScrollExtent == 0) {
      return false;
    }

    final double threshold = notification.metrics.maxScrollExtent -
        notification.metrics.viewportDimension;
    if (notification.metrics.pixels >= threshold - 120 &&
        !state.isLoadingMore &&
        state.hasMore &&
        !state.loadMoreError) {
      context.read<ServiceRequestsCubit>().loadMore(filter);
    }
    return false;
  }

  Widget _buildList(BuildContext context, ServiceRequestPageState state) {
    if (!state.isLoading && state.requests.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          _EmptyState(message: 'لا توجد طلبات في هذه القائمة'),
        ],
      );
    }

    final bool showErrorBanner = state.hasError && state.requests.isNotEmpty;
    final bool showLoadMoreSection =
        state.hasMore || state.isLoadingMore || state.loadMoreError;
    final bool showCompletedBanner = !state.hasMore &&
        !state.isLoadingMore &&
        !state.loadMoreError &&
        state.requests.isNotEmpty;

    int itemCount = state.requests.length;
    if (showErrorBanner) {
      itemCount += 1;
    }
    if (showLoadMoreSection || showCompletedBanner) {
      itemCount += 1;
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        int currentIndex = index;

        if (showErrorBanner) {
          if (currentIndex == 0) {
            return _ErrorBanner(
              message: state.errorMessage ?? 'حدث خطأ أثناء تحديث البيانات.',
              onRetry: () =>
                  context.read<ServiceRequestsCubit>().changeStatus(filter),
            );
          }
          currentIndex -= 1;
        }

        if (currentIndex >= state.requests.length) {
          if (showLoadMoreSection) {
            if (state.isLoadingMore) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (state.loadMoreError) {
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: OutlinedButton.icon(
                  onPressed: () =>
                      context.read<ServiceRequestsCubit>().loadMore(filter),
                  icon: const Icon(Icons.refresh),
                  label: const Text('حاول مرة أخرى'),
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: ElevatedButton.icon(
                onPressed: () =>
                    context.read<ServiceRequestsCubit>().loadMore(filter),
                icon: const Icon(Icons.download),
                label: const Text('تحميل المزيد'),
              ),
            );
          }

          if (showCompletedBanner) {
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Center(
                child: Text(
                  'تم عرض جميع الطلبات',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            );
          }
        }

        final ServiceRequestModel request = state.requests[currentIndex];
        return _ServiceRequestTile(request: request);
      },
    );
  }
}

class _ServiceRequestTile extends StatelessWidget {
  const _ServiceRequestTile({required this.request});

  final ServiceRequestModel request;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DateFormat formatter = DateFormat('yyyy/MM/dd HH:mm');
    final String statusLabel = switch (request.status) {
      'approved' => 'مقبول',
      'rejected' => 'مرفوض',
      'review' => 'قيد المراجعة',
      _ => request.status,
    };
    final String? createdAt = request.createdAt != null
        ? formatter.format(request.createdAt!.toLocal())
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      request.serviceTitle ?? 'طلب #${request.id}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Chip(
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                    label: Text(
                      statusLabel,
                      style: TextStyle(color: theme.colorScheme.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'رقم الطلب: ${request.id}',
                style: theme.textTheme.bodyMedium,
              ),
              if (createdAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  'تاريخ الطلب: $createdAt',
                  style: theme.textTheme.bodySmall,
                ),
              ],
              if (request.note != null && request.note!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  request.note!,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onAction,
            child: Text(actionLabel!),
          ),
        ],
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Theme.of(context).colorScheme.error),
                ),
              ),
              TextButton(
                onPressed: onRetry,
                child: const Text('تحديث'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
