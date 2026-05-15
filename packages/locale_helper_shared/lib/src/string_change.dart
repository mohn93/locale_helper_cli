import 'package:meta/meta.dart';

enum ChangeSource {
  suggestion,
  direct,
  publish;

  String toWire() => name;

  static ChangeSource fromWire(String s) {
    for (final v in ChangeSource.values) {
      if (v.name == s) return v;
    }
    throw ArgumentError.value(s, 'ChangeSource', 'unknown value');
  }
}

@immutable
class StringChange {
  final String id;
  final String projectId;
  final String key;
  final String locale;
  final String? oldValue;
  final String newValue;
  final String? authorUserId;
  final String? authorDisplayName;
  final String? authorEmail;
  final ChangeSource source;
  final String? sourceEditId;
  final DateTime createdAt;

  const StringChange({
    required this.id,
    required this.projectId,
    required this.key,
    required this.locale,
    required this.oldValue,
    required this.newValue,
    required this.authorUserId,
    required this.authorDisplayName,
    required this.authorEmail,
    required this.source,
    required this.sourceEditId,
    required this.createdAt,
  });

  String get authorLabel =>
      authorDisplayName ?? authorEmail ?? 'unknown user';

  factory StringChange.fromJson(Map<String, dynamic> json) => StringChange(
        id: json['id'] as String,
        projectId: json['projectId'] as String,
        key: json['key'] as String,
        locale: (json['locale'] as String?) ?? '',
        oldValue: json['oldValue'] as String?,
        newValue: json['newValue'] as String,
        authorUserId: json['authorUserId'] as String?,
        authorDisplayName: json['authorDisplayName'] as String?,
        authorEmail: json['authorEmail'] as String?,
        source: ChangeSource.fromWire(json['source'] as String),
        sourceEditId: json['sourceEditId'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'projectId': projectId,
        'key': key,
        'locale': locale,
        if (oldValue != null) 'oldValue': oldValue,
        'newValue': newValue,
        if (authorUserId != null) 'authorUserId': authorUserId,
        if (authorDisplayName != null) 'authorDisplayName': authorDisplayName,
        if (authorEmail != null) 'authorEmail': authorEmail,
        'source': source.toWire(),
        if (sourceEditId != null) 'sourceEditId': sourceEditId,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };
}
