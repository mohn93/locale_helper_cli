// packages/locale_helper_cli/lib/src/commands/init_command.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import '../baseline_lock.dart';
import '../project_config.dart';
import 'command.dart';

class InitCommand implements CliCommand {
  final String workingDir;
  InitCommand({this.workingDir = '.'});

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

    ProjectConfig(backendUrl: backend, arbGlob: glob, sourceLocale: locale)
        .writeTo(cfgPath);

    ensureGitignored(workingDir);
    stdout.writeln('Wrote ${ProjectConfig.defaultPath}.');
    return 0;
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
