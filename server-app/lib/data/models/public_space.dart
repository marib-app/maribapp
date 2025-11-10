import 'package:freezed_annotation/freezed_annotation.dart';

part 'public_space.freezed.dart';
part 'public_space.g.dart';

enum SpaceStatus { online, offline, maintenance }

@freezed
class PublicSpace with _$PublicSpace {
  const factory PublicSpace({
    required int id,
    required String name,
    required String city,
    required String type,
    required SpaceStatus status,
    required int activeAccessPoints,
    required int totalAccessPoints,
    required DateTime lastSyncAt,
    @Default(<SpaceSensor>[]) List<SpaceSensor> sensors,
  }) = _PublicSpace;

  factory PublicSpace.fromJson(Map<String, dynamic> json) => _$PublicSpaceFromJson(json);
}

@freezed
class SpaceSensor with _$SpaceSensor {
  const factory SpaceSensor({
    required String identifier,
    required int onlineClients,
    required double downloadMbps,
    required double uploadMbps,
  }) = _SpaceSensor;

  factory SpaceSensor.fromJson(Map<String, dynamic> json) => _$SpaceSensorFromJson(json);
}
