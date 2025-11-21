class QuietHours {
  final String start;
  final String end;
  final String timezone;

  const QuietHours({
    required this.start,
    required this.end,
    required this.timezone,
  });

  factory QuietHours.fromJson(Map<String, dynamic> json) {
    return QuietHours(
      start: json['start']?.toString() ?? '00:00',
      end: json['end']?.toString() ?? '00:00',
      timezone: json['tz']?.toString() ?? json['timezone']?.toString() ?? 'UTC',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'start': start,
      'end': end,
      'tz': timezone,
    };
  }
}

class NotificationPreferenceModel {
  final String type;
  final bool enabled;
  final bool sound;
  final String channel;
  final String frequency;
  final QuietHours? quietHours;

  const NotificationPreferenceModel({
    required this.type,
    required this.enabled,
    required this.sound,
    required this.channel,
    required this.frequency,
    this.quietHours,
  });

  factory NotificationPreferenceModel.fromJson(Map<String, dynamic> json) {
    return NotificationPreferenceModel(
      type: json['type']?.toString() ?? 'default',
      enabled: json['enabled'] is bool
          ? json['enabled'] as bool
          : json['enabled'] == 1,
      sound: json['sound'] is bool ? json['sound'] as bool : json['sound'] == 1,
      channel: json['channel']?.toString() ?? 'push',
      frequency: json['frequency']?.toString() ?? 'instant',
      quietHours: json['quiet_hours'] is Map<String, dynamic>
          ? QuietHours.fromJson(Map<String, dynamic>.from(json['quiet_hours']))
          : null,
    );
  }

  NotificationPreferenceModel copyWith({
    bool? enabled,
    bool? sound,
    String? channel,
    String? frequency,
    QuietHours? quietHours,
  }) {
    return NotificationPreferenceModel(
      type: type,
      enabled: enabled ?? this.enabled,
      sound: sound ?? this.sound,
      channel: channel ?? this.channel,
      frequency: frequency ?? this.frequency,
      quietHours: quietHours ?? this.quietHours,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type,
      'enabled': enabled,
      'sound': sound,
      'channel': channel,
      'frequency': frequency,
      if (quietHours != null) 'quiet_hours': quietHours!.toJson(),
    };
  }
}
