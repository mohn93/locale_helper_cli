// packages/locale_helper_cli/lib/src/commands/pull_command.dart
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:locale_helper_shared/locale_helper_shared.dart';
import 'package:path/path.dart' as p;

import '../api_client.dart';
import '../baseline_lock.dart';
import '../credentials.dart';
import '../project_config.dart';
import 'command.dart';
import 'init_command.dart';

/// Per-key classification used to drive the diff display + conflict handling.
enum _PullStatus {
  inSync, // baseline == local == server
  incoming, // server changed; local untouched -> safe to apply
  localOnly, // local changed; server untouched -> nothing to do
  bothSameValue, // server and local both moved to the same value -> no-op
  conflict, // both moved, to different values
  missingLocally, // key exists on server (and in baseline) but ARB lacks it
}

class _KeyDiff {
  final String key;
  final _PullStatus status;
  final String? baselineValue;
  final String? localValue;
  final String serverValue;
  _KeyDiff({
    required this.key,
    required this.status,
    required this.baselineValue,
    required this.localValue,
    required this.serverValue,
  });
}

class PullCommand implements CliCommand {
  final String workingDir;
  final CredentialsStore? credentialsStore;
  PullCommand({this.workingDir = '.', this.credentialsStore});

  @override
  String get name => 'pull';
  @override
  String get description =>
      'Show what changed on the server and (with --apply) write it into the ARB.';

