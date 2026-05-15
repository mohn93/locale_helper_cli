// packages/locale_helper_cli/test/credentials_test.dart
import 'dart:io';
import 'package:locale_helper_cli/src/credentials.dart';
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('cred_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('write + read round-trip', () {
    final store = CredentialsStore(homeDir: tmp.path);
    store.save(backendUrl: 'http://api', email: 'a@b.com', token: 't1');
    final cred = store.read('http://api');
    expect(cred?.token, 't1');
    expect(cred?.email, 'a@b.com');
  });

  test('reading missing backend returns null', () {
    final store = CredentialsStore(homeDir: tmp.path);
    expect(store.read('http://api'), isNull);
  });

  test('save sets file mode 0600 on Unix', () {
    if (Platform.isWindows) return; // skip
    final store = CredentialsStore(homeDir: tmp.path);
    store.save(backendUrl: 'http://api', email: 'a@b.com', token: 't1');
    final stat = File('${tmp.path}/.locale_helper/credentials.yaml').statSync();
    // modeString() on macOS returns 9-char form (e.g. "rw-------"); on Linux
    // it may be 10-char with a leading type character. Normalise to last 9 chars.
    final mode = stat.modeString();
    expect(mode.substring(mode.length - 9), 'rw-------');
  });

  test('clear removes only the specified backend', () {
    final store = CredentialsStore(homeDir: tmp.path);
    store.save(backendUrl: 'http://a', email: 'x@x', token: 't1');
    store.save(backendUrl: 'http://b', email: 'y@y', token: 't2');
    store.clear('http://a');
    expect(store.read('http://a'), isNull);
    expect(store.read('http://b'), isNotNull);
  });
}
