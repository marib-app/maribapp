import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/models/public_space.dart';
import '../controllers/places_controller.dart';
import '../widgets/place_card.dart';

class PlaceDetailsScreen extends ConsumerWidget {
  const PlaceDetailsScreen({super.key, required this.spaceId});

  final int spaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacesState = ref.watch(placesControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Space details'),
      ),
      body: spacesState.when(
        data: (spaces) {
          if (spaces.isEmpty) {
            return const Center(child: Text('No spaces available'));
          }
          final space = spaces.firstWhere(
            (element) => element.id == spaceId,
            orElse: () => spaces.first,
          );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              PlaceCard(space: space),
              const SizedBox(height: 16),
              _SensorsTable(space: space),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
      ),
    );
  }
}

class _SensorsTable extends StatelessWidget {
  const _SensorsTable({required this.space});

  final PublicSpace space;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('HH:mm');
    if (space.sensors.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            title: const Text('Sensors overview'),
            subtitle: Text('Updated ${formatter.format(space.lastSyncAt)}'),
          ),
          DataTable(
            columns: const [
              DataColumn(label: Text('Sensor')),
              DataColumn(label: Text('Clients')),
              DataColumn(label: Text('Down Mbps')),
              DataColumn(label: Text('Up Mbps')),
            ],
            rows: [
              for (final sensor in space.sensors)
                DataRow(
                  cells: [
                    DataCell(Text(sensor.identifier)),
                    DataCell(Text(sensor.onlineClients.toString())),
                    DataCell(Text(sensor.downloadMbps.toStringAsFixed(1))),
                    DataCell(Text(sensor.uploadMbps.toStringAsFixed(1))),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
