// packages/locale_helper_cli/lib/src/commands/publish_command.dart
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:locale_helper_shared/locale_helper_shared.dart';
import 'package:path/path.dart' as p;

import '../api_client.dart';
import '../arb_loader.dart';
import '../baseline_lock.dart';
import '../credentials.dart';
import '../project_config.dart';
import '../usage_scanner.dart';
import 'command.dart';
import 'init_command.dart';

class PublishCommand implements CliCommand {
  final String workingDir;
  final CredentialsStore? credentialsStore;
  PublishCommand({this.workingDir = '.', this.credentialsStore});

  @override
  String get name => 'publish';
  @override
  String get description => 'Scan strings + usages and publish a review bundle.';

  @override
  Future<int> run(List<String> args) async {
    final force = args.contains('--force');
    final cfgPath = p.join(workingDir, ProjectConfig.defaultPath);
    if (!File(cfgPath).existsSync()) {
      stderr.writeln(
          'No ${ProjectConfig.defaultPath} found. Run `locale_helper init` first.',);
      return 1;
    }
    final cfg = ProjectConfig.load(cfgPath);

    // Load credentials
    final store = credentialsStore ?? CredentialsStore();
    final cred = store.read(cfg.backendUrl);
    if (cred == null) {
      stderr.writeln(
          'No credentials for ${cfg.backendUrl}. Run `locale_helper login`.',);
      return 1;
    }

    final BundleInputs inputs;
    try {
      inputs = loadArbBundle(workingDir, cfg.arbPattern, cfg.sourceLocale);
    } on StateError catch (e) {
      stderr.writeln(e.message);
      return 1;
    }
    final keys = inputs.entries.map((e) => e.key).toSet();
    stdout.writeln(
      'Scanning ${inputs.entries.length} strings across ${inputs.locales.length} '
      'locale(s) (${inputs.locales.join(', ')})...',
    );

    final scanner = UsageScanner(
      rootDir: workingDir,
      typePatterns: const ['AppLocalizations', 'S.', 'LocaleKeys', 'l10n', 'strings'],
    );
    final usages = await scanner.scan(keys: keys);

    final stringEntries = [
      for (final e in inputs.entries)
        StringEntry(
          key: e.key,
          sourceLocale: cfg.sourceLocale,
          values: e.values,
          arbMetadata: e.arbMetadata,
          usages: usages[e.key] ?? const [],
        ),
    ];

    final bundle = Bundle(
      projectId: cfg.projectId ?? '',
      sourceLocale: cfg.sourceLocale,
      locales: inputs.locales,
      strings: stringEntries,
      createdAt: DateTime.now().toUtc(),
    );

    // Project name: use config value, or fall back to directory basename
    final projectName = cfg.projectName ??
        p.basename(File(workingDir).absolute.path);

    final api = ApiClient(backendUrl: cfg.backendUrl, token: cred.token);

    // Pre-check: if we have a baseline and the project exists on the server,
    // refuse to publish over server-side changes we haven't pulled.
    if (cfg.projectId != null) {
      final baseline = BaselineLock.read(workingDir,
          sourceLocale: cfg.sourceLocale,);
      if (baseline != null) {
        try {
          final serverValues = await api.currentValues(cfg.projectId!,
              fallbackLocale: cfg.sourceLocale,);
          final conflicts = <String>[]; // formatted "locale:key" entries

          // Build local values per locale from the inputs.
          final localByLocale = <String, Map<String, String?>>{};
          for (final locale in inputs.locales) {
            localByLocale[locale] = {
              for (final e in inputs.entries) e.key: e.values[locale],
            };
          }

          final allLocales = <String>{
            ...baseline.valuesByLocale.keys,
            ...serverValues.keys,
            ...localByLocale.keys,
          };
          for (final locale in allLocales) {
            final baseMap = baseline.valuesFor(locale);
            final serverMap = serverValues[locale] ?? const <String, String>{};
            final localMap =
                localByLocale[locale] ?? const <String, String?>{};
            final localeKeys = <String>{
              ...baseMap.keys,
              ...serverMap.keys,
              ...localMap.keys,
            };
            for (final k in localeKeys) {
              final baseVal = baseMap[k];
              final serverVal = serverMap[k] ?? baseVal;
              final localVal = localMap.containsKey(k)
                  ? (localMap[k] ?? baseVal)
                  : baseVal;
              if (serverVal == null) continue;
              final serverChanged = serverVal != baseVal;
              final localChanged = localVal != baseVal;
              if (serverChanged && localChanged && serverVal != localVal) {
                conflicts.add('$locale:$k');
              }
            }
          }

          if (conflicts.isNotEmpty && !force) {
            stderr.writeln(
              'error: ${conflicts.length} (locale, key) pair(s) have diverging '
              'server changes:',
            );
            for (final c in conflicts) {
              stderr.writeln('  ! $c');
            }
            stderr.writeln(
              'Run `locale_helper pull` to merge first, or re-run with '
              '--force to overwrite the server.',
            );
            return 1;
          }
        } on http.ClientException catch (e) {
          stderr.writeln(
              'warning: could not pre-check server changes: ${e.message}',);
        } on StateError catch (_) {
          // Not authorized to fetch /changes — fall through and let publish
          // surface the real error.
        }
      }
    }

    try {
      final response = await api.publish(
        PublishRequest(
          bundle: bundle,
          projectName: projectName,
          projectId: cfg.projectId,
        ),
      );
      ProjectConfig.updateAfterPublish(
        cfgPath,
        projectId: response.projectId,
      );

      // Write the new baseline using the full nested per-locale shape.
      final baselineByLocale = <String, Map<String, String>>{};
      for (final locale in inputs.locales) {
        final m = <String, String>{};
        for (final e in inputs.entries) {
          final v = e.values[locale];
          if (v != null) m[e.key] = v;
        }
        baselineByLocale[locale] = m;
      }
      BaselineLock.writeNested(workingDir, baselineByLocale);
      InitCommand.ensureGitignored(workingDir);
      stdout.writeln('Review:    ${response.reviewUrl}');
      stdout.writeln('Settings:  ${response.settingsUrl}');
      return 0;
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
        stderr.writeln('error: you are not the owner of this project.');
        return 1;
      }
      stderr.writeln('error: ${e.message}');
      return 1;
    }
  }
}
