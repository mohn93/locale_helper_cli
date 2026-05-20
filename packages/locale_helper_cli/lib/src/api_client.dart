// packages/locale_helper_cli/lib/src/api_client.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:locale_helper_shared/locale_helper_shared.dart';

class ApiClient {
  final String backendUrl;
  final http.Client httpClient;
  final String? token;

  ApiClient({required this.backendUrl, http.Client? httpClient, this.token})
      : httpClient = httpClient ?? http.Client();

  Map<String, String> get _authHeaders =>
      token != null ? {'authorization': 'Bearer $token'} : {};

  Future<AuthResponse> signup({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final resp = await httpClient.post(
      Uri.parse('$backendUrl/api/auth/signup'),
      headers: {'content-type': 'application/json', ..._authHeaders},
      body: jsonEncode(
          SignupRequest(email: email, password: password, displayName: displayName)
              .toJson(),),
    );
    if (resp.statusCode != 201) {
      throw StateError('signup failed: ${resp.statusCode} ${resp.body}');
    }
    return AuthResponse.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final resp = await httpClient.post(
      Uri.parse('$backendUrl/api/auth/login'),
      headers: {'content-type': 'application/json', ..._authHeaders},
      body: jsonEncode(LoginRequest(email: email, password: password).toJson()),
    );
    if (resp.statusCode != 200) {
      throw StateError('login failed: ${resp.statusCode} ${resp.body}');
    }
    return AuthResponse.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  Future<void> logout(String token) async {
    await httpClient.post(
      Uri.parse('$backendUrl/api/auth/logout'),
      headers: {'authorization': 'Bearer $token', ..._authHeaders},
    );
  }

  Future<PublishResponse> publish(PublishRequest request) async {
    final resp = await httpClient.post(
      Uri.parse('$backendUrl/api/projects'),
      headers: {
        'content-type': 'application/json',
        ..._authHeaders,
      },
      body: jsonEncode(request.toJson()),
    );
    if (resp.statusCode == 401) {
      throw StateError('401');
    }
    if (resp.statusCode == 403) {
      throw StateError('403');
    }
    if (resp.statusCode != 201 && resp.statusCode != 200) {
      throw StateError('publish failed: ${resp.statusCode} ${resp.body}');
    }
    return PublishResponse.fromJson(
        jsonDecode(resp.body) as Map<String, dynamic>,);
  }

  /// Fetch the current values map from the project's change log.
  /// Returns a nested map `{locale: {stringKey: currentValue}}` covering every
  /// key in every locale that has at least one recorded change (suggestion
  /// accept, direct edit, or publish-recorded diff).
  ///
  /// Also accepts the legacy flat shape `{stringKey: currentValue}` (older
  /// servers) by wrapping it under the [fallbackLocale] (default `en`).
  Future<Map<String, Map<String, String>>> currentValues(
    String projectId, {
    String fallbackLocale = 'en',
  }) async {
    final resp = await httpClient.get(
      Uri.parse('$backendUrl/api/projects/$projectId/changes'),
      headers: {..._authHeaders},
    );
    if (resp.statusCode == 401) throw StateError('401');
    if (resp.statusCode == 403) throw StateError('403');
    if (resp.statusCode != 200) {
      throw StateError('list changes failed: ${resp.statusCode}');
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final raw = (body['currentValues'] as Map).cast<String, dynamic>();
    if (raw.isEmpty) return const {};
    // Detect legacy flat shape (values are strings, not maps).
    final isLegacy = raw.values.any((v) => v is String);
    if (isLegacy) {
      return {
        fallbackLocale: raw.map((k, v) => MapEntry(k, v as String)),
      };
    }
    return {
      for (final e in raw.entries)
        e.key: (e.value as Map)
            .cast<String, dynamic>()
            .map((k, v) => MapEntry(k, v as String)),
    };
  }

  Future<List<Edit>> listAcceptedEdits(String projectId) async {
    final resp = await httpClient.get(
      Uri.parse('$backendUrl/api/projects/$projectId/edits'),
      headers: {..._authHeaders},
    );
    if (resp.statusCode == 401) {
      throw StateError('401');
    }
    if (resp.statusCode == 403) {
      throw StateError('403');
    }
    if (resp.statusCode != 200) {
      throw StateError('list edits failed: ${resp.statusCode}');
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final all = (body['edits'] as List).cast<Map<String, dynamic>>();
    return all
        .map(Edit.fromJson)
        .where((e) => e.status == EditStatus.accepted)
        .toList();
  }

  Future<List<Edit>> listAllEdits(String projectId) async {
    final resp = await httpClient.get(
      Uri.parse('$backendUrl/api/projects/$projectId/edits'),
      headers: {..._authHeaders},
    );
    if (resp.statusCode == 401) {
      throw StateError('401');
    }
    if (resp.statusCode == 403) {
      throw StateError('403');
    }
    if (resp.statusCode != 200) {
      throw StateError('list edits failed: ${resp.statusCode}');
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    return (body['edits'] as List)
        .cast<Map<String, dynamic>>()
        .map(Edit.fromJson)
        .toList();
  }

  Future<List<ProjectListItemDto>> listMyProjects() async {
    final resp = await httpClient.get(
      Uri.parse('$backendUrl/api/projects'),
      headers: {..._authHeaders},
    );
    if (resp.statusCode == 401) {
      throw StateError('401');
    }
    if (resp.statusCode == 403) {
      throw StateError('403');
    }
    if (resp.statusCode != 200) {
      throw StateError('list projects failed: ${resp.statusCode} ${resp.body}');
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    return (body['projects'] as List)
        .cast<Map<String, dynamic>>()
        .map(ProjectListItemDto.fromJson)
        .toList();
  }
}
