// packages/locale_helper_cli/lib/src/commands/status_command.dart
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:locale_helper_shared/locale_helper_shared.dart';
import 'package:path/path.dart' as p;

import '../api_client.dart';
import '../credentials.dart';
import '../project_config.dart';
import 'command.dart';

class StatusCommand implements CliCommand {
  final String workingDir;
  final IOSink? out;
  final CredentialsStore? credentialsStore;
  StatusCommand({this.workingDir = '.', this.out, this.credentialsStore});

  IOSink get _out => out ?? stdout;

  @override
  String get name => 'status';
  @override
  String get description => 'Show review/edit status for the current project.';

  @override
  Future<int> run(List<String> args) async {
    final cfgPath = p.join(workingDir, ProjectConfig.defaultPath);
    if (!File(cfgPath).existsSync()) {
      stderr.writeln('No ${ProjectConfig.defaultPath} found.');
      return 1;
    }
    final cfg = ProjectConfig.load(cfgPath);
    if (cfg.projectId == null) {
      _out.writeln('Project not published yet.');
      return 0;
    }

    // Load credentials
    final store = credentialsStore ?? CredentialsStore();
    final cred = store.read(cfg.backendUrl);
    if (cred == null) {
      stderr.writeln(
          'No credentials for ${cfg.backendUrl}. Run `locale_helper login`.');
      return 1;
    }

    final api = ApiClient(backendUrl: cfg.backendUrl, token: cred.token);
    final List<Edit> edits;
    try {
      edits = await api.listAllEdits(cfg.projectId!);
    } on http.ClientException catch (e) {
      stderr.writeln(
          'error: cannot reach backend at ${cfg.backendUrl}: ${e.message}');
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

    final counts = <EditStatus, int>{
      for (final s in EditStatus.values) s: 0,
    };
    for (final e in edits) counts[e.status] = counts[e.status]! + 1;

    _out.writeln('Project:   ${cfg.projectId}');
    _out.writeln('Backend:   ${cfg.backendUrl}');
    _out.writeln('Review:    ${cfg.backendUrl}/review/${cfg.projectId}');
    _out.writeln('Dashboard: ${cfg.backendUrl}/dashboard/${cfg.projectId}');
    _out.writeln('Edits:     pending=${counts[EditStatus.pending]} '
        'accepted=${counts[EditStatus.accepted]} rejected=${counts[EditStatus.rejected]}');
    return 0;
  }
}
