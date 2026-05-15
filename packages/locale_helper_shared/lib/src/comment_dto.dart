// packages/locale_helper_shared/lib/src/comment_dto.dart
import 'package:meta/meta.dart';

@immutable
class CommentDto {
  final String id;
  final String stringKey;
  final String? userId;       // null if user was deleted
  final String? displayName;
  final String body;
  final DateTime createdAt;
  const CommentDto({
    required this.id,
    required this.stringKey,
    required this.userId,
    required this.displayName,
    required this.body,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'stringKey': stringKey,
    if (userId != null) 'userId': userId,
    if (displayName != null) 'displayName': displayName,
    'body': body,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  factory CommentDto.fromJson(Map<String, dynamic> json) => CommentDto(
    id: json['id'] as String,
    stringKey: json['stringKey'] as String,
    userId: json['userId'] as String?,
    displayName: json['displayName'] as String?,
    body: json['body'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}