  @override
  Future<int> run(List<String> args) async {
    final apply = args.contains('--apply');
    final takeTheirs = args.contains('--theirs');
    final takeOurs = args.contains('--ours');
    if (takeTheirs && takeOurs) {
      stderr.writeln('error: --theirs and --ours are mutually exclusive.');
      return 2;
    }
    String? localeFilter;
    for (final a in args) {
      if (a.startsWith('--locale=')) {
        localeFilter = a.substring('--locale='.length);
      }
    }

    final cfgPath = p.join(workingDir, ProjectConfig.defaultPath);
    if (!File(cfgPath).existsSync()) {
      stderr.writeln('No ${ProjectConfig.defaultPath} found.');
      return 1;
    }
    final cfg = ProjectConfig.load(cfgPath);
    if (cfg.projectId == null) {
      stderr.writeln(
          'Project not published yet. Run `locale_helper publish` first.',);
      return 1;
    }

    final store = credentialsStore ?? CredentialsStore();
    final cred = store.read(cfg.backendUrl);
    if (cred == null) {
      stderr.writeln(
          'No credentials for ${cfg.backendUrl}. Run `locale_helper login`.',);
      return 1;
    }

    final api = ApiClient(backendUrl: cfg.backendUrl, token: cred.token);
    final Map<String, Map<String, String>> serverValues;
    try {
      serverValues = await api.currentValues(cfg.projectId!,
          fallbackLocale: cfg.sourceLocale,);
    } on http.ClientException catch (e) {
      stderr.writeln(
          'error: cannot reach backend at ${cfg.backendUrl}: ${e.message}',);
      return 1;
    } on StateError catch (e) {
      if (e.message == '401') {
        stderr.writeln('error: not signed in. Run `locale_helper login`.');
        return 1;
      }
      if (e.message == '403') {
        stderr.writeln('error: you are not a member of this project.');
        return 1;
      }
      stderr.writeln('error: ${e.message}');
      return 1;
    }

    if (localeFilter != null && !serverValues.containsKey(localeFilter)) {
      stderr.writeln(
        'error: locale "$localeFilter" is not present on the server. '
        'Known locales: ${serverValues.keys.toList()..sort()}',
      );
      return 1;
    }

    // Determine which locales we'll operate on.
    final localesToProcess = <String>{
      if (localeFilter != null) localeFilter else ...serverValues.keys,
    };
    // Always include the source locale so first-publish projects with no
    // recorded server values still resolve their ARB path correctly.
    if (localeFilter == null && serverValues.isEmpty) {
      localesToProcess.add(cfg.sourceLocale);
    }

    final baseline = BaselineLock.read(workingDir,
        sourceLocale: cfg.sourceLocale,);
    if (baseline == null) {
      stdout.writeln(
        'No baseline.lock found — treating local ARB as the baseline. '
        'After this command finishes, future syncs will use 3-way conflict detection.',
      );
    }

    // Parsed ARB per locale (or null if file doesn't exist yet).
    final arbByLocale = <String, ArbFile?>{};
    final arbPathByLocale = <String, String>{};
    for (final locale in localesToProcess) {
      final path = _arbPathForLocale(workingDir, cfg.arbPattern, locale);
      arbPathByLocale[locale] = path;
      arbByLocale[locale] =
          File(path).existsSync() ? ArbFile.parse(File(path).readAsStringSync()) : null;
    }

    // Build diffs per locale.
    final diffsByLocale = <String, List<_KeyDiff>>{};
    for (final locale in localesToProcess) {
      final arb = arbByLocale[locale];
      final baselineValues = baseline?.valuesFor(locale) ??
          _defaultBaselineFromArb(arb);
      final serverMap = serverValues[locale] ?? const <String, String>{};

      final allKeys = <String>{
        ...serverMap.keys,
        ...baselineValues.keys,
        if (arb != null) ...arb.keysInOrder,
      };

      final diffs = <_KeyDiff>[];
      for (final k in allKeys) {
        final baseVal = baselineValues[k];
        final localVal = arb?.value(k);
        final serverVal = serverMap[k] ?? baseVal;
        if (serverVal == null) continue;

        final localChanged = localVal != baseVal;
        final serverChanged = serverVal != baseVal;

        _PullStatus status;
        if (localVal == null) {
          status = _PullStatus.missingLocally;
        } else if (!serverChanged && !localChanged) {
          status = _PullStatus.inSync;
        } else if (serverChanged && !localChanged) {
          status = _PullStatus.incoming;
        } else if (!serverChanged && localChanged) {
          status = _PullStatus.localOnly;
        } else if (localVal == serverVal) {
          status = _PullStatus.bothSameValue;
        } else {
          status = _PullStatus.conflict;
        }
        diffs.add(_KeyDiff(
          key: k,
          status: status,
          baselineValue: baseVal,
          localValue: localVal,
          serverValue: serverVal,
        ),);
      }
      diffsByLocale[locale] = diffs;
    }

    // Print and aggregate counts across locales.
    var totalIncoming = 0;
    var totalConflicts = 0;
    final sortedLocales = localesToProcess.toList()..sort();
    // Display source locale first, others sorted.
    sortedLocales.sort((a, b) {
      if (a == cfg.sourceLocale) return -1;
      if (b == cfg.sourceLocale) return 1;
      return a.compareTo(b);
    });

    for (final locale in sortedLocales) {
      final diffs = diffsByLocale[locale] ?? const [];
      final incoming =
          diffs.where((d) => d.status == _PullStatus.incoming).toList();
      final conflicts =
          diffs.where((d) => d.status == _PullStatus.conflict).toList();
      final localOnly =
          diffs.where((d) => d.status == _PullStatus.localOnly).toList();
      final missing =
          diffs.where((d) => d.status == _PullStatus.missingLocally).toList();
      totalIncoming += incoming.length;
      totalConflicts += conflicts.length;
      _printLocaleHeader(locale);
      _printDiffs(incoming, conflicts, localOnly, missing);
    }

    if (totalIncoming == 0 && totalConflicts == 0) {
      stdout.writeln('\nNothing to apply.');
      return 0;
    }

    if (!apply) {
      if (totalConflicts > 0) {
        stdout.writeln(
          '\n$totalConflicts conflict(s). Resolve by running:\n'
          '  locale_helper pull --apply --theirs   # accept server values\n'
          '  locale_helper pull --apply --ours     # keep your local values\n'
          'or edit the ARB by hand and re-run.',
        );
      } else {
        stdout.writeln('\nRun again with --apply to write changes.');
      }
      return 0;
    }

    if (totalConflicts > 0 && !takeTheirs && !takeOurs) {
      stderr.writeln(
        '\nerror: $totalConflicts conflict(s) — refusing to overwrite. '
        'Re-run with --theirs or --ours, or edit the ARB by hand.',
      );
      return 1;
    }

    // Apply per-locale.
    var totalApplied = 0;
    final newBaselineByLocale = <String, Map<String, String>>{};
    // Preserve existing baseline entries for locales we didn't touch (e.g.
    // when --locale=fr filters us to a single locale).
    if (baseline != null) {
      for (final entry in baseline.valuesByLocale.entries) {
        newBaselineByLocale[entry.key] = Map<String, String>.from(entry.value);
      }
    }

    for (final locale in localesToProcess) {
      final diffs = diffsByLocale[locale] ?? const [];
      final incoming =
          diffs.where((d) => d.status == _PullStatus.incoming).toList();
      final conflicts =
          diffs.where((d) => d.status == _PullStatus.conflict).toList();

      final replacements = <String, String>{};
      for (final d in incoming) {
        replacements[d.key] = d.serverValue;
      }
      for (final d in conflicts) {
        if (takeTheirs) replacements[d.key] = d.serverValue;
        // takeOurs: skip — keep local.
      }

      final path = arbPathByLocale[locale]!;
      final existing = arbByLocale[locale];

      // Touched = either we have replacements, OR this locale had any
      // conflict/incoming considered (so we re-serialise the ARB to its
      // canonical form). For locales with no work at all, skip the write.
      final touched = replacements.isNotEmpty ||
          (diffs.isNotEmpty &&
              diffs.any((d) =>
                  d.status == _PullStatus.conflict ||
                  d.status == _PullStatus.incoming,));

      if (existing != null && touched) {
        final updated = existing.withReplacements(replacements);
        File(path).writeAsStringSync('${updated.toJsonString()}\n');
        arbByLocale[locale] = updated;
        totalApplied += replacements.length;
      } else if (existing == null && replacements.isNotEmpty) {
        // ARB file didn't exist yet — create it from scratch with just the
        // server values for this locale + an @@locale header.
        final entries = [
          for (final entry in replacements.entries)
            (key: entry.key, value: entry.value, metadata: null),
        ];
        Directory(p.dirname(path)).createSync(recursive: true);
        final newArb = ArbFile.fromEntries(
          locale: locale,
          entries: entries,
        );
        File(path).writeAsStringSync('${newArb.toJsonString()}\n');
        arbByLocale[locale] = newArb;
        totalApplied += replacements.length;
      }

      // Build the new baseline entry for this locale: post-apply ARB values
      // for every key the server knows about.
      final serverMap = serverValues[locale] ?? const <String, String>{};
      final baselineValues = baseline?.valuesFor(locale) ?? const <String, String>{};
      final post = arbByLocale[locale];
      final newBaseline = <String, String>{};
      for (final k in {...serverMap.keys, ...baselineValues.keys}) {
        final v = post?.value(k);
        if (v != null) newBaseline[k] = v;
      }
      newBaselineByLocale[locale] = newBaseline;
    }

    BaselineLock.writeNested(workingDir, newBaselineByLocale);
    InitCommand.ensureGitignored(workingDir);

    stdout.writeln(
      '\nApplied $totalApplied key(s) across '
      '${localesToProcess.length} locale(s). Baseline updated.',
    );
    return 0;
  }

