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

  group('ApiClient listMyProjects', () {
    late HttpServer server;

    setUp(() async {
      server = await HttpServer.bind('localhost', 0);
      server.listen((req) async {
        req.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({
            'projects': [
              {
                'id': 'a',
                'name': 'Alpha',
                'myRole': 'owner',
                'unreviewedCount': 0,
                'updatedAt': '2026-01-01T00:00:00Z',
              },
              {
                'id': 'b',
                'name': 'Beta',
                'myRole': 'reviewer',
                'unreviewedCount': 3,
                'updatedAt': '2026-02-01T00:00:00Z',
              },
            ],
          }));
        await req.response.close();
      });
    });

    tearDown(() => server.close(force: true));

    test('returns parsed list from /api/projects', () async {
      final api = ApiClient(
        backendUrl: 'http://localhost:${server.port}',
        token: 'tok',
      );

      final list = await api.listMyProjects();

      expect(list.length, 2);
      expect(list[0].id, 'a');
      expect(list[0].name, 'Alpha');
      expect(list[0].myRole, 'owner');
      expect(list[0].unreviewedCount, 0);
      expect(list[1].id, 'b');
      expect(list[1].name, 'Beta');
      expect(list[1].myRole, 'reviewer');
      expect(list[1].unreviewedCount, 3);
    });

    test('throws StateError on 401', () async {
      server.close(force: true);
      server = await HttpServer.bind('localhost', 0);
      server.listen((req) async {
        req.response.statusCode = 401;
        await req.response.close();
      });

      final api = ApiClient(
        backendUrl: 'http://localhost:${server.port}',
        token: 'tok',
      );

      expect(api.listMyProjects, throwsStateError);
    });

    test('throws StateError on 403', () async {
      server.close(force: true);
      server = await HttpServer.bind('localhost', 0);
      server.listen((req) async {
        req.response.statusCode = 403;
        await req.response.close();
      });

      final api = ApiClient(
        backendUrl: 'http://localhost:${server.port}',
        token: 'tok',
      );

      expect(api.listMyProjects, throwsStateError);
    });
  });
}
