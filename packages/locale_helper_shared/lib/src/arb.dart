// packages/locale_helper_shared/lib/src/arb.dart
import 'dart:convert';

class ArbFile {
  final String? locale;
  final List<String> keysInOrder;
  final Map<String, String> values;
  final Map<String, Map<String, dynamic>> metadataByKey;
  final Map<String, dynamic> extraTopLevel; // e.g. @@last_modified

  ArbFile._({
    required this.locale,
    required this.keysInOrder,
    required this.values,
    required this.metadataByKey,
    required this.extraTopLevel,
  });

  static ArbFile parse(String source) {
    final raw = jsonDecode(source);
    if (raw is! Map<String, dynamic>) {
      throw FormatException('ARB root must be an object');
    }
    String? locale;
    final keys = <String>[];
    final values = <String, String>{};
    final meta = <String, Map<String, dynamic>>{};
    final extras = <String, dynamic>{};

    raw.forEach((k, v) {
      if (k == '@@locale') {
        locale = v as String?;
      } else if (k.startsWith('@@')) {
        extras[k] = v;
      } else if (k.startsWith('@')) {
        meta[k.substring(1)] = (v as Map).cast<String, dynamic>();
      } else {
        keys.add(k);
        values[k] = v as String;
      }
    });

    return ArbFile._(
      locale: locale,
      keysInOrder: List.unmodifiable(keys),
      values: values,
      metadataByKey: meta,
      extraTopLevel: extras,
    );
  }

  /// Construct an ArbFile directly from ordered entries (no round-trip through
  /// a JSON string needed).
  factory ArbFile.fromEntries({
    required String locale,
    required List<({String key, String value, Map<String, dynamic>? metadata})>
    entries,
  }) {
    final keys = <String>[];
    final values = <String, String>{};
    final meta = <String, Map<String, dynamic>>{};
    for (final e in entries) {
      keys.add(e.key);
      values[e.key] = e.value;
      if (e.metadata != null && e.metadata!.isNotEmpty) {
        meta[e.key] = e.metadata!;
      }
    }
    return ArbFile._(
      locale: locale,
      keysInOrder: List.unmodifiable(keys),
      values: values,
      metadataByKey: meta,
      extraTopLevel: const {},
    );
  }

  String? value(String key) => values[key];
  Map<String, dynamic>? metadata(String key) => metadataByKey[key];

  ArbFile withReplacements(Map<String, String> replacements) {
    final newValues = Map<String, String>.from(values);
    replacements.forEach((k, v) {
      if (newValues.containsKey(k)) newValues[k] = v;
    });
    return ArbFile._(
      locale: locale,
      keysInOrder: keysInOrder,
      values: newValues,
      metadataByKey: metadataByKey,
      extraTopLevel: extraTopLevel,
    );
  }

  /// Serialise back to a well-ordered ARB JSON string.
  ///
  /// Layout: @@locale, other @@* keys, then for each key in order: value
  /// immediately followed by its @key metadata block (if any).
  String toJsonString({String indent = '  '}) {
    final out = <String, dynamic>{};
    if (locale != null) out['@@locale'] = locale;
    extraTopLevel.forEach((k, v) => out[k] = v);
    for (final k in keysInOrder) {
      out[k] = values[k];
      final m = metadataByKey[k];
      if (m != null) out['@$k'] = m;
    }
    return JsonEncoder.withIndent(indent).convert(out);
  }
}
