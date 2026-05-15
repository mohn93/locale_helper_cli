// packages/locale_helper_cli/lib/src/credentials.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

class Credential {
  final String email;
  final String token;
  Credential({required this.email, required this.token});
}

class CredentialsStore {
  final String homeDir;
  CredentialsStore({String? homeDir})
      : homeDir = homeDir ??
            Platform.environment['HOME'] ??
            Platform.environment['USERPROFILE'] ??
            Directory.current.path;

  String get _filePath => p.join(homeDir, '.locale_helper', 'credentials.yaml');

  Map<String, dynamic> _readAll() {
    final f = File(_filePath);
    if (!f.existsSync()) return <String, dynamic>{};
    final loaded = loadYaml(f.readAsStringSync());
    if (loaded is! Map) return <String, dynamic>{};
    return Map<String, dynamic>.from((loaded).cast<dynamic, dynamic>());
  }

  void save({required String backendUrl, required String email, required String token}) {
    final all = _readAll();
    final backends = ((all['backends'] as Map?) ?? <dynamic, dynamic>{})
        .map((k, v) => MapEntry(k.toString(), Map<String, dynamic>.from((v as Map).cast<dynamic, dynamic>())));
    backends[backendUrl] = {'email': email, 'token': token};
    final f = File(_filePath);
    f.parent.createSync(recursive: true);
    final buf = StringBuffer()
      ..writeln('default_backend: $backendUrl')
      ..writeln('backends:');
    backends.forEach((url, c) {
      buf.writeln('  $url:');
      buf.writeln('    email: ${c['email']}');
      buf.writeln('    token: ${c['token']}');
    });
    f.writeAsStringSync(buf.toString());
    if (!Platform.isWindows) {
      Process.runSync('chmod', ['600', _filePath]);
    }
  }

  Credential? read(String backendUrl) {
    final all = _readAll();
    final backends = all['backends'];
    if (backends is! Map) return null;
    final c = backends[backendUrl];
    if (c is! Map) return null;
    return Credential(email: c['email'] as String, token: c['token'] as String);
  }

  void clear(String backendUrl) {
    final all = _readAll();
    // YamlMap is unmodifiable – make a mutable copy.
    final raw = all['backends'];
    final backends = raw is Map
        ? Map<dynamic, dynamic>.from(raw)
        : <dynamic, dynamic>{};
    backends.remove(backendUrl);
    final f = File(_filePath);
    final buf = StringBuffer()..writeln('backends:');
    backends.forEach((url, c) {
      buf.writeln('  $url:');
      buf.writeln('    email: ${(c as Map)['email']}');
      buf.writeln('    token: ${c['token']}');
    });
    f.writeAsStringSync(buf.toString());
  }
}
