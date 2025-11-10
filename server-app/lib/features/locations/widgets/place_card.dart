import 'package:flutter/material.dart';

import '../../../data/models/public_space.dart';

class PlaceCard extends StatelessWidget {
  const PlaceCard({
    super.key,
    required this.space,
    this.onTap,
    this.onToggle,
  });

  final PublicSpace space;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onToggle;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          space.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${space.city} - ${space.type}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: space.status == SpaceStatus.online,
                    onChanged: space.status == SpaceStatus.maintenance
                        ? null
                        : onToggle,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatusChip(status: space.status),
                  _MetricChip(
                    label: 'Access points',
                    value:
                        '${space.activeAccessPoints}/${space.totalAccessPoints}',
                    icon: Icons.router,
                  ),
                  _MetricChip(
                    label: 'Last sync',
                    value:
                        '${space.lastSyncAt.hour.toString().padLeft(2, '0')}:${space.lastSyncAt.minute.toString().padLeft(2, '0')}',
                    icon: Icons.schedule,
                  ),
                ],
              ),
              if (space.sensors.isNotEmpty) ...[
                const Divider(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: space.sensors
                      .take(3)
                      .map(
                        (sensor) => _SensorTile(
                          name: sensor.identifier,
                          download: sensor.downloadMbps,
                          upload: sensor.uploadMbps,
                          clients: sensor.onlineClients,
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final SpaceStatus status;

  @override
  Widget build(BuildContext context) {
    Color background;
    Color foreground;
    String label;

    switch (status) {
      case SpaceStatus.online:
        background = Colors.green.shade50;
        foreground = Colors.green.shade800;
        label = 'Online';
        break;
      case SpaceStatus.offline:
        background = Colors.red.shade50;
        foreground = Colors.red.shade800;
        label = 'Offline';
        break;
      case SpaceStatus.maintenance:
        background = Colors.orange.shade50;
        foreground = Colors.orange.shade800;
        label = 'Maintenance';
        break;
    }

    return Chip(
      label: Text(label),
      avatar: Icon(
        status == SpaceStatus.online
            ? Icons.wifi_tethering
            : status == SpaceStatus.offline
                ? Icons.portable_wifi_off
                : Icons.build_circle_outlined,
        color: foreground,
        size: 18,
      ),
      backgroundColor: background,
      labelStyle: TextStyle(color: foreground),
      shape: StadiumBorder(
        side: BorderSide(color: foreground.withValues(alpha: 0.2)),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }
}

class _SensorTile extends StatelessWidget {
  const _SensorTile({
    required this.name,
    required this.download,
    required this.upload,
    required this.clients,
  });

  final String name;
  final double download;
  final double upload;
  final int clients;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Text('Down: ${download.toStringAsFixed(1)} Mbps'),
          Text('Up: ${upload.toStringAsFixed(1)} Mbps'),
          Text('Clients: $clients'),
        ],
      ),
    );
  }
}
