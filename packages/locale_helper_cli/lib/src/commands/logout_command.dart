// packages/locale_helper_cli/lib/src/commands/logout_command.dart
import 'dart:io';
import '../api_client.dart';
import '../credentials.dart';
import 'command.dart';

class LogoutCommand implements CliCommand {
  final CredentialsStore credentialsStore;
  final ApiClient Function(String backendUrl)? _clientFactory;

  LogoutCommand({
    CredentialsStore? credentialsStore,
    ApiClient Function(String backendUrl)? clientFactory,
  })  : credentialsStore = credentialsStore ?? CredentialsStore(),
        _clientFactory = clientFactory;

  ApiClient _makeClient(String url) =>
      _clientFactory != null ? _clientFactory!(url) : ApiClient(backendUrl: url);

  @override
  String get name => 'logout';

  @override
  String get description => 'Sign out from a locale_helper backend.';

  /// Non-interactive entry point for tests.
  Future<int> runWithInputs({required String backendUrl}) async {
    final cred = credentialsStore.read(backendUrl);
    if (cred == null) {
      stderr.writeln('Not signed in to $backendUrl.');
      return 1;
    }
    try {
      final api = _makeClient(backendUrl);
      await api.logout(cred.token);
    } catch (_) {
      // Best-effort: clear local credentials even if server call fails.
    }
    credentialsStore.clear(backendUrl);
    stdout.writeln('Signed out from $backendUrl.');
    return 0;
  }

  @override
  Future<int> run(List<String> args) async {
    stdout.write('Backend URL [http://localhost:8080]: ');
    final urlInput = stdin.readLineSync()?.trim() ?? '';
    final url = urlInput.isEmpty ? 'http://localhost:8080' : urlInput;
    return runWithInputs(backendUrl: url);
  }
}
