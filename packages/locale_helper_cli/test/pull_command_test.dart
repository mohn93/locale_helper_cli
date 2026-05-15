// packages/locale_helper_cli/test/pull_command_test.dart
import 'dart:convert';
import 'dart:io';
import 'package:locale_helper_cli/src/commands/pull_command.dart';
import 'package:locale_helper_cli/src/credentials.dart';
import 'package:locale_helper_cli/src/project_config.dart';
import 'package:test/test.dart';

void main() {
  late HttpServer server;
  late Map<String, String> receivedHeaders;

  Future<void> startServer({
    Map<String, String> currentValues = const {},
    int statusCode = 200,
  }) async {
    server = await HttpServer.bind('localhost', 0);
    server.listen((req) async {
      receivedHeaders = {};
      req.headers.forEach((name, values) {
        receivedHeaders[name.toLowerCase()] = values.first;
      });
      req.response
        ..statusCode = statusCode
        ..headers.contentType = ContentType.json
        ..write(statusCode == 200
            ? jsonEncode({'currentValues': currentValues, 'changes': []})
            : '{"error":"unauthorized"}');
      await req.response.close();
    });
  }

  tearDown(() => server.close(force: true));

  Future<Directory> setupProject({required String arbContent}) async {
    final tmp = Directory.systemTemp.createTempSync('pull_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    Directory('${tmp.path}/lib/l10n').createSync(recursive: true);
    File('${tmp.path}/lib/l10n/app_en.arb').writeAsStringSync(arbContent);
    return tmp;
  }

  Future<CredentialsStore> seededCredentials(String backendUrl) async {
    final homeDir = Directory.systemTemp.createTempSync('home_');
    addTearDown(() => homeDir.deleteSync(recursive: true));
    final store = CredentialsStore(homeDir: homeDir.path);
    store.save(backendUrl: backendUrl, email: 'dev@test.com', token: 'bearer-tok');
    return store;
  }

  test('rewrites ARB applying recorded changes in place', () async {
    await startServer(currentValues: {'hello': 'Hi there'});
    final tmp = await setupProject(arbContent: '''
{"@@locale":"en","hello":"Hello","bye":"Goodbye"}
''');
    final backendUrl = 'http://localhost:${server.port}';
    ProjectConfig(
      backendUrl: backendUrl,
      arbGlob: 'lib/l10n/app_en.arb',
      sourceLocale: 'en',
      projectId: 'p1',
    ).writeTo('${tmp.path}/.locale_helper.yaml');

    final credStore = await seededCredentials(backendUrl);
    final exitCode =
        await PullCommand(workingDir: tmp.path, credentialsStore: credStore)
            .run(const ['--apply']);
    expect(exitCode, 0);

    // Sent bearer token
    expect(receivedHeaders['authorization'], 'Bearer bearer-tok');
    expect(receivedHeaders.containsKey('x-owner-token'), isFalse);

    final updated =
        File('${tmp.path}/lib/l10n/app_en.arb').readAsStringSync();
    expect(updated, contains('"hello": "Hi there"'));
    expect(updated, contains('"bye": "Goodbye"'));
  });

  test('without --apply prints diff and does not write', () async {
    await startServer(currentValues: {'hello': 'Hi'});
    final tmp = await setupProject(arbContent: '''
{"@@locale":"en","hello":"Hello"}
''');
    final backendUrl = 'http://localhost:${server.port}';
    ProjectConfig(
      backendUrl: backendUrl,
      arbGlob: 'lib/l10n/app_en.arb',
      sourceLocale: 'en',
      projectId: 'p1',
    ).writeTo('${tmp.path}/.locale_helper.yaml');

    final credStore = await seededCredentials(backendUrl);
    final beforeMtime =
        File('${tmp.path}/lib/l10n/app_en.arb').lastModifiedSync();
    final exitCode =
        await PullCommand(workingDir: tmp.path, credentialsStore: credStore)
            .run(const []);
    expect(exitCode, 0);
    final afterMtime =
        File('${tmp.path}/lib/l10n/app_en.arb').lastModifiedSync();
    expect(afterMtime, beforeMtime);
  });

  test('exits 1 when no credentials found', () async {
    await startServer();
    final tmp = await setupProject(arbContent: '{"@@locale":"en"}');
    final backendUrl = 'http://localhost:${server.port}';
    ProjectConfig(
      backendUrl: backendUrl,
      arbGlob: 'lib/l10n/app_en.arb',
      sourceLocale: 'en',
      projectId: 'p1',
    ).writeTo('${tmp.path}/.locale_helper.yaml');

    // homeDir with NO credentials
    final homeDir = Directory.systemTemp.createTempSync('home_');
    addTearDown(() => homeDir.deleteSync(recursive: true));
    final exitCode = await PullCommand(
      workingDir: tmp.path,
      credentialsStore: CredentialsStore(homeDir: homeDir.path),
    ).run(const []);
    expect(exitCode, 1);
  });

  test('refuses --apply on conflict; --theirs applies server values', () async {
    await startServer(currentValues: {'hello': 'Hi there'});
    final tmp = await setupProject(arbContent: '''
{"@@locale":"en","hello":"Hey friend"}
''');
    // Seed a baseline that matches NEITHER local nor server, so both diverged.
    Directory('${tmp.path}/.locale_helper').createSync(recursive: true);
    File('${tmp.path}/.locale_helper/baseline.lock.json').writeAsStringSync(
      jsonEncode({
        'updatedAt': '2026-05-12T00:00:00Z',
        'values': {'hello': 'Hello'},
      }),
    );
    final backendUrl = 'http://localhost:${server.port}';
    ProjectConfig(
      backendUrl: backendUrl,
      arbGlob: 'lib/l10n/app_en.arb',
      sourceLocale: 'en',
      projectId: 'p1',
    ).writeTo('${tmp.path}/.locale_helper.yaml');

    final credStore = await seededCredentials(backendUrl);

    final refused = await PullCommand(
      workingDir: tmp.path,
      credentialsStore: credStore,
    ).run(const ['--apply']);
    expect(refused, 1, reason: 'should refuse to overwrite without --theirs/--ours');
    // ARB untouched.
    expect(
      File('${tmp.path}/lib/l10n/app_en.arb').readAsStringSync(),
      contains('"hello":"Hey friend"'),
    );

    final accepted = await PullCommand(
      workingDir: tmp.path,
      credentialsStore: credStore,
    ).run(const ['--apply', '--theirs']);
    expect(accepted, 0);
    expect(
      File('${tmp.path}/lib/l10n/app_en.arb').readAsStringSync(),
      contains('"hello": "Hi there"'),
    );
  });

  test('exits 1 on 401 response', () async {
    await startServer(statusCode: 401);
    final tmp = await setupProject(arbContent: '{"@@locale":"en"}');
    final backendUrl = 'http://localhost:${server.port}';
    ProjectConfig(
      backendUrl: backendUrl,
      arbGlob: 'lib/l10n/app_en.arb',
      sourceLocale: 'en',
      projectId: 'p1',
    ).writeTo('${tmp.path}/.locale_helper.yaml');

    final credStore = await seededCredentials(backendUrl);
    final exitCode =
        await PullCommand(workingDir: tmp.path, credentialsStore: credStore)
            .run(const []);
    expect(exitCode, 1);
  });
}
