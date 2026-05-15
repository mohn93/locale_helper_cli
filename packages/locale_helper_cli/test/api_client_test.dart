// packages/locale_helper_cli/test/api_client_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:locale_helper_cli/src/api_client.dart';
import 'package:locale_helper_shared/locale_helper_shared.dart';
import 'package:test/test.dart';

void main() {
  group('ApiClient bearer auth', () {
    late HttpServer server;
    late Map<String, String> receivedHeaders;

    setUp(() async {
      server = await HttpServer.bind('localhost', 0);
      server.listen((req) async {
        receivedHeaders = {};
        req.headers.forEach((name, values) {
          receivedHeaders[name.toLowerCase()] = values.first;
        });
        req.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'edits': []}));
        await req.response.close();
      });
    });

    tearDown(() => server.close(force: true));

    test('sends Authorization: Bearer header when token provided', () async {
      final api = ApiClient(
        backendUrl: 'http://localhost:${server.port}',
        token: 'my-secret-token',
      );
      await api.listAllEdits('p1');
      expect(receivedHeaders['authorization'], 'Bearer my-secret-token');
    });

    test('sends no Authorization header when token is null', () async {
      final api = ApiClient(
        backendUrl: 'http://localhost:${server.port}',
      );
      await api.listAllEdits('p1');
      expect(receivedHeaders.containsKey('authorization'), isFalse);
    });

    test('does not send X-Owner-Token header', () async {
      final api = ApiClient(
        backendUrl: 'http://localhost:${server.port}',
        token: 'tok',
      );
      await api.listAllEdits('p1');
      expect(receivedHeaders.containsKey('x-owner-token'), isFalse);
    });

    test('listAcceptedEdits sends bearer token', () async {
      final api = ApiClient(
        backendUrl: 'http://localhost:${server.port}',
        token: 'tok2',
      );
      await api.listAcceptedEdits('p1');
      expect(receivedHeaders['authorization'], 'Bearer tok2');
    });
  });

  group('ApiClient publish with bearer auth', () {
    late HttpServer server;
    late Map<String, String> receivedHeaders;

    setUp(() async {
      server = await HttpServer.bind('localhost', 0);
      server.listen((req) async {
        receivedHeaders = {};
        req.headers.forEach((name, values) {
          receivedHeaders[name.toLowerCase()] = values.first;
        });
        await utf8.decoder.bind(req).join(); // drain body
        req.response
          ..statusCode = 201
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({
            'projectId': 'p1',
            'reviewUrl': 'http://x/review/p1',
            'settingsUrl': 'http://x/settings/p1',
          }));
        await req.response.close();
      });
    });

    tearDown(() => server.close(force: true));

    test('publish sends bearer token in Authorization header', () async {
      final api = ApiClient(
        backendUrl: 'http://localhost:${server.port}',
        token: 'owner-tok',
      );
      final bundle = Bundle(
        projectId: '',
        sourceLocale: 'en',
        locales: const ['en'],
        strings: const [],
        createdAt: DateTime.utc(2026, 5, 13),
      );
      await api.publish(PublishRequest(bundle: bundle, projectName: 'Demo'));
      expect(receivedHeaders['authorization'], 'Bearer owner-tok');
      expect(receivedHeaders.containsKey('x-owner-token'), isFalse);
    });
  });
}
