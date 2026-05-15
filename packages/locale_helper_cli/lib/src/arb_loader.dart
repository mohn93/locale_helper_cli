// packages/locale_helper_cli/lib/src/arb_loader.dart
import 'dart:io';
import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:locale_helper_shared/locale_helper_shared.dart';
import 'package:path/path.dart' as p;

/// Loads a single ARB file as [StringEntry]s for the given source locale.
List<StringEntry> loadArbFile(String path, {String sourceLocale = 'en'}) {
  final source = File(path).readAsStringSync();
  final arb = ArbFile.parse(source);
  return [
    for (final key in arb.keysInOrder)
      StringEntry(
        key: key,
        sourceLocale: sourceLocale,
        values: {sourceLocale: arb.value(key) ?? ''},
        arbMetadata: arb.metadata(key) ?? const {},
        usages: const [],
      ),
  ];
}

String arbLocale(String path) {
  final arb = ArbFile.parse(File(path).readAsStringSync());
  return arb.locale ?? 'en';
}

/// A merged view across every ARB file matched by an `arb_pattern`.
class BundleInputs {
  /// Every locale we discovered, in deterministic order with the source locale
  /// listed first.
  final List<String> locales;

  /// Ordered list of keys (in the source file's order, with extras appended).
  final List<BundleEntry> entries;

  const BundleInputs({required this.locales, required this.entries});
}

class BundleEntry {
  final String key;
  final String sourceValue;
  final Map<String, dynamic> arbMetadata;
  final Map<String, String?> values;

  const BundleEntry({
    required this.key,
    required this.sourceValue,
    required this.arbMetadata,
    required this.values,
  });
}

/// Loads every ARB file matching [pattern] (relative to [workingDir]) and
/// merges them into a single [BundleInputs].
///
/// The locale code is extracted from each filename: if the filename is of the
/// form `<prefix>_<locale>.arb` (e.g. `app_en.arb`, `app_pt_BR.arb`) we take
/// everything after the first `_`. Otherwise we fall back to the filename
/// minus the `.arb` suffix.
///
/// The file matching `sourceLocale` must exist; otherwise this throws a
/// [StateError] with a clear message.
BundleInputs loadArbBundle(
  String workingDir,
  String pattern,
  String sourceLocale,
) {
  final glob = Glob(pattern);
  final root = Directory(workingDir);
  final matches = glob
      .listSync(root: root.path, followLinks: false)
      .whereType<File>()
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  if (matches.isEmpty) {
    throw StateError(
      'No ARB files matched `$pattern` under $workingDir.',
    );
  }

  // Map of locale -> parsed ArbFile.
  final byLocale = <String, ArbFile>{};
  // Also remember the absolute path of each match so error messages are useful.
  final pathByLocale = <String, String>{};

  // Build a regex from the configured pattern that captures whatever the `*`
  // matches in each filename — that capture IS the locale code. This is much
  // more robust than hardcoding an `app_` prefix.
  //
  // We anchor the regex against the path *relative* to workingDir, so the
  // `*` capture is contextual (e.g. `lib/l10n/l10n_*.arb` against
  // `lib/l10n/l10n_en.arb` captures `en`, not `lib/l10n/l10n_en`).
  final patternRegex = _patternToRegex(pattern);

  for (final f in matches) {
    final source = f.readAsStringSync();
    final arb = ArbFile.parse(source);

    // Prefer @@locale inside the file when present (canonical).
    String? locale = arb.locale;

    // Otherwise extract from where `*` matched in the filename pattern.
    if (locale == null || locale.isEmpty) {
      final rel = p.relative(f.path, from: workingDir).replaceAll('\\', '/');
      final match = patternRegex.firstMatch(rel);
      if (match != null && match.groupCount >= 1) {
        locale = match.group(1);
      }
    }

    // Last-ditch fallback for legacy callers that didn't include a `*`.
    locale ??= _localeFromFilename(p.basename(f.path));

    byLocale[locale] = arb;
    pathByLocale[locale] = f.path;
  }

  if (!byLocale.containsKey(sourceLocale)) {
    throw StateError(
      'Source locale "$sourceLocale" not found among ARB files matched by '
      '`$pattern`. Got: ${byLocale.keys.toList()..sort()}.',
    );
  }

  // Build ordered key list: start with the source locale's keys (preserving
  // its order, which is the order developers maintain), then append any keys
  // that exist only in other locales.
  final sourceArb = byLocale[sourceLocale]!;
  final orderedKeys = <String>[...sourceArb.keysInOrder];
  final seen = orderedKeys.toSet();
  for (final entry in byLocale.entries) {
    if (entry.key == sourceLocale) continue;
    for (final k in entry.value.keysInOrder) {
      if (seen.add(k)) orderedKeys.add(k);
    }
  }

  // Deterministic locale ordering: source locale first, then the rest sorted.
  final otherLocales = byLocale.keys.where((l) => l != sourceLocale).toList()
    ..sort();
  final locales = <String>[sourceLocale, ...otherLocales];

  final entries = <BundleEntry>[];
  for (final k in orderedKeys) {
    final values = <String, String?>{};
    for (final locale in locales) {
      values[locale] = byLocale[locale]!.value(k);
    }
    final sourceValue = values[sourceLocale] ?? '';
    final meta = sourceArb.metadata(k) ?? const <String, dynamic>{};
    entries.add(BundleEntry(
      key: k,
      sourceValue: sourceValue,
      arbMetadata: meta,
      values: values,
    ));
  }

  return BundleInputs(locales: locales, entries: entries);
}

/// Converts a glob `pattern` into a regex that captures whatever `*` matches.
/// Only handles the common single-`*` case used by `arb_pattern`.
RegExp _patternToRegex(String pattern) {
  final escaped = pattern
      .replaceAll(r'\', r'\\')
      .replaceAll('.', r'\.')
      .replaceAll('+', r'\+')
      .replaceAll('?', r'\?')
      .replaceAll('(', r'\(')
      .replaceAll(')', r'\)')
      .replaceAll('[', r'\[')
      .replaceAll(']', r'\]')
      .replaceAll('*', r'([^/\\]+)');
  return RegExp('^$escaped\$');
}

/// `app_en.arb` -> `en`, `app_pt_BR.arb` -> `pt_BR`, `fr.arb` -> `fr`.
String _localeFromFilename(String filename) {
  final stem = filename.endsWith('.arb')
      ? filename.substring(0, filename.length - 4)
      : filename;
  final underscore = stem.indexOf('_');
  // Common Flutter convention: `app_<locale>.arb`. If we don't start with
  // "app_" (or any prefix with `_`), treat the whole stem as the locale code.
  if (underscore == -1) return stem;
  // Heuristic: only strip a prefix if the filename starts with `app_` (the
  // Flutter convention). Falling back keeps weird filenames intact.
  if (stem.startsWith('app_')) return stem.substring(4);
  return stem;
}
