// packages/locale_helper_shared/lib/src/project_list_item_dto.dart
import 'package:meta/meta.dart';

@immutable
class ProjectListItemDto {
  final String id;
  final String name;
  final String myRole;          // owner | reviewer | commenter
  final int unreviewedCount;    // count for the calling user
  final DateTime updatedAt;
  const ProjectListItemDto({
    required this.id,
    required this.name,
    required this.myRole,
    required this.unreviewedCount,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'myRole': myRole,
    'unreviewedCount': unreviewedCount,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  factory ProjectListItemDto.fromJson(Map<String, dynamic> json) => ProjectListItemDto(
    id: json['id'] as String,
    name: json['name'] as String,
    myRole: json['myRole'] as String,
    unreviewedCount: json['unreviewedCount'] as int,
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );
}
