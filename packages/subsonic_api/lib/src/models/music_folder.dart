import 'model_helpers.dart';

class MusicFolder {
  const MusicFolder({required this.id, required this.name});

  factory MusicFolder.fromJson(Map<String, dynamic> json) {
    return MusicFolder(
      id: asInt(json['id']) ?? 0,
      name: asString(json['name']) ?? '',
    );
  }

  final int id;
  final String name;
}
