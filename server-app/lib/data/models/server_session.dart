import 'package:freezed_annotation/freezed_annotation.dart';

part 'server_session.freezed.dart';
part 'server_session.g.dart';

@freezed
class ServerSession with _$ServerSession {
  const factory ServerSession({
    required String token,
    required AdminProfile admin,
  }) = _ServerSession;

  factory ServerSession.fromJson(Map<String, dynamic> json) => _$ServerSessionFromJson(json);
}

@freezed
class AdminProfile with _$AdminProfile {
  const factory AdminProfile({
    required int id,
    required String name,
    required String email,
    String? role,
    String? avatarUrl,
  }) = _AdminProfile;

  factory AdminProfile.fromJson(Map<String, dynamic> json) => _$AdminProfileFromJson(json);
}
