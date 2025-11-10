// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ServerSessionImpl _$$ServerSessionImplFromJson(Map<String, dynamic> json) =>
    _$ServerSessionImpl(
      token: json['token'] as String,
      admin: AdminProfile.fromJson(json['admin'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$$ServerSessionImplToJson(_$ServerSessionImpl instance) =>
    <String, dynamic>{'token': instance.token, 'admin': instance.admin};

_$AdminProfileImpl _$$AdminProfileImplFromJson(Map<String, dynamic> json) =>
    _$AdminProfileImpl(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
    );

Map<String, dynamic> _$$AdminProfileImplToJson(_$AdminProfileImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'email': instance.email,
      'role': instance.role,
      'avatarUrl': instance.avatarUrl,
    };
