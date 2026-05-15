// packages/locale_helper_cli/test/commands/login_command_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:locale_helper_cli/src/commands/login_command.dart';
import 'package:locale_helper_cli/src/commands/logout_command.dart';
import 'package:locale_helper_cli/src/commands/signup_command.dart';
import 'package:locale_helper_cli/src/credentials.dart';
import 'package:test/test.dart';

void main() {
  late HttpServer server;
  late Directory tmp;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('auth_cmd_');
    server = await HttpServer.bind('localhost', 0);
    server.listen((req) async {
      final body = await utf8.decoder.bind(req).join();
      if (req.uri.path == '/api/auth/login' && req.method == 'POST') {
        req.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({
            'token': 'tok-login',
            'user': {'id': 'u1', 'email': 'a@b.com'},
          }));
        await req.response.close();
      } else if (req.uri.path == '/api/auth/signup' && req.method == 'POST') {
        req.response
          ..statusCode = 201
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({
            'token': 'tok-signup',
            'user': {'id': 'u2', 'email': 'new@b.com'},
          }));
        await req.response.close();
      } else if (req.uri.path == '/api/auth/logout' && req.method == 'POST') {
        req.response
          ..statusCode = 200
          ..write('');
        await req.response.close();
      } else {
        req.response.statusCode = 404;
        await req.response.close();
      }
      // Suppress unused variable warning
      body.length;
    });
  });

  tearDown(() async {
    await server.close(force: true);
    tmp.deleteSync(recursive: true);
  });

  test('login stores token in credentials file', () async {
    final store = CredentialsStore(homeDir: tmp.path);
    final backendUrl = 'http://localhost:${server.port}';
    final cmd = LoginCommand(credentialsStore: store);

    final exitCode = await cmd.runWithInputs(
      backendUrl: backendUrl,
      email: 'a@b.com',
      password: 'secret',
    );

    expect(exitCode, 0);
    final cred = store.read(backendUrl);
    expect(cred, isNotNull);
    expect(cred!.token, 'tok-login');
    expect(cred.email, 'a@b.com');
  });

  test('login returns exit code 1 on server error', () async {
    final store = CredentialsStore(homeDir: tmp.path);
    // Use a port with no server listening.
    final cmd = LoginCommand(credentialsStore: store);

    final exitCode = await cmd.runWithInputs(
      backendUrl: 'http://localhost:19999',
      email: 'a@b.com',
      password: 'wrong',
    );

    expect(exitCode, 1);
  });

  test('signup stores token in credentials file', () async {
    final store = CredentialsStore(homeDir: tmp.path);
    final backendUrl = 'http://localhost:${server.port}';
    final cmd = SignupCommand(credentialsStore: store);

    final exitCode = await cmd.runWithInputs(
      backendUrl: backendUrl,
      email: 'new@b.com',
      password: 'secret',
      displayName: 'New User',
    );

    expect(exitCode, 0);
    final cred = store.read(backendUrl);
    expect(cred, isNotNull);
    expect(cred!.token, 'tok-signup');
    expect(cred.email, 'new@b.com');
  });

  test('logout clears credentials', () async {
    final store = CredentialsStore(homeDir: tmp.path);
    final backendUrl = 'http://localhost:${server.port}';
    // Pre-populate credentials.
    store.save(backendUrl: backendUrl, email: 'a@b.com', token: 'tok-login');

    final cmd = LogoutCommand(credentialsStore: store);
    final exitCode = await cmd.runWithInputs(backendUrl: backendUrl);

    expect(exitCode, 0);
    expect(store.read(backendUrl), isNull);
  });
}
