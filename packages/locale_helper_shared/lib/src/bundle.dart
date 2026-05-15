// packages/locale_helper_shared/lib/src/bundle.dart
import 'package:meta/meta.dart';
import 'string_entry.dart';

@immutable
class Bundle {
  final String projectId;
  final String sourceLocale;
  final List<String> locales;
  final List<StringEntry> strings;
  final DateTime createdAt;

  const Bundle({
    required this.projectId,
    required this.sourceLocale,
    required this.locales,
    required this.strings,
    required this.createdAt,
  });

  factory Bundle.fromJson(Map<String, dynamic> json) {
    final sourceLocale = json['sourceLocale'] as String;
    final localesRaw = json['locales'];
    final locales = localesRaw is List
        ? localesRaw.cast<String>()
        : <String>[sourceLocale];
    return Bundle(
      projectId: json['projectId'] as String,
      sourceLocale: sourceLocale,
      locales: locales,
      strings: ((json['strings'] as List?) ?? const [])
          .map((e) => StringEntry.fromJson(
                (e as Map).cast<String, dynamic>(),
                sourceLocale: sourceLocale,
              ))
          .toList(growable: false),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'projectId': projectId,
        'sourceLocale': sourceLocale,
        'locales': locales,
        'strings': strings.map((s) => s.toJson()).toList(growable: false),
        'createdAt': createdAt.toUtc().toIso8601String(),
      };
}
