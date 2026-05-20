// packages/locale_helper_cli/test/pull_command_conflict_test.dart
//
// Conflict-detection + 3-way diff cases for `locale_helper pull`.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:locale_helper_cli/src/baseline_lock.dart';
import 'package:locale_helper_cli/src/commands/pull_command.dart';
import 'package:locale_helper_cli/src/credentials.dart';
import 'package:locale_helper_cli/src/project_config.dart';
import 'package:test/test.dart';

void main() {
  late HttpServer server;

  Future<void> startServer({
    Map<String, String> currentValues = const {},
    int statusCode = 200,
  }) async {
    server = await HttpServer.bind('localhost', 0);
    server.listen((req) async {
      req.response
        ..statusCode = statusCode
        ..headers.contentType = ContentType.json
        ..write(statusCode == 200
            ? jsonEncode({'currentValues': currentValues, 'changes': []})
            : '{"error":"server"}',);
      await req.response.close();
    });
  }

  tearDown(() => server.close(force: true));

  Future<Directory> setupProject({required String arbContent}) async {
    final tmp = Directory.systemTemp.createTempSync('pull_conflict_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    Directory('${tmp.path}/lib/l10n').createSync(recursive: true);
    File('${tmp.path}/lib/l10n/app_en.arb').writeAsStringSync(arbContent);
    return tmp;
  }

  Future<CredentialsStore> seededCredentials(String backendUrl) async {
    final homeDir = Directory.systemTemp.createTempSync('home_');
    addTearDown(() => homeDir.deleteSync(recursive: true));
    final store = CredentialsStore(homeDir: homeDir.path);
    store.save(
        backendUrl: backendUrl, email: 'dev@test.com', token: 'bearer-tok',);
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

  ProjectConfig writeConfig(Directory tmp, String backendUrl) {
    final cfg = ProjectConfig(
      backendUrl: backendUrl,
      arbGlob: 'lib/l10n/app_en.arb',
      sourceLocale: 'en',
      projectId: 'p1',
    );
    cfg.writeTo('${tmp.path}/.locale_helper.yaml');
    return cfg;
  }

  // ----- All in sync -----
  test('all-in-sync: server matches baseline -> Nothing to apply, exit 0',
      () async {
    await startServer(currentValues: {'hello': 'Hello'});
    final tmp = await setupProject(arbContent: '''
{"@@locale":"en","hello":"Hello"}
''',);
    writeBaseline(tmp.path, {'hello': 'Hello'});
    final backendUrl = 'http://localhost:${server.port}';
    writeConfig(tmp, backendUrl);
    final credStore = await seededCredentials(backendUrl);

    final output = StringBuffer();
    final exitCode = await runZoned(
      () => PullCommand(workingDir: tmp.path, credentialsStore: credStore)
          .run(const ['--apply']),
      zoneSpecification: ZoneSpecification(
        print: (_, __, ___, line) => output.writeln(line),
      ),
    );
    expect(exitCode, 0);
    // ARB untouched
    expect(
      File('${tmp.path}/lib/l10n/app_en.arb').readAsStringSync(),
      contains('"hello":"Hello"'),
    );
  });

  // ----- Incoming only + baseline file written after --apply -----
  test(
      'incoming-only with --apply writes baseline.lock.json afterwards',
      () async {
    await startServer(currentValues: {'hello': 'Hi there'});
    final tmp = await setupProject(arbContent: '''
{"@@locale":"en","hello":"Hello"}
''',);
    // Baseline matches current local.
    writeBaseline(tmp.path, {'hello': 'Hello'});
    final backendUrl = 'http://localhost:${server.port}';
    writeConfig(tmp, backendUrl);
    final credStore = await seededCredentials(backendUrl);

    final exitCode =
        await PullCommand(workingDir: tmp.path, credentialsStore: credStore)
            .run(const ['--apply']);
    expect(exitCode, 0);

    // ARB updated with server value.
    expect(
      File('${tmp.path}/lib/l10n/app_en.arb').readAsStringSync(),
      contains('"hello": "Hi there"'),
    );

    // Baseline file refreshed with the new value.
    final newBaseline = BaselineLock.read(tmp.path);
    expect(newBaseline, isNotNull);
    expect(newBaseline!.values['hello'], 'Hi there');
  });

  // ----- Local-only -----
  test('local-only: key changed locally, server unchanged -> not modified',
      () async {
    // Server still has the baseline value.
    await startServer(currentValues: {'hello': 'Hello'});
    final tmp = await setupProject(arbContent: '''
{"@@locale":"en","hello":"Howdy partner"}
''',);
    writeBaseline(tmp.path, {'hello': 'Hello'});
    final backendUrl = 'http://localhost:${server.port}';
    writeConfig(tmp, backendUrl);
    final credStore = await seededCredentials(backendUrl);

    // Capture stdout via stdoutOverride zone.
    final output = StringBuffer();
    final exitCode = await IOOverrides.runZoned(
      () => PullCommand(workingDir: tmp.path, credentialsStore: credStore)
          .run(const []),
      stdout: () => _CapturingStdout(output),
    );
    expect(exitCode, 0);
    expect(output.toString(), contains('Local-only'));

    // ARB untouched (we didn't pass --apply, and local-only keys aren't
    // modified anyway).
    expect(
      File('${tmp.path}/lib/l10n/app_en.arb').readAsStringSync(),
      contains('"hello":"Howdy partner"'),
    );
  });

  // ----- Missing locally -----
  test(
      'missing-locally: key in baseline + server but not in ARB -> '
      'printed and not auto-added even with --apply', () async {
    await startServer(currentValues: {'hello': 'Hello', 'extra': 'Surprise'});
    // ARB has only "hello".
    final tmp = await setupProject(arbContent: '''
{"@@locale":"en","hello":"Hello"}
''',);
    // Baseline says "extra" used to exist.
    writeBaseline(tmp.path, {'hello': 'Hello', 'extra': 'Surprise'});
    final backendUrl = 'http://localhost:${server.port}';
    writeConfig(tmp, backendUrl);
    final credStore = await seededCredentials(backendUrl);

    final output = StringBuffer();
    final exitCode = await IOOverrides.runZoned(
      () => PullCommand(workingDir: tmp.path, credentialsStore: credStore)
          .run(const ['--apply']),
      stdout: () => _CapturingStdout(output),
    );
    expect(exitCode, 0);
    expect(output.toString(), contains('Missing locally'));

    // ARB should NOT have gained "extra".
    final arbBody = File('${tmp.path}/lib/l10n/app_en.arb').readAsStringSync();
    expect(arbBody, isNot(contains('"extra"')));
  });

  // ----- Conflict + --ours -----
  test('conflict + --ours keeps local value, exit 0', () async {
    await startServer(currentValues: {'hello': 'Hi there'});
    final tmp = await setupProject(arbContent: '''
{"@@locale":"en","hello":"Hey friend"}
''',);
    writeBaseline(tmp.path, {'hello': 'Hello'}); // diverges from both sides
    final backendUrl = 'http://localhost:${server.port}';
    writeConfig(tmp, backendUrl);
    final credStore = await seededCredentials(backendUrl);

    final exitCode =
        await PullCommand(workingDir: tmp.path, credentialsStore: credStore)
            .run(const ['--apply', '--ours']);
    expect(exitCode, 0);

    final arbBody = File('${tmp.path}/lib/l10n/app_en.arb').readAsStringSync();
    expect(arbBody, contains('"hello": "Hey friend"'));
    expect(arbBody, isNot(contains('"Hi there"')));

    // Baseline should also be refreshed.
    final newBaseline = BaselineLock.read(tmp.path);
    expect(newBaseline, isNotNull);
    expect(newBaseline!.values['hello'], 'Hey friend');
  });

  // ----- --theirs + --ours mutually exclusive -----
  test('--theirs and --ours together exits 2 with error', () async {
    await startServer(currentValues: {'hello': 'Hi'});
    final tmp = await setupProject(arbContent: '''
{"@@locale":"en","hello":"Hello"}
''',);
    final backendUrl = 'http://localhost:${server.port}';
    writeConfig(tmp, backendUrl);
    final credStore = await seededCredentials(backendUrl);

    final exitCode =
        await PullCommand(workingDir: tmp.path, credentialsStore: credStore)
            .run(const ['--apply', '--theirs', '--ours']);
    expect(exitCode, 2);
  });
}

/// Minimal stdout that lets tests capture writes without spamming the console.
class _CapturingStdout implements Stdout {
  _CapturingStdout(this._buf);
  final StringBuffer _buf;

  @override
  void writeln([Object? obj = '']) => _buf.writeln(obj);
  @override
  void write(Object? obj) => _buf.write(obj);
  @override
  void writeAll(Iterable objects, [String sep = '']) =>
      _buf.writeAll(objects, sep);
  @override
  void writeCharCode(int charCode) => _buf.writeCharCode(charCode);

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
