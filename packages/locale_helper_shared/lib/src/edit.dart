// packages/locale_helper_shared/lib/src/edit.dart
import 'package:meta/meta.dart';

enum EditStatus {
  pending,
  accepted,
  rejected;

  String toWire() => name;

  static EditStatus fromWire(String s) {
    for (final v in EditStatus.values) {
      if (v.name == s) return v;
    }
    throw ArgumentError.value(s, 'EditStatus', 'unknown value');
  }
}

@immutable
class Edit {
  final String id;
  final String projectId;
  final String key;
  final String locale;
  final String proposedValue;
  final String? comment;
  final String? authorUserId;
  final String? displayName;
  final String? authorEmail;
  final EditStatus status;
  final DateTime createdAt;

  const Edit({
    required this.id,
    required this.projectId,
    required this.key,
    required this.locale,
    required this.proposedValue,
    this.comment,
    this.authorUserId,
    this.displayName,
    this.authorEmail,
    required this.status,
    required this.createdAt,
  });

  /// Friendly author label: displayName if present, else email, else 'someone'.
  String get authorLabel => displayName ?? authorEmail ?? 'someone';

  factory Edit.fromJson(Map<String, dynamic> json) => Edit(
        id: json['id'] as String,
        projectId: json['projectId'] as String,
        key: json['key'] as String,
        // Older clients may not send `locale` — assume the project's source
        // locale at the call site; servers always send it on new payloads.
        locale: (json['locale'] as String?) ?? '',
        proposedValue: json['proposedValue'] as String,
        comment: json['comment'] as String?,
        authorUserId: json['authorUserId'] as String?,
        displayName: json['displayName'] as String?,
        authorEmail: json['authorEmail'] as String?,
        status: EditStatus.fromWire(json['status'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'projectId': projectId,
        'key': key,
        'locale': locale,
        'proposedValue': proposedValue,
        if (comment != null) 'comment': comment,
        if (authorUserId != null) 'authorUserId': authorUserId,
        if (displayName != null) 'displayName': displayName,
        if (authorEmail != null) 'authorEmail': authorEmail,
        'status': status.toWire(),
        'createdAt': createdAt.toUtc().toIso8601String(),
      };
}
