import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:marib/app/routes.dart';
import 'package:marib/data/cubits/notifications/notification_preferences_cubit.dart';
import 'package:marib/data/cubits/notifications/notification_topics_cubit.dart';
import 'package:marib/data/model/notification_preference.dart';
import 'package:marib/data/repositories/notifications_repository_repository.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/responsiveSize.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:marib/utils/helper_utils.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  static Route route(RouteSettings settings) {
    return BlurredRouter(
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => NotificationPreferencesCubit(
              NotificationsRepository(),
            )..load(),
          ),
          BlocProvider(
            create: (_) => NotificationTopicsCubit(
              NotificationsRepository(),
            )..fetchTopics(),
          ),
        ],
        child: const NotificationSettingsScreen(),
      ),
      settings: settings,
    );
  }

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  List<NotificationPreferenceModel> _workingPreferences =
      const <NotificationPreferenceModel>[];
  bool _dirty = false;
  String _topicInput = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: UiUtils.buildAppBar(
        context,
        title: "notification_settings".translate(context),
        showBackButton: true,
      ),
      backgroundColor: Theme.of(context).colorScheme.primaryColor,
      body: BlocConsumer<NotificationPreferencesCubit,
          NotificationPreferencesState>(
        listener: (context, state) {
          if (state is NotificationPreferencesLoaded && !state.saving) {
            setState(() {
              _workingPreferences = List<NotificationPreferenceModel>.from(
                state.preferences,
              );
              _dirty = false;
            });
          }
          if (state is NotificationPreferencesError) {
            HelperUtils.showSnackBarMessage(context, state.message);
          }
        },
        builder: (context, prefState) {
          if (prefState is NotificationPreferencesLoading) {
            return Center(
              child: UiUtils.progress(width: 48, height: 48),
            );
          }
          if (prefState is NotificationPreferencesError) {
            return Center(
              child: Text(
                prefState.message,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            );
          }
          if (prefState is NotificationPreferencesLoaded) {
            return SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(
                          "notification_preferences".translate(context),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        ..._buildPreferenceCards(prefState),
                        const SizedBox(height: 24),
                        _buildTopicsSection(context),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _dirty && !prefState.saving
                            ? () => _savePreferences(prefState)
                            : null,
                        child: prefState.saving
                            ? SizedBox(
                                height: 18,
                                width: 18,
                                child: UiUtils.progress(
                                  width: 18,
                                  height: 18,
                                ),
                              )
                            : Text("save".translate(context)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  List<Widget> _buildPreferenceCards(
    NotificationPreferencesLoaded state,
  ) {
    if (_workingPreferences.isEmpty) {
      return <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text("noDataFound".translate(context)),
        )
      ];
    }

    final List<Widget> cards = <Widget>[];
    for (int i = 0; i < _workingPreferences.length; i++) {
      final NotificationPreferenceModel pref = _workingPreferences[i];
      cards.add(
        Card(
          color: Theme.of(context).colorScheme.secondaryColor,
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pref.type.firstUpperCase(),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: Text("enabled".translate(context)),
                  value: pref.enabled,
                  onChanged: (value) => _updatePreference(
                    i,
                    pref.copyWith(enabled: value),
                  ),
                ),
                SwitchListTile(
                  title: Text("sound".translate(context)),
                  value: pref.sound,
                  onChanged: (value) => _updatePreference(
                    i,
                    pref.copyWith(sound: value),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: _buildDropdown(
                        label: "channel".translate(context),
                        value: pref.channel,
                        items: const ['push', 'email', 'inbox'],
                        onChanged: (value) => _updatePreference(
                          i,
                          pref.copyWith(channel: value ?? pref.channel),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDropdown(
                        label: "frequency".translate(context),
                        value: pref.frequency,
                        items: const ['instant', 'digest', 'daily', 'weekly'],
                        onChanged: (value) => _updatePreference(
                          i,
                          pref.copyWith(frequency: value ?? pref.frequency),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text("quiet_hours".translate(context)),
                  subtitle: Text(
                    pref.quietHours == null
                        ? "not_set".translate(context)
                        : "${pref.quietHours!.start} - ${pref.quietHours!.end} (${pref.quietHours!.timezone})",
                  ),
                  trailing: TextButton(
                    onPressed: () => _editQuietHours(i),
                    child: Text("edit".translate(context)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return cards;
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          isExpanded: true,
          onChanged: onChanged,
          items: items
              .map(
                (String item) => DropdownMenuItem<String>(
                  value: item,
                  child: Text(item.translate(context)),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildTopicsSection(BuildContext context) {
    return BlocConsumer<NotificationTopicsCubit, NotificationTopicsState>(
      listener: (context, state) {
        if (state is NotificationTopicsError) {
          HelperUtils.showSnackBarMessage(context, state.message);
        }
      },
      builder: (context, state) {
        final List<String> topics =
            state is NotificationTopicsLoaded ? state.topics : const [];
        final bool updating =
            state is NotificationTopicsLoaded ? state.updating : false;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "notification_topics".translate(context),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: topics.isEmpty
                  ? [
                      Text(
                        "no_topics".translate(context),
                        style: Theme.of(context).textTheme.bodySmall,
                      )
                    ]
                  : topics
                      .map(
                        (topic) => Chip(
                          label: Text(topic),
                          onDeleted: updating
                              ? null
                              : () => context
                                  .read<NotificationTopicsCubit>()
                                  .unsubscribe(topic),
                        ),
                      )
                      .toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                labelText: "topic_code".translate(context),
                hintText: "cur-USD / metal-gold",
              ),
              onChanged: (value) => setState(() {
                _topicInput = value.trim();
              }),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: updating || _topicInput.isEmpty
                        ? null
                        : () => context
                            .read<NotificationTopicsCubit>()
                            .subscribe(_topicInput.toLowerCase()),
                    child: Text("subscribe".translate(context)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: updating || _topicInput.isEmpty
                        ? null
                        : () => context
                            .read<NotificationTopicsCubit>()
                            .unsubscribe(_topicInput.toLowerCase()),
                    child: Text("unsubscribe".translate(context)),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _editQuietHours(int index) async {
    final NotificationPreferenceModel pref = _workingPreferences[index];
    final QuietHours initial = pref.quietHours ??
        QuietHours(
          start: '22:00',
          end: '07:00',
          timezone: DateTime.now().timeZoneName,
        );

    final QuietHours? result = await showDialog<QuietHours>(
      context: context,
      builder: (context) => _QuietHoursDialog(initial: initial),
    );

    if (result != null) {
      _updatePreference(index, pref.copyWith(quietHours: result));
    }
  }

  void _updatePreference(int index, NotificationPreferenceModel updated) {
    setState(() {
      _workingPreferences[index] = updated;
      _dirty = true;
    });
  }

  Future<void> _savePreferences(
    NotificationPreferencesLoaded state,
  ) async {
    await context
        .read<NotificationPreferencesCubit>()
        .update(_workingPreferences);
  }
}

class _QuietHoursDialog extends StatefulWidget {
  const _QuietHoursDialog({required this.initial});
  final QuietHours initial;

  @override
  State<_QuietHoursDialog> createState() => _QuietHoursDialogState();
}

class _QuietHoursDialogState extends State<_QuietHoursDialog> {
  late String _start = widget.initial.start;
  late String _end = widget.initial.end;
  late String _timezone = widget.initial.timezone;

  Future<void> _pickTime({
    required bool isStart,
  }) async {
    final List<String> parts = (isStart ? _start : _end).split(':');
    final TimeOfDay initialTime = TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (picked != null) {
      setState(() {
        final formatted =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
        if (isStart) {
          _start = formatted;
        } else {
          _end = formatted;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("quiet_hours".translate(context)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text("start".translate(context)),
            subtitle: Text(_start),
            onTap: () => _pickTime(isStart: true),
          ),
          ListTile(
            title: Text("end".translate(context)),
            subtitle: Text(_end),
            onTap: () => _pickTime(isStart: false),
          ),
          TextField(
            decoration: InputDecoration(
              labelText: "timezone".translate(context),
            ),
            controller: TextEditingController(text: _timezone),
            onChanged: (value) => _timezone = value,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("cancel".translate(context)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(
            context,
            QuietHours(start: _start, end: _end, timezone: _timezone),
          ),
          child: Text("save".translate(context)),
        ),
      ],
    );
  }
}
