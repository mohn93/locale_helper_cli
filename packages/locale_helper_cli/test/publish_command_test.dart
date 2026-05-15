// packages/locale_helper_cli/test/publish_command_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:locale_helper_cli/src/commands/publish_command.dart';
import 'package:locale_helper_cli/src/credentials.dart';
import 'package:locale_helper_cli/src/project_config.dart';
import 'package:test/test.dart';

void main() {
  late HttpServer server;
  late Map<String, dynamic> receivedBody;
  late Map<String, String> receivedHeaders;
  int serverStatusCode = 201;

  setUp(() async {
    serverStatusCode = 201;
    server = await HttpServer.bind('localhost', 0);
    server.listen((req) async {
      receivedHeaders = {};
      req.headers.forEach((name, values) {
        receivedHeaders[name.toLowerCase()] = values.first;
      });
      if (req.uri.path == '/api/projects' && req.method == 'POST') {
        final body = await utf8.decoder.bind(req).join();
        receivedBody = jsonDecode(body) as Map<String, dynamic>;
        req.response
          ..statusCode = serverStatusCode
          ..headers.contentType = ContentType.json
          ..write(serverStatusCode == 201
              ? jsonEncode({
                  'projectId': 'p1',
                  'reviewUrl': 'http://x/review/p1',
                  'settingsUrl': 'http://x/settings/p1',
                })
              : '{"error":"unauthorized"}');
        await req.response.close();
      } else if (req.uri.path.endsWith('/changes')) {
        // Pre-check endpoint used by the conflict-detection pre-check.
        req.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'currentValues': const <String, String>{}, 'changes': []}));
        await req.response.close();
      } else {
        req.response.statusCode = 404;
        await req.response.close();
      }
    });
  });

  tearDown(() => server.close(force: true));

  Future<Directory> setupProject({
    bool withProjectId = false,
    String? projectName,
  }) async {
    final tmp = Directory.systemTemp.createTempSync('publish_e2e_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    Directory('${tmp.path}/lib/l10n').createSync(recursive: true);
    File('${tmp.path}/lib/l10n/app_en.arb').writeAsStringSync('''
{"@@locale":"en","hello":"Hello"}
''');
    File('${tmp.path}/lib/main.dart').writeAsStringSync('''
class AppLocalizations { static AppLocalizations of(Object c) => AppLocalizations(); String get hello => ''; }
class Greeter { String build(Object c) => AppLocalizations.of(c).hello; }
''');
    ProjectConfig(
      backendUrl: 'http://localhost:${server.port}',
      arbGlob: 'lib/l10n/app_en.arb',
      sourceLocale: 'en',
      projectId: withProjectId ? 'existing-p1' : null,
      projectName: projectName,
    ).writeTo('${tmp.path}/.locale_helper.yaml');
    return tmp;
  }

  test('publish reads ARB + scans usages + writes back projectId', () async {
    final tmp = await setupProject();
    // Seed credentials
    final homeDir = Directory.systemTemp.createTempSync('home_');
    addTearDown(() => homeDir.deleteSync(recursive: true));
    CredentialsStore(homeDir: homeDir.path).save(
      backendUrl: 'http://localhost:${server.port}',
      email: 'dev@test.com',
      token: 'bearer-tok',
    );

    final command = PublishCommand(
      workingDir: tmp.path,
      credentialsStore: CredentialsStore(homeDir: homeDir.path),
    );
    final exitCode = await command.run(const []);
    expect(exitCode, 0);

    // Sent bearer token in Authorization header
    expect(receivedHeaders['authorization'], 'Bearer bearer-tok');
    expect(receivedHeaders.containsKey('x-owner-token'), isFalse);

    // Body has projectName and bundle
    expect(receivedBody['projectName'], isNotEmpty);
    final bundle = receivedBody['bundle'] as Map<String, dynamic>;
    expect((bundle['strings'] as List).first['key'], 'hello');
    expect((bundle['strings'] as List).first['usages'], isNotEmpty);

    // projectId written back to config
    final cfg = ProjectConfig.load('${tmp.path}/.locale_helper.yaml');
    expect(cfg.projectId, 'p1');
  });

  test('publish includes existing projectId in request body', () async {
    final tmp = await setupProject(withProjectId: true);
    final homeDir = Directory.systemTemp.createTempSync('home_');
    addTearDown(() => homeDir.deleteSync(recursive: true));
    CredentialsStore(homeDir: homeDir.path).save(
      backendUrl: 'http://localhost:${server.port}',
      email: 'dev@test.com',
      token: 'tok',
    );

    final command = PublishCommand(
      workingDir: tmp.path,
      credentialsStore: CredentialsStore(homeDir: homeDir.path),
    );
    final exitCode = await command.run(const []);
    expect(exitCode, 0);
    expect(receivedBody['projectId'], 'existing-p1');
  });

  test('publish exits 1 with message when no credentials found', () async {
    final tmp = await setupProject();
    // homeDir with NO saved credentials
    final homeDir = Directory.systemTemp.createTempSync('home_');
    addTearDown(() => homeDir.deleteSync(recursive: true));

    final command = PublishCommand(
      workingDir: tmp.path,
      credentialsStore: CredentialsStore(homeDir: homeDir.path),
    );
    final exitCode = await command.run(const []);
    expect(exitCode, 1);
  });

  test('publish exits 1 on 401 response', () async {
    serverStatusCode = 401;
    final tmp = await setupProject();
    final homeDir = Directory.systemTemp.createTempSync('home_');
    addTearDown(() => homeDir.deleteSync(recursive: true));
    CredentialsStore(homeDir: homeDir.path).save(
      backendUrl: 'http://localhost:${server.port}',
      email: 'dev@test.com',
      token: 'bad-tok',
    );

    final command = PublishCommand(
      workingDir: tmp.path,
      credentialsStore: CredentialsStore(homeDir: homeDir.path),
    );
    final exitCode = await command.run(const []);
    expect(exitCode, 1);
  });

  test('publish exits 1 on 403 response', () async {
    serverStatusCode = 403;
    final tmp = await setupProject();
    final homeDir = Directory.systemTemp.createTempSync('home_');
    addTearDown(() => homeDir.deleteSync(recursive: true));
    CredentialsStore(homeDir: homeDir.path).save(
      backendUrl: 'http://localhost:${server.port}',
      email: 'dev@test.com',
      token: 'not-owner-tok',
    );

    final command = PublishCommand(
      workingDir: tmp.path,
      credentialsStore: CredentialsStore(homeDir: homeDir.path),
    );
    final exitCode = await command.run(const []);
    expect(exitCode, 1);
  });
}
