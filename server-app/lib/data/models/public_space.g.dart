// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'public_space.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PublicSpaceImpl _$$PublicSpaceImplFromJson(Map<String, dynamic> json) =>
    _$PublicSpaceImpl(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      city: json['city'] as String,
      type: json['type'] as String,
      status: $enumDecode(_$SpaceStatusEnumMap, json['status']),
      activeAccessPoints: (json['activeAccessPoints'] as num).toInt(),
      totalAccessPoints: (json['totalAccessPoints'] as num).toInt(),
      lastSyncAt: DateTime.parse(json['lastSyncAt'] as String),
      sensors:
          (json['sensors'] as List<dynamic>?)
              ?.map((e) => SpaceSensor.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <SpaceSensor>[],
    );

Map<String, dynamic> _$$PublicSpaceImplToJson(_$PublicSpaceImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'city': instance.city,
      'type': instance.type,
      'status': _$SpaceStatusEnumMap[instance.status]!,
      'activeAccessPoints': instance.activeAccessPoints,
      'totalAccessPoints': instance.totalAccessPoints,
      'lastSyncAt': instance.lastSyncAt.toIso8601String(),
      'sensors': instance.sensors,
    };

const _$SpaceStatusEnumMap = {
  SpaceStatus.online: 'online',
  SpaceStatus.offline: 'offline',
  SpaceStatus.maintenance: 'maintenance',
};

_$SpaceSensorImpl _$$SpaceSensorImplFromJson(Map<String, dynamic> json) =>
    _$SpaceSensorImpl(
      identifier: json['identifier'] as String,
      onlineClients: (json['onlineClients'] as num).toInt(),
      downloadMbps: (json['downloadMbps'] as num).toDouble(),
      uploadMbps: (json['uploadMbps'] as num).toDouble(),
    );

Map<String, dynamic> _$$SpaceSensorImplToJson(_$SpaceSensorImpl instance) =>
    <String, dynamic>{
      'identifier': instance.identifier,
      'onlineClients': instance.onlineClients,
      'downloadMbps': instance.downloadMbps,
      'uploadMbps': instance.uploadMbps,
    };
