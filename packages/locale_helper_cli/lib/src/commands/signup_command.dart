// packages/locale_helper_cli/lib/src/commands/signup_command.dart
import 'dart:io';
import '../api_client.dart';
import '../credentials.dart';
import 'command.dart';

class SignupCommand implements CliCommand {
  final CredentialsStore credentialsStore;
  final ApiClient Function(String backendUrl)? _clientFactory;

  SignupCommand({
    CredentialsStore? credentialsStore,
    ApiClient Function(String backendUrl)? clientFactory,
  })  : credentialsStore = credentialsStore ?? CredentialsStore(),
        _clientFactory = clientFactory;

  ApiClient _makeClient(String url) =>
      _clientFactory != null ? _clientFactory(url) : ApiClient(backendUrl: url);

  @override
  String get name => 'signup';

  @override
  String get description => 'Create a new account on a locale_helper backend.';

  /// Non-interactive entry point for tests.
  Future<int> runWithInputs({
    required String backendUrl,
    required String email,
    required String password,
    String? displayName,
  }) async {
    final api = _makeClient(backendUrl);
    try {
      final auth = await api.signup(
          email: email, password: password, displayName: displayName,);
      credentialsStore.save(
          backendUrl: backendUrl, email: auth.user.email, token: auth.token,);
      stdout.writeln('Account created and signed in as ${auth.user.email}.');
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
    stdout.write('Display name (optional): ');
    final displayNameInput = stdin.readLineSync()?.trim() ?? '';
    final displayName = displayNameInput.isEmpty ? null : displayNameInput;
    stdout.write('Password: ');
    stdin.echoMode = false;
    final password = stdin.readLineSync() ?? '';
    stdin.echoMode = true;
    stdout.writeln();
    return runWithInputs(
        backendUrl: url, email: email, password: password, displayName: displayName,);
  }
}
