// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'server_session.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

ServerSession _$ServerSessionFromJson(Map<String, dynamic> json) {
  return _ServerSession.fromJson(json);
}

/// @nodoc
mixin _$ServerSession {
  String get token => throw _privateConstructorUsedError;
  AdminProfile get admin => throw _privateConstructorUsedError;

  /// Serializes this ServerSession to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ServerSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ServerSessionCopyWith<ServerSession> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ServerSessionCopyWith<$Res> {
  factory $ServerSessionCopyWith(
    ServerSession value,
    $Res Function(ServerSession) then,
  ) = _$ServerSessionCopyWithImpl<$Res, ServerSession>;
  @useResult
  $Res call({String token, AdminProfile admin});

  $AdminProfileCopyWith<$Res> get admin;
}

/// @nodoc
class _$ServerSessionCopyWithImpl<$Res, $Val extends ServerSession>
    implements $ServerSessionCopyWith<$Res> {
  _$ServerSessionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ServerSession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? token = null, Object? admin = null}) {
    return _then(
      _value.copyWith(
            token: null == token
                ? _value.token
                : token // ignore: cast_nullable_to_non_nullable
                      as String,
            admin: null == admin
                ? _value.admin
                : admin // ignore: cast_nullable_to_non_nullable
                      as AdminProfile,
          )
          as $Val,
    );
  }

  /// Create a copy of ServerSession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AdminProfileCopyWith<$Res> get admin {
    return $AdminProfileCopyWith<$Res>(_value.admin, (value) {
      return _then(_value.copyWith(admin: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$ServerSessionImplCopyWith<$Res>
    implements $ServerSessionCopyWith<$Res> {
  factory _$$ServerSessionImplCopyWith(
    _$ServerSessionImpl value,
    $Res Function(_$ServerSessionImpl) then,
  ) = __$$ServerSessionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String token, AdminProfile admin});

  @override
  $AdminProfileCopyWith<$Res> get admin;
}

/// @nodoc
class __$$ServerSessionImplCopyWithImpl<$Res>
    extends _$ServerSessionCopyWithImpl<$Res, _$ServerSessionImpl>
    implements _$$ServerSessionImplCopyWith<$Res> {
  __$$ServerSessionImplCopyWithImpl(
    _$ServerSessionImpl _value,
    $Res Function(_$ServerSessionImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ServerSession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? token = null, Object? admin = null}) {
    return _then(
      _$ServerSessionImpl(
        token: null == token
            ? _value.token
            : token // ignore: cast_nullable_to_non_nullable
                  as String,
        admin: null == admin
            ? _value.admin
            : admin // ignore: cast_nullable_to_non_nullable
                  as AdminProfile,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ServerSessionImpl implements _ServerSession {
  const _$ServerSessionImpl({required this.token, required this.admin});

  factory _$ServerSessionImpl.fromJson(Map<String, dynamic> json) =>
      _$$ServerSessionImplFromJson(json);

  @override
  final String token;
  @override
  final AdminProfile admin;

  @override
  String toString() {
    return 'ServerSession(token: $token, admin: $admin)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ServerSessionImpl &&
            (identical(other.token, token) || other.token == token) &&
            (identical(other.admin, admin) || other.admin == admin));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, token, admin);

  /// Create a copy of ServerSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ServerSessionImplCopyWith<_$ServerSessionImpl> get copyWith =>
      __$$ServerSessionImplCopyWithImpl<_$ServerSessionImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ServerSessionImplToJson(this);
  }
}

abstract class _ServerSession implements ServerSession {
  const factory _ServerSession({
    required final String token,
    required final AdminProfile admin,
  }) = _$ServerSessionImpl;

  factory _ServerSession.fromJson(Map<String, dynamic> json) =
      _$ServerSessionImpl.fromJson;

  @override
  String get token;
  @override
  AdminProfile get admin;

  /// Create a copy of ServerSession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ServerSessionImplCopyWith<_$ServerSessionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

AdminProfile _$AdminProfileFromJson(Map<String, dynamic> json) {
  return _AdminProfile.fromJson(json);
}

/// @nodoc
mixin _$AdminProfile {
  int get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get email => throw _privateConstructorUsedError;
  String? get role => throw _privateConstructorUsedError;
  String? get avatarUrl => throw _privateConstructorUsedError;

  /// Serializes this AdminProfile to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AdminProfile
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AdminProfileCopyWith<AdminProfile> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AdminProfileCopyWith<$Res> {
  factory $AdminProfileCopyWith(
    AdminProfile value,
    $Res Function(AdminProfile) then,
  ) = _$AdminProfileCopyWithImpl<$Res, AdminProfile>;
  @useResult
  $Res call({
    int id,
    String name,
    String email,
    String? role,
    String? avatarUrl,
  });
}

/// @nodoc
class _$AdminProfileCopyWithImpl<$Res, $Val extends AdminProfile>
    implements $AdminProfileCopyWith<$Res> {
  _$AdminProfileCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AdminProfile
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? email = null,
    Object? role = freezed,
    Object? avatarUrl = freezed,
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
            email: null == email
                ? _value.email
                : email // ignore: cast_nullable_to_non_nullable
                      as String,
            role: freezed == role
                ? _value.role
                : role // ignore: cast_nullable_to_non_nullable
                      as String?,
            avatarUrl: freezed == avatarUrl
                ? _value.avatarUrl
                : avatarUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AdminProfileImplCopyWith<$Res>
    implements $AdminProfileCopyWith<$Res> {
  factory _$$AdminProfileImplCopyWith(
    _$AdminProfileImpl value,
    $Res Function(_$AdminProfileImpl) then,
  ) = __$$AdminProfileImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int id,
    String name,
    String email,
    String? role,
    String? avatarUrl,
  });
}

/// @nodoc
class __$$AdminProfileImplCopyWithImpl<$Res>
    extends _$AdminProfileCopyWithImpl<$Res, _$AdminProfileImpl>
    implements _$$AdminProfileImplCopyWith<$Res> {
  __$$AdminProfileImplCopyWithImpl(
    _$AdminProfileImpl _value,
    $Res Function(_$AdminProfileImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AdminProfile
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? email = null,
    Object? role = freezed,
    Object? avatarUrl = freezed,
  }) {
    return _then(
      _$AdminProfileImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as int,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        email: null == email
            ? _value.email
            : email // ignore: cast_nullable_to_non_nullable
                  as String,
        role: freezed == role
            ? _value.role
            : role // ignore: cast_nullable_to_non_nullable
                  as String?,
        avatarUrl: freezed == avatarUrl
            ? _value.avatarUrl
            : avatarUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AdminProfileImpl implements _AdminProfile {
  const _$AdminProfileImpl({
    required this.id,
    required this.name,
    required this.email,
    this.role,
    this.avatarUrl,
  });

  factory _$AdminProfileImpl.fromJson(Map<String, dynamic> json) =>
      _$$AdminProfileImplFromJson(json);

  @override
  final int id;
  @override
  final String name;
  @override
  final String email;
  @override
  final String? role;
  @override
  final String? avatarUrl;

  @override
  String toString() {
    return 'AdminProfile(id: $id, name: $name, email: $email, role: $role, avatarUrl: $avatarUrl)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AdminProfileImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.avatarUrl, avatarUrl) ||
                other.avatarUrl == avatarUrl));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, name, email, role, avatarUrl);

  /// Create a copy of AdminProfile
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AdminProfileImplCopyWith<_$AdminProfileImpl> get copyWith =>
      __$$AdminProfileImplCopyWithImpl<_$AdminProfileImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AdminProfileImplToJson(this);
  }
}

abstract class _AdminProfile implements AdminProfile {
  const factory _AdminProfile({
    required final int id,
    required final String name,
    required final String email,
    final String? role,
    final String? avatarUrl,
  }) = _$AdminProfileImpl;

  factory _AdminProfile.fromJson(Map<String, dynamic> json) =
      _$AdminProfileImpl.fromJson;

  @override
  int get id;
  @override
  String get name;
  @override
  String get email;
  @override
  String? get role;
  @override
  String? get avatarUrl;

  /// Create a copy of AdminProfile
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AdminProfileImplCopyWith<_$AdminProfileImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
