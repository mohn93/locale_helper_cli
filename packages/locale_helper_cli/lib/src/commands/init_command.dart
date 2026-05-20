// packages/locale_helper_cli/lib/src/commands/init_command.dart
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:locale_helper_shared/locale_helper_shared.dart';
import 'package:path/path.dart' as p;
import '../api_client.dart';
import '../baseline_lock.dart';
import '../credentials.dart';
import '../project_config.dart';
import 'command.dart';

class InitCommand implements CliCommand {
  final String workingDir;
  final CredentialsStore? credentialsStore;
  InitCommand({this.workingDir = '.', this.credentialsStore});

  @override
  String get name => 'init';
  @override
  String get description => 'Initialize a locale_helper config file.';

  @override
  Future<int> run(List<String> args) async {
    final cfgPath = p.join(workingDir, ProjectConfig.defaultPath);
    if (File(cfgPath).existsSync()) {
      stderr.writeln(
        '${ProjectConfig.defaultPath} already exists. Refusing to overwrite.',
      );
      return 1;
    }
    String prompt(String label, String fallback) {
      stdout.write('$label [$fallback]: ');
      final line = stdin.readLineSync()?.trim();
      return (line == null || line.isEmpty) ? fallback : line;
    }

    final backend = prompt('Backend URL', 'http://localhost:8080');
    final glob = prompt('ARB glob', 'lib/l10n/app_en.arb');
    final locale = prompt('Source locale', 'en');

    // Optional attach step: when logged in, offer to pick an existing project
    // so first `publish` reuses it. Best-effort — any failure is silent and
    // we keep local-only behavior.
    String? attachedProjectId;
    try {
      final store = credentialsStore ?? CredentialsStore();
      final cred = store.read(backend);
      if (cred != null) {
        final api = ApiClient(backendUrl: backend, token: cred.token);
        final projects = await api.listMyProjects();
        attachedProjectId = pickProjectFromList(
          projects,
          readLine: () => stdin.readLineSync(),
          writeLine: stdout.writeln,
        );
      }
    } on http.ClientException catch (_) {
      // Network unreachable / server down — silent fallback to local-only.
    } on SocketException catch (_) {
      // DNS / connect failure.
    } on StateError catch (_) {
      // ApiClient signals 401/403/non-200 via StateError.
    } on FormatException catch (_) {
      // Server returned non-JSON for some reason.
    }

    ProjectConfig(
      backendUrl: backend,
      arbGlob: glob,
      sourceLocale: locale,
      projectId: attachedProjectId,
    ).writeTo(cfgPath);

    ensureGitignored(workingDir);
    if (attachedProjectId != null) {
      stdout.writeln('Attached to existing project $attachedProjectId.');
    }
    stdout.writeln('Wrote ${ProjectConfig.defaultPath}.');
    return 0;
  }

  /// Pure picker: ask the user whether to attach to one of the existing
  /// projects in [projects], and if so which one. Returns the chosen
  /// projectId, or null if the user declined / EOF / the list was empty.
  ///
  /// I/O is injected so this can be unit-tested without touching real
  /// stdin/stdout.
  static String? pickProjectFromList(
    List<ProjectListItemDto> projects, {
    required String? Function() readLine,
    required void Function(String) writeLine,
  }) {
    if (projects.isEmpty) return null;

    writeLine(
      'Found ${projects.length} project'
      '${projects.length == 1 ? '' : 's'} in your account:',
    );
    for (var i = 0; i < projects.length; i++) {
      final p = projects[i];
      writeLine('  ${i + 1}) ${p.name}  (${p.myRole})');
    }
    writeLine('Attach to an existing project (a) or create a new one (n)?');

    final choice = readLine()?.trim().toLowerCase();
    if (choice == null || choice != 'a') return null;

    while (true) {
      writeLine('Pick a project (1-${projects.length}):');
      final raw = readLine();
      if (raw == null) return null; // EOF
      final n = int.tryParse(raw.trim());
      if (n != null && n >= 1 && n <= projects.length) {
        return projects[n - 1].id;
      }
      writeLine('Invalid choice.');
    }
  }

  /// Ensures `.gitignore` (creating it if missing) lists the dev-local
  /// `.locale_helper/` directory so the baseline.lock isn't committed.
  /// Also keeps the legacy `.locale_helper.yaml` ignore entry intact if
  /// callers want it, but does not add it — the config file is shared.
  static void ensureGitignored(String workingDir) {
    final gi = File(p.join(workingDir, '.gitignore'));
    const marker = '${BaselineLock.dirName}/';
    if (!gi.existsSync()) {
      gi.writeAsStringSync(
        '# locale_helper: dev-local sync state (baseline.lock)\n$marker\n',
      );
      return;
    }
    final body = gi.readAsStringSync();
    if (body.split('\n').any((line) => line.trim() == marker)) return;
    final trailingNewline = body.endsWith('\n') ? '' : '\n';
    gi.writeAsStringSync(
      '$trailingNewline# locale_helper: dev-local sync state (baseline.lock)\n$marker\n',
      mode: FileMode.append,
    );
  }
}
