// packages/locale_helper_cli/lib/src/commands/login_command.dart
import 'dart:io';
import '../api_client.dart';
import '../credentials.dart';
import 'command.dart';

class LoginCommand implements CliCommand {
  final CredentialsStore credentialsStore;
  final ApiClient Function(String backendUrl)? _clientFactory;

  LoginCommand({
    CredentialsStore? credentialsStore,
    ApiClient Function(String backendUrl)? clientFactory,
  })  : credentialsStore = credentialsStore ?? CredentialsStore(),
        _clientFactory = clientFactory;

  ApiClient _makeClient(String url) =>
      _clientFactory != null ? _clientFactory!(url) : ApiClient(backendUrl: url);

  @override
  String get name => 'login';

  @override
  String get description => 'Authenticate with a locale_helper backend.';

  /// Non-interactive entry point for tests.
  Future<int> runWithInputs({
    required String backendUrl,
    required String email,
    required String password,
  }) async {
    final api = _makeClient(backendUrl);
    try {
      final auth = await api.login(email: email, password: password);
      credentialsStore.save(
          backendUrl: backendUrl, email: auth.user.email, token: auth.token);
      stdout.writeln('Signed in as ${auth.user.email}.');
      return 0;
    } catch (e) {
      stderr.writeln('error: $e');
      return 1;
    }
  }

  @override
  Future<int> run(List<String> args) async {
    stdout.write('Backend URL [http://localhost:8080]: ');
    final urlInput = stdin.readLineSync()?.trim() ?? '';
    final url = urlInput.isEmpty ? 'http://localhost:8080' : urlInput;
    stdout.write('Email: ');
    final email = stdin.readLineSync()?.trim() ?? '';
    stdout.write('Password: ');
    stdin.echoMode = false;
    final password = stdin.readLineSync() ?? '';
    stdin.echoMode = true;
    stdout.writeln();
    return runWithInputs(backendUrl: url, email: email, password: password);
  }
}