  void _printLocaleHeader(String locale) {
    stdout.writeln('\nLocale: $locale');
  }

  void _printDiffs(
    List<_KeyDiff> incoming,
    List<_KeyDiff> conflicts,
    List<_KeyDiff> localOnly,
    List<_KeyDiff> missing,
  ) {
    if (incoming.isEmpty &&
        conflicts.isEmpty &&
        localOnly.isEmpty &&
        missing.isEmpty) {
      stdout.writeln('Everything in sync.');
      return;
    }
    if (incoming.isNotEmpty) {
      stdout.writeln('Incoming (server changed, local untouched):');
      for (final d in incoming) {
        stdout.writeln(
            '  ~ ${d.key}: "${d.localValue}" -> "${d.serverValue}"',);
      }
    }
    if (conflicts.isNotEmpty) {
      stdout.writeln('\nConflicts (both sides changed):');
      for (final d in conflicts) {
        stdout.writeln('  ! ${d.key}');
        stdout.writeln('      base:   "${d.baselineValue}"');
        stdout.writeln('      local:  "${d.localValue}"');
        stdout.writeln('      server: "${d.serverValue}"');
      }
    }
    if (localOnly.isNotEmpty) {
      stdout.writeln(
          '\nLocal-only (will go up at next publish):',);
      for (final d in localOnly) {
        stdout.writeln(
            '  + ${d.key}: "${d.baselineValue}" -> "${d.localValue}"',);
      }
    }
    if (missing.isNotEmpty) {
      stdout.writeln(
          '\nMissing locally (server has a value, your ARB does not):',);
      for (final d in missing) {
        stdout.writeln('  ? ${d.key}: server has "${d.serverValue}"');
      }
    }
  }

  /// Fallback when no baseline.lock exists yet: pretend the current ARB is
  /// the baseline so the first pull behaves like the old "server wins" mode
  /// for unchanged-locally keys, but at least flags real conflicts.
  Map<String, String> _defaultBaselineFromArb(ArbFile? arb) {
    if (arb == null) return const <String, String>{};
    return {for (final k in arb.keysInOrder) k: arb.value(k) ?? ''};
  }

  /// Derive the ARB filename for [locale] from [pattern].
  /// Replaces the first `*` in the pattern with the locale code. If the
  /// pattern has no `*` (legacy single-file configs), returns it unchanged.
  static String _arbPathForLocale(
      String workingDir, String pattern, String locale,) {
    final patched =
        pattern.contains('*') ? pattern.replaceFirst('*', locale) : pattern;
    return p.join(workingDir, patched);
  }
}
