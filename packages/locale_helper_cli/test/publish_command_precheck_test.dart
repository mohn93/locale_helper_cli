// packages/locale_helper_cli/test/publish_command_precheck_test.dart
//
// Pre-check coverage: publish should refuse to overwrite diverging server
// changes unless --force is passed, and should write baseline.lock.json after
// success.
import 'dart:convert';
import 'dart:io';

import 'package:locale_helper_cli/src/baseline_lock.dart';
import 'package:locale_helper_cli/src/commands/publish_command.dart';
import 'package:locale_helper_cli/src/credentials.dart';
import 'package:locale_helper_cli/src/project_config.dart';
import 'package:test/test.dart';

void main() {
  late HttpServer server;
  late int postCount;
  late Map<String, String> serverCurrentValues;

  setUp(() async {
    postCount = 0;
    serverCurrentValues = const <String, String>{};
    server = await HttpServer.bind('localhost', 0);
    server.listen((req) async {
      if (req.method == 'GET' && req.uri.path.endsWith('/changes')) {
        req.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({
            'currentValues': serverCurrentValues,
            'changes': const <Map<String, dynamic>>[],
          }),);
        await req.response.close();
        return;
      }
      if (req.method == 'POST' && req.uri.path == '/api/projects') {
        postCount++;
        // Drain body.
        await utf8.decoder.bind(req).join();
        req.response
          ..statusCode = 201
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({
            'projectId': 'existing-p1',
            'reviewUrl': 'http://x/review/p1',
            'settingsUrl': 'http://x/settings/p1',
          }),);
        await req.response.close();
        return;
      }
      req.response.statusCode = 404;
      await req.response.close();
    });
  });

  tearDown(() => server.close(force: true));

  Future<Directory> setupProject({
    required String arbContent,
    String? projectId,
  }) async {
    final tmp = Directory.systemTemp.createTempSync('publish_precheck_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    Directory('${tmp.path}/lib/l10n').createSync(recursive: true);
    File('${tmp.path}/lib/l10n/app_en.arb').writeAsStringSync(arbContent);
    File('${tmp.path}/lib/main.dart').writeAsStringSync('// no usages\n');
    ProjectConfig(
      backendUrl: 'http://localhost:${server.port}',
      arbGlob: 'lib/l10n/app_en.arb',
      sourceLocale: 'en',
      projectId: projectId,
    ).writeTo('${tmp.path}/.locale_helper.yaml');
    return tmp;
  }

  CredentialsStore seededCredentials(String backendUrl) {
    final homeDir = Directory.systemTemp.createTempSync('home_');
    addTearDown(() => homeDir.deleteSync(recursive: true));
    final store = CredentialsStore(homeDir: homeDir.path);
    store.save(backendUrl: backendUrl, email: 'dev@test.com', token: 'tok');
    return store;
  }

  void writeBaseline(String workingDir, Map<String, String> values) {
    Directory('$workingDir/.locale_helper').createSync(recursive: true);
    File('$workingDir/.locale_helper/baseline.lock.json').writeAsStringSync(
      jsonEncode({
        'updatedAt': '2026-05-12T00:00:00Z',
        'values': values,
      }),
    );
  }

  test('refuses to publish (exit 1, no POST) when server diverges from baseline',
      () async {
    // Baseline = "Hello", server moved to "Hi there", local moved to "Hey".
    // Both sides changed, to different values -> conflict.
    serverCurrentValues = {'hello': 'Hi there'};
    final tmp = await setupProject(
      arbContent: '{"@@locale":"en","hello":"Hey"}\n',
      projectId: 'existing-p1',
    );
    writeBaseline(tmp.path, {'hello': 'Hello'});

    final backendUrl = 'http://localhost:${server.port}';
    final credStore = seededCredentials(backendUrl);

    final exitCode = await PublishCommand(
      workingDir: tmp.path,
      credentialsStore: credStore,
    ).run(const []);

    expect(exitCode, 1);
    expect(postCount, 0, reason: 'POST /api/projects must NOT be issued');
  });

  test('--force lets publish proceed despite divergence', () async {
    serverCurrentValues = {'hello': 'Hi there'};
    final tmp = await setupProject(
      arbContent: '{"@@locale":"en","hello":"Hey"}\n',
      projectId: 'existing-p1',
    );
    writeBaseline(tmp.path, {'hello': 'Hello'});

    final backendUrl = 'http://localhost:${server.port}';
    final credStore = seededCredentials(backendUrl);

    final exitCode = await PublishCommand(
      workingDir: tmp.path,
      credentialsStore: credStore,
    ).run(const ['--force']);

    expect(exitCode, 0);
    expect(postCount, 1, reason: 'POST must be sent with --force');
  });

  test('no baseline -> skips pre-check and publishes normally', () async {
    // Server has a value, local has a different one — would normally look
    // like divergence — but with no baseline the pre-check is skipped.
    serverCurrentValues = {'hello': 'Hi there'};
    final tmp = await setupProject(
      arbContent: '{"@@locale":"en","hello":"Hey"}\n',
      projectId: 'existing-p1',
    );
    // No baseline written.
    expect(
      File('${tmp.path}/.locale_helper/baseline.lock.json').existsSync(),
      isFalse,
    );

    final backendUrl = 'http://localhost:${server.port}';
    final credStore = seededCredentials(backendUrl);

    final exitCode = await PublishCommand(
      workingDir: tmp.path,
      credentialsStore: credStore,
    ).run(const []);

    expect(exitCode, 0);
    expect(postCount, 1);
  });

  test('baseline.lock.json is written after successful publish', () async {
    serverCurrentValues = const <String, String>{};
    final tmp = await setupProject(
      arbContent: '{"@@locale":"en","hello":"Hello","bye":"Goodbye"}\n',
    );
    final backendUrl = 'http://localhost:${server.port}';
    final credStore = seededCredentials(backendUrl);

    expect(
      File('${tmp.path}/.locale_helper/baseline.lock.json').existsSync(),
      isFalse,
    );

    final exitCode = await PublishCommand(
      workingDir: tmp.path,
      credentialsStore: credStore,
    ).run(const []);
    expect(exitCode, 0);

    final baseline = BaselineLock.read(tmp.path);
    expect(baseline, isNotNull);
    expect(baseline!.values, {'hello': 'Hello', 'bye': 'Goodbye'});
  });
}
