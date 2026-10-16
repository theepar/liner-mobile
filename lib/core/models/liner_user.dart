import 'json_helpers.dart';

class LinerUser {
  const LinerUser({
    required this.id,
    this.email,
    this.username,
    this.displayName,
    this.avatarUrl,
  });

  factory LinerUser.fromJson(JsonMap json) => LinerUser(
    id: json['id']?.toString() ?? '',
    email: asString(json['email']),
    username: asString(json['username']),
    displayName: asString(json['displayName']),
    avatarUrl: asString(json['avatarUrl']),
  );

  final String id;
  final String? email;
  final String? username;
  final String? displayName;
  final String? avatarUrl;

  String get name {
    final display = displayName;
    if (display != null && display.isNotEmpty) return display;
    final handle = username;
    if (handle != null && handle.isNotEmpty) return handle;
    return email ?? 'Liner user';
  }

  @override
  bool operator ==(Object other) =>
      other is LinerUser &&
      other.id == id &&
      other.email == email &&
      other.username == username &&
      other.displayName == displayName &&
      other.avatarUrl == avatarUrl;

  @override
  int get hashCode => Object.hash(id, email, username, displayName, avatarUrl);

  JsonMap toJson() => {
    'id': id,
    'email': email,
    'username': username,
    'displayName': displayName,
    'avatarUrl': avatarUrl,
  };
}
