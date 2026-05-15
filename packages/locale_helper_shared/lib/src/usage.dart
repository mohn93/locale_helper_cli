// packages/locale_helper_shared/lib/src/usage.dart
import 'package:meta/meta.dart';

import 'role.dart';

@immutable
class Usage {
  final String filePath;
  final int lineStart;
  final int lineEnd;
  final String codeSnippet;
  final String? surroundingWidget;
  final String? enclosingWidgetCode;
  final Role role;

  const Usage({
    required this.filePath,
    required this.lineStart,
    required this.lineEnd,
    required this.codeSnippet,
    this.surroundingWidget,
    this.enclosingWidgetCode,
    this.role = Role.other,
  });

  factory Usage.fromJson(Map<String, dynamic> json) => Usage(
    filePath: json['filePath'] as String,
    lineStart: json['lineStart'] as int,
    lineEnd: json['lineEnd'] as int,
    codeSnippet: json['codeSnippet'] as String,
    surroundingWidget: json['surroundingWidget'] as String?,
    enclosingWidgetCode: json['enclosingWidgetCode'] as String?,
    role: json.containsKey('role')
        ? Role.fromWire(json['role'] as String)
        : Role.other,
  );

  Map<String, dynamic> toJson() => {
    'filePath': filePath,
    'lineStart': lineStart,
    'lineEnd': lineEnd,
    'codeSnippet': codeSnippet,
    if (surroundingWidget != null) 'surroundingWidget': surroundingWidget,
    if (enclosingWidgetCode != null) 'enclosingWidgetCode': enclosingWidgetCode,
    if (role != Role.other) 'role': role.toWire(),
  };
}
