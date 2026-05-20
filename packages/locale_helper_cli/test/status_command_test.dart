// packages/locale_helper_cli/test/status_command_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:locale_helper_cli/src/commands/status_command.dart';
import 'package:locale_helper_cli/src/credentials.dart';
import 'package:locale_helper_cli/src/project_config.dart';
import 'package:test/test.dart';

void main() {
  late Map<String, String> receivedHeaders;

  Future<HttpServer> startServer({int statusCode = 200}) async {
    final server = await HttpServer.bind('localhost', 0);
    server.listen((req) async {
      receivedHeaders = {};
      req.headers.forEach((name, values) {
        receivedHeaders[name.toLowerCase()] = values.first;
      });
      req.response
        ..statusCode = statusCode
        ..headers.contentType = ContentType.json
        ..write(statusCode == 200
            ? jsonEncode({
                'edits': [
                  {
                    'id': '1',
                    'projectId': 'p1',
                    'key': 'a',
                    'proposedValue': 'x',
                    'status': 'pending',
                    'createdAt': '2026-05-12T00:00:00Z',
                  },
                  {
                    'id': '2',
                    'projectId': 'p1',
                    'key': 'b',
                    'proposedValue': 'y',
                    'status': 'accepted',
                    'createdAt': '2026-05-12T00:00:00Z',
                  },
                ],
              })
            : '{"error":"unauthorized"}',);
      await req.response.close();
    });
    return server;
  }

  test('prints counts and review URL, sends bearer token', () async {
    final server = await startServer();
    addTearDown(() => server.close(force: true));

    final tmp = Directory.systemTemp.createTempSync('status_');
    addTearDown(() => tmp.deleteSync(recursive: true));

    final backendUrl = 'http://localhost:${server.port}';
    ProjectConfig(
      backendUrl: backendUrl,
      arbGlob: 'lib/l10n/app_en.arb',
      sourceLocale: 'en',
      projectId: 'p1',
    ).writeTo('${tmp.path}/.locale_helper.yaml');

    final homeDir = Directory.systemTemp.createTempSync('home_');
    addTearDown(() => homeDir.deleteSync(recursive: true));
    final credStore = CredentialsStore(homeDir: homeDir.path);
    credStore.save(backendUrl: backendUrl, email: 'dev@test.com', token: 'bearer-tok');

    final buffer = StringBuffer();
    final sink = _StringBufferSink(buffer);

    final exitCode = await StatusCommand(
      workingDir: tmp.path,
      out: sink,
      credentialsStore: credStore,
    ).run(const []);
    expect(exitCode, 0);

    // Sent bearer token
    expect(receivedHeaders['authorization'], 'Bearer bearer-tok');
    expect(receivedHeaders.containsKey('x-owner-token'), isFalse);

    final output = buffer.toString();
    expect(output, contains('pending=1'));
    expect(output, contains('accepted=1'));
    expect(output, contains('rejected=0'));
    expect(output, contains('/review/p1'));
  });

  test('exits 1 when no credentials found', () async {
    final server = await startServer();
    addTearDown(() => server.close(force: true));

    final tmp = Directory.systemTemp.createTempSync('status_');
    addTearDown(() => tmp.deleteSync(recursive: true));

    final backendUrl = 'http://localhost:${server.port}';
    ProjectConfig(
      backendUrl: backendUrl,
      arbGlob: 'lib/l10n/app_en.arb',
      sourceLocale: 'en',
      projectId: 'p1',
    ).writeTo('${tmp.path}/.locale_helper.yaml');

    // no credentials saved
    final homeDir = Directory.systemTemp.createTempSync('home_');
    addTearDown(() => homeDir.deleteSync(recursive: true));

    final exitCode = await StatusCommand(
      workingDir: tmp.path,
      credentialsStore: CredentialsStore(homeDir: homeDir.path),
    ).run(const []);
    expect(exitCode, 1);
  });

  test('exits 1 on 401 response', () async {
    final server = await startServer(statusCode: 401);
    addTearDown(() => server.close(force: true));

    final tmp = Directory.systemTemp.createTempSync('status_');
    addTearDown(() => tmp.deleteSync(recursive: true));

    final backendUrl = 'http://localhost:${server.port}';
    ProjectConfig(
      backendUrl: backendUrl,
      arbGlob: 'lib/l10n/app_en.arb',
      sourceLocale: 'en',
      projectId: 'p1',
    ).writeTo('${tmp.path}/.locale_helper.yaml');

    final homeDir = Directory.systemTemp.createTempSync('home_');
    addTearDown(() => homeDir.deleteSync(recursive: true));
    final credStore = CredentialsStore(homeDir: homeDir.path);
    credStore.save(backendUrl: backendUrl, email: 'dev@test.com', token: 'bad-tok');

    final exitCode = await StatusCommand(
      workingDir: tmp.path,
      credentialsStore: credStore,
    ).run(const []);
    expect(exitCode, 1);
  });
}

/// A minimal [IOSink] that writes to a [StringBuffer] for testing.
class _StringBufferSink implements IOSink {
  final StringBuffer _buf;
  _StringBufferSink(this._buf);

  @override
  void writeln([Object? obj = '']) => _buf.writeln(obj);

  @override
  void write(Object? obj) => _buf.write(obj);

  @override
  void writeAll(Iterable objects, [String separator = '']) =>
      _buf.writeAll(objects, separator);

  @override
  void writeCharCode(int charCode) => _buf.writeCharCode(charCode);

  @override
  void add(List<int> data) {}

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future addStream(Stream<List<int>> stream) async {}

  @override
  Future get done async {}

  @override
  Future flush() async {}

  @override
  Future close() async {}

  @override
  Encoding get encoding => utf8;

  @override
  set encoding(Encoding value) {}
}
