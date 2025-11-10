// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'public_space.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

PublicSpace _$PublicSpaceFromJson(Map<String, dynamic> json) {
  return _PublicSpace.fromJson(json);
}

/// @nodoc
mixin _$PublicSpace {
  int get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get city => throw _privateConstructorUsedError;
  String get type => throw _privateConstructorUsedError;
  SpaceStatus get status => throw _privateConstructorUsedError;
  int get activeAccessPoints => throw _privateConstructorUsedError;
  int get totalAccessPoints => throw _privateConstructorUsedError;
  DateTime get lastSyncAt => throw _privateConstructorUsedError;
  List<SpaceSensor> get sensors => throw _privateConstructorUsedError;

  /// Serializes this PublicSpace to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PublicSpace
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PublicSpaceCopyWith<PublicSpace> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PublicSpaceCopyWith<$Res> {
  factory $PublicSpaceCopyWith(
    PublicSpace value,
    $Res Function(PublicSpace) then,
  ) = _$PublicSpaceCopyWithImpl<$Res, PublicSpace>;
  @useResult
  $Res call({
    int id,
    String name,
    String city,
    String type,
    SpaceStatus status,
    int activeAccessPoints,
    int totalAccessPoints,
    DateTime lastSyncAt,
    List<SpaceSensor> sensors,
  });
}

/// @nodoc
class _$PublicSpaceCopyWithImpl<$Res, $Val extends PublicSpace>
    implements $PublicSpaceCopyWith<$Res> {
  _$PublicSpaceCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PublicSpace
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? city = null,
    Object? type = null,
    Object? status = null,
    Object? activeAccessPoints = null,
    Object? totalAccessPoints = null,
    Object? lastSyncAt = null,
    Object? sensors = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as int,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            city: null == city
                ? _value.city
                : city // ignore: cast_nullable_to_non_nullable
                      as String,
            type: null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as String,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as SpaceStatus,
            activeAccessPoints: null == activeAccessPoints
                ? _value.activeAccessPoints
                : activeAccessPoints // ignore: cast_nullable_to_non_nullable
                      as int,
            totalAccessPoints: null == totalAccessPoints
                ? _value.totalAccessPoints
                : totalAccessPoints // ignore: cast_nullable_to_non_nullable
                      as int,
            lastSyncAt: null == lastSyncAt
                ? _value.lastSyncAt
                : lastSyncAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            sensors: null == sensors
                ? _value.sensors
                : sensors // ignore: cast_nullable_to_non_nullable
                      as List<SpaceSensor>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PublicSpaceImplCopyWith<$Res>
    implements $PublicSpaceCopyWith<$Res> {
  factory _$$PublicSpaceImplCopyWith(
    _$PublicSpaceImpl value,
    $Res Function(_$PublicSpaceImpl) then,
  ) = __$$PublicSpaceImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int id,
    String name,
    String city,
    String type,
    SpaceStatus status,
    int activeAccessPoints,
    int totalAccessPoints,
    DateTime lastSyncAt,
    List<SpaceSensor> sensors,
  });
}

