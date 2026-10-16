import '../config/app_config.dart';
import 'json_helpers.dart';

class Artist {
  const Artist({required this.id, required this.name, this.avatarUrl = ''});

  factory Artist.fromJson(JsonMap json) => Artist(
    id: json['id']?.toString() ?? '',
    name: asString(json['name']) ?? 'Unknown Artist',
    avatarUrl: asString(asMap(json['cover'])?['url']) ?? '',
  );

  final String id;
  final String name;
  final String avatarUrl;

  String get shareUrl => AppConfig.shareUrl('artist', id);
  String get deepLink => AppConfig.deepLink('artist', id);
}
