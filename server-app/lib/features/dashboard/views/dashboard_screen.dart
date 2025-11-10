import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/async_value_widget.dart';
import '../../../data/models/public_space.dart';
import '../../../data/models/server_session.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../locations/controllers/places_controller.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final session = authState.valueOrNull;
    final placesState = ref.watch(placesControllerProvider);

    Future<void> refresh() =>
        ref.read(placesControllerProvider.notifier).refresh();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Server control'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: authState.isLoading
                ? null
                : () => ref.read(authControllerProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/dashboard/spaces'),
        icon: const Icon(Icons.map_outlined),
        label: const Text('Manage public areas'),
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (session != null) _AdminHeader(profile: session.admin),
            const SizedBox(height: 16),
            AsyncValueWidget<List<PublicSpace>>(
              value: placesState,
              data: (spaces) => _SpacesOverview(spaces: spaces),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminHeader extends StatelessWidget {
  const _AdminHeader({required this.profile});

  final AdminProfile profile;

  @override
  Widget build(BuildContext context) {
    final parts =
        profile.name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final initials = parts.isNotEmpty
        ? parts.take(2).map((part) => part[0]).join().toUpperCase()
        : 'AD';

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
          child: Text(initials),
        ),
        title: Text(profile.name),
        subtitle: Text(profile.email),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Role'),
            Text(profile.role ?? 'Admin'),
          ],
        ),
      ),
    );
  }
}

class _SpacesOverview extends StatelessWidget {
  const _SpacesOverview({required this.spaces});

  final List<PublicSpace> spaces;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd MMM, HH:mm');
    final online = spaces.where((space) => space.status == SpaceStatus.online).length;
    final offline = spaces.where((space) => space.status == SpaceStatus.offline).length;
    final maintenance =
        spaces.where((space) => space.status == SpaceStatus.maintenance).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _MetricCard(
              title: 'Total',
              value: spaces.length.toString(),
              icon: Icons.apartment,
            ),
            _MetricCard(
              title: 'Online',
              value: online.toString(),
              chipColor: Colors.green.shade600,
              icon: Icons.wifi_tethering,
            ),
            _MetricCard(
              title: 'Offline',
              value: offline.toString(),
              chipColor: Colors.red.shade400,
              icon: Icons.portable_wifi_off,
            ),
            _MetricCard(
              title: 'Maintenance',
              value: maintenance.toString(),
              chipColor: Colors.orange.shade400,
              icon: Icons.build_circle_outlined,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ListTile(
                title: Text('Recently updated areas'),
                subtitle: Text('Shortcuts to the most used actions'),
              ),
              for (final space in spaces.take(5))
                ListTile(
                  leading: Icon(_iconForStatus(space.status)),
                  title: Text(space.name),
                  subtitle: Text('${space.city} - Last sync ${formatter.format(space.lastSyncAt)}'),
                  trailing: Text(
                    '${space.activeAccessPoints}/${space.totalAccessPoints}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static IconData _iconForStatus(SpaceStatus status) {
    switch (status) {
      case SpaceStatus.online:
        return Icons.wifi_tethering;
      case SpaceStatus.offline:
        return Icons.portable_wifi_off;
      case SpaceStatus.maintenance:
        return Icons.build_circle;
    }
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    this.chipColor,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color? chipColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: chipColor ?? Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text(title, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