/// @nodoc
class __$$PublicSpaceImplCopyWithImpl<$Res>
    extends _$PublicSpaceCopyWithImpl<$Res, _$PublicSpaceImpl>
    implements _$$PublicSpaceImplCopyWith<$Res> {
  __$$PublicSpaceImplCopyWithImpl(
    _$PublicSpaceImpl _value,
    $Res Function(_$PublicSpaceImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PublicSpace
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? city = null,
    Object? type = null,
    Object? status = null,
    Object? activeAccessPoints = null,
    Object? totalAccessPoints = null,
    Object? lastSyncAt = null,
    Object? sensors = null,
  }) {
    return _then(
      _$PublicSpaceImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as int,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        city: null == city
            ? _value.city
            : city // ignore: cast_nullable_to_non_nullable
                  as String,
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as String,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as SpaceStatus,
        activeAccessPoints: null == activeAccessPoints
            ? _value.activeAccessPoints
            : activeAccessPoints // ignore: cast_nullable_to_non_nullable
                  as int,
        totalAccessPoints: null == totalAccessPoints
            ? _value.totalAccessPoints
            : totalAccessPoints // ignore: cast_nullable_to_non_nullable
                  as int,
        lastSyncAt: null == lastSyncAt
            ? _value.lastSyncAt
            : lastSyncAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        sensors: null == sensors
            ? _value._sensors
            : sensors // ignore: cast_nullable_to_non_nullable
                  as List<SpaceSensor>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$PublicSpaceImpl implements _PublicSpace {
  const _$PublicSpaceImpl({
    required this.id,
    required this.name,
    required this.city,
    required this.type,
    required this.status,
    required this.activeAccessPoints,
    required this.totalAccessPoints,
    required this.lastSyncAt,
    final List<SpaceSensor> sensors = const <SpaceSensor>[],
  }) : _sensors = sensors;

  factory _$PublicSpaceImpl.fromJson(Map<String, dynamic> json) =>
      _$$PublicSpaceImplFromJson(json);

  @override
  final int id;
  @override
  final String name;
  @override
  final String city;
  @override
  final String type;
  @override
  final SpaceStatus status;
  @override
  final int activeAccessPoints;
  @override
  final int totalAccessPoints;
  @override
  final DateTime lastSyncAt;
  final List<SpaceSensor> _sensors;
  @override
  @JsonKey()
  List<SpaceSensor> get sensors {
    if (_sensors is EqualUnmodifiableListView) return _sensors;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_sensors);
  }

  @override
  String toString() {
    return 'PublicSpace(id: $id, name: $name, city: $city, type: $type, status: $status, activeAccessPoints: $activeAccessPoints, totalAccessPoints: $totalAccessPoints, lastSyncAt: $lastSyncAt, sensors: $sensors)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PublicSpaceImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.city, city) || other.city == city) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.activeAccessPoints, activeAccessPoints) ||
                other.activeAccessPoints == activeAccessPoints) &&
            (identical(other.totalAccessPoints, totalAccessPoints) ||
                other.totalAccessPoints == totalAccessPoints) &&
            (identical(other.lastSyncAt, lastSyncAt) ||
                other.lastSyncAt == lastSyncAt) &&
            const DeepCollectionEquality().equals(other._sensors, _sensors));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    city,
    type,
    status,
    activeAccessPoints,
    totalAccessPoints,
    lastSyncAt,
    const DeepCollectionEquality().hash(_sensors),
  );

  /// Create a copy of PublicSpace
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PublicSpaceImplCopyWith<_$PublicSpaceImpl> get copyWith =>
      __$$PublicSpaceImplCopyWithImpl<_$PublicSpaceImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PublicSpaceImplToJson(this);
  }
}

abstract class _PublicSpace implements PublicSpace {
  const factory _PublicSpace({
    required final int id,
    required final String name,
    required final String city,
    required final String type,
    required final SpaceStatus status,
    required final int activeAccessPoints,
    required final int totalAccessPoints,
    required final DateTime lastSyncAt,
    final List<SpaceSensor> sensors,
  }) = _$PublicSpaceImpl;

  factory _PublicSpace.fromJson(Map<String, dynamic> json) =
      _$PublicSpaceImpl.fromJson;

  @override
  int get id;
  @override
  String get name;
  @override
  String get city;
  @override
  String get type;
  @override
  SpaceStatus get status;
  @override
  int get activeAccessPoints;
  @override
  int get totalAccessPoints;
  @override
  DateTime get lastSyncAt;
  @override
  List<SpaceSensor> get sensors;

