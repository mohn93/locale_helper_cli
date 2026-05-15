// packages/locale_helper_cli/lib/src/baseline_lock.dart
//
// On-disk snapshot of "the strings as they existed at the last successful sync
// (publish or pull --apply)". Lives next to the project config at
// `.locale_helper/baseline.lock.json`.
//
// Used to do 3-way conflict detection on subsequent pulls and publishes:
//   baseline -> local  (local changes the dev made since last sync)
//   baseline -> server (changes accepted upstream since last sync)
//
// Shape on disk (current):
//   { "updatedAt": "...", "values": { "<locale>": { "<key>": "<value>" } } }
//
// Legacy shape (still accepted on read):
//   { "updatedAt": "...", "values": { "<key>": "<value>" } }
// — interpreted as the source locale's values.

import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

class BaselineLock {
  static const dirName = '.locale_helper';
  static const fileName = 'baseline.lock.json';

  /// Per-locale values: `valuesByLocale[locale][key] = value`.
  final Map<String, Map<String, String>> valuesByLocale;
  final DateTime? updatedAt;

  /// Source locale (used to expose [values] for back-compat with single-locale
  /// callers). Defaults to whichever locale the on-disk file calls out, or
  /// falls back to `en`.
  final String sourceLocale;

  const BaselineLock({
    required this.valuesByLocale,
    required this.sourceLocale,
    this.updatedAt,
  });

  /// Back-compat: a flat view of the source-locale values, so existing
  /// single-locale callers keep working unchanged.
  Map<String, String> get values =>
      valuesByLocale[sourceLocale] ?? const <String, String>{};

  /// Returns the recorded values for [locale], or an empty map if we have
  /// no record of that locale yet.
  Map<String, String> valuesFor(String locale) =>
      valuesByLocale[locale] ?? const <String, String>{};

  static String pathFor(String workingDir) =>
      p.join(workingDir, dirName, fileName);

  /// Reads the baseline if present. Returns `null` if no baseline exists yet
  /// (first-ever sync) so callers can treat that case explicitly.
  ///
  /// Accepts both the new nested shape and the legacy flat shape. For the
  /// legacy shape, callers can pass [sourceLocale] to tell us which locale
  /// those keys belong to; otherwise we default to `en`.
  static BaselineLock? read(
    String workingDir, {
    String sourceLocale = 'en',
  }) {
    final f = File(pathFor(workingDir));
    if (!f.existsSync()) return null;
    final raw = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    final rawValues = raw['values'];
    Map<String, Map<String, String>> nested;
    String effectiveSource = sourceLocale;
    if (rawValues is Map) {
      final asMap = rawValues.cast<String, dynamic>();
      // Detect legacy flat shape: values are strings rather than maps.
      final isLegacy = asMap.values.any((v) => v is String);
      if (isLegacy) {
        nested = {
          sourceLocale: asMap.map((k, v) => MapEntry(k, v as String)),
        };
      } else {
        nested = {
          for (final e in asMap.entries)
            e.key: (e.value as Map)
                .cast<String, dynamic>()
                .map((k, v) => MapEntry(k, v as String)),
        };
        // If the recorded source locale isn't in this file at all but we have
        // exactly one locale, treat that one as the source for back-compat.
        if (!nested.containsKey(sourceLocale) && nested.length == 1) {
          effectiveSource = nested.keys.first;
        }
      }
    } else {
      nested = <String, Map<String, String>>{};
    }
    final updatedAtRaw = raw['updatedAt'] as String?;
    return BaselineLock(
      valuesByLocale: nested,
      sourceLocale: effectiveSource,
      updatedAt:
          updatedAtRaw == null ? null : DateTime.parse(updatedAtRaw),
    );
  }

  /// Writes the baseline. Two call shapes are accepted for convenience:
  ///   1. `write(workingDir, {key: value})` — legacy single-locale call;
  ///      the caller must also pass [sourceLocale] (defaults to `en`).
  ///   2. `write.nested(workingDir, {locale: {key: value}})` — full shape.
  static void write(
    String workingDir,
    Map<String, String> values, {
    String sourceLocale = 'en',
  }) {
    writeNested(workingDir, {sourceLocale: values});
  }

  /// Writes the new nested baseline shape directly.
  static void writeNested(
    String workingDir,
    Map<String, Map<String, String>> valuesByLocale,
  ) {
    final dir = Directory(p.join(workingDir, dirName));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final f = File(pathFor(workingDir));
    final payload = <String, dynamic>{
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'values': valuesByLocale,
    };
    f.writeAsStringSync('${jsonEncode(payload)}\n');
  }
}