  /// Create a copy of PublicSpace
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PublicSpaceImplCopyWith<_$PublicSpaceImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SpaceSensor _$SpaceSensorFromJson(Map<String, dynamic> json) {
  return _SpaceSensor.fromJson(json);
}

/// @nodoc
mixin _$SpaceSensor {
  String get identifier => throw _privateConstructorUsedError;
  int get onlineClients => throw _privateConstructorUsedError;
  double get downloadMbps => throw _privateConstructorUsedError;
  double get uploadMbps => throw _privateConstructorUsedError;

  /// Serializes this SpaceSensor to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SpaceSensor
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SpaceSensorCopyWith<SpaceSensor> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SpaceSensorCopyWith<$Res> {
  factory $SpaceSensorCopyWith(
    SpaceSensor value,
    $Res Function(SpaceSensor) then,
  ) = _$SpaceSensorCopyWithImpl<$Res, SpaceSensor>;
  @useResult
  $Res call({
    String identifier,
    int onlineClients,
    double downloadMbps,
    double uploadMbps,
  });
}

/// @nodoc
class _$SpaceSensorCopyWithImpl<$Res, $Val extends SpaceSensor>
    implements $SpaceSensorCopyWith<$Res> {
  _$SpaceSensorCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SpaceSensor
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? identifier = null,
    Object? onlineClients = null,
    Object? downloadMbps = null,
    Object? uploadMbps = null,
  }) {
    return _then(
      _value.copyWith(
            identifier: null == identifier
                ? _value.identifier
                : identifier // ignore: cast_nullable_to_non_nullable
                      as String,
            onlineClients: null == onlineClients
                ? _value.onlineClients
                : onlineClients // ignore: cast_nullable_to_non_nullable
                      as int,
            downloadMbps: null == downloadMbps
                ? _value.downloadMbps
                : downloadMbps // ignore: cast_nullable_to_non_nullable
                      as double,
            uploadMbps: null == uploadMbps
                ? _value.uploadMbps
                : uploadMbps // ignore: cast_nullable_to_non_nullable
                      as double,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SpaceSensorImplCopyWith<$Res>
    implements $SpaceSensorCopyWith<$Res> {
  factory _$$SpaceSensorImplCopyWith(
    _$SpaceSensorImpl value,
    $Res Function(_$SpaceSensorImpl) then,
  ) = __$$SpaceSensorImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String identifier,
    int onlineClients,
    double downloadMbps,
    double uploadMbps,
  });
}

/// @nodoc
class __$$SpaceSensorImplCopyWithImpl<$Res>
    extends _$SpaceSensorCopyWithImpl<$Res, _$SpaceSensorImpl>
    implements _$$SpaceSensorImplCopyWith<$Res> {
  __$$SpaceSensorImplCopyWithImpl(
    _$SpaceSensorImpl _value,
    $Res Function(_$SpaceSensorImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SpaceSensor
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? identifier = null,
    Object? onlineClients = null,
    Object? downloadMbps = null,
    Object? uploadMbps = null,
  }) {
    return _then(
      _$SpaceSensorImpl(
        identifier: null == identifier
            ? _value.identifier
            : identifier // ignore: cast_nullable_to_non_nullable
                  as String,
        onlineClients: null == onlineClients
            ? _value.onlineClients
            : onlineClients // ignore: cast_nullable_to_non_nullable
                  as int,
        downloadMbps: null == downloadMbps
            ? _value.downloadMbps
            : downloadMbps // ignore: cast_nullable_to_non_nullable
                  as double,
        uploadMbps: null == uploadMbps
            ? _value.uploadMbps
            : uploadMbps // ignore: cast_nullable_to_non_nullable
                  as double,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SpaceSensorImpl implements _SpaceSensor {
  const _$SpaceSensorImpl({
    required this.identifier,
    required this.onlineClients,
    required this.downloadMbps,
    required this.uploadMbps,
  });

  factory _$SpaceSensorImpl.fromJson(Map<String, dynamic> json) =>
      _$$SpaceSensorImplFromJson(json);

  @override
  final String identifier;
  @override
  final int onlineClients;
  @override
  final double downloadMbps;
  @override
  final double uploadMbps;

  @override
  String toString() {
    return 'SpaceSensor(identifier: $identifier, onlineClients: $onlineClients, downloadMbps: $downloadMbps, uploadMbps: $uploadMbps)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SpaceSensorImpl &&
            (identical(other.identifier, identifier) ||
                other.identifier == identifier) &&
            (identical(other.onlineClients, onlineClients) ||
                other.onlineClients == onlineClients) &&
            (identical(other.downloadMbps, downloadMbps) ||
                other.downloadMbps == downloadMbps) &&
            (identical(other.uploadMbps, uploadMbps) ||
                other.uploadMbps == uploadMbps));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    identifier,
    onlineClients,
    downloadMbps,
    uploadMbps,
  );

  /// Create a copy of SpaceSensor
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SpaceSensorImplCopyWith<_$SpaceSensorImpl> get copyWith =>
      __$$SpaceSensorImplCopyWithImpl<_$SpaceSensorImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SpaceSensorImplToJson(this);
  }
}

abstract class _SpaceSensor implements SpaceSensor {
  const factory _SpaceSensor({
    required final String identifier,
    required final int onlineClients,
    required final double downloadMbps,
    required final double uploadMbps,
  }) = _$SpaceSensorImpl;

  factory _SpaceSensor.fromJson(Map<String, dynamic> json) =
      _$SpaceSensorImpl.fromJson;

  @override
  String get identifier;
  @override
  int get onlineClients;
  @override
  double get downloadMbps;
  @override
  double get uploadMbps;

  /// Create a copy of SpaceSensor
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SpaceSensorImplCopyWith<_$SpaceSensorImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
