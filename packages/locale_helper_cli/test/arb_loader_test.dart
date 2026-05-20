// packages/locale_helper_cli/test/arb_loader_test.dart
import 'dart:io';
import 'package:locale_helper_cli/src/arb_loader.dart';
import 'package:test/test.dart';

/// Returns the absolute path to the locale_helper_cli package root,
/// searching from [Directory.current] upward and downward as needed.
String _cliPackageRoot() {
  // dart test with a workspace sets CWD to the workspace root.
  // dart test from inside the package sets CWD to the package root.
  final cwd = Directory.current.path;

  // Try CWD itself first (running from inside the package).
  if (File('$cwd/pubspec.yaml').existsSync() &&
      File('$cwd/pubspec.yaml')
          .readAsStringSync()
          .contains('name: locale_helper_cli')) {
    return cwd;
  }
  // Try packages/locale_helper_cli subdirectory (workspace root invocation).
  final candidate = '$cwd/packages/locale_helper_cli';
  if (Directory(candidate).existsSync()) return candidate;

  throw StateError('Cannot locate locale_helper_cli root from $cwd');
}

void main() {
  final packageRoot = _cliPackageRoot();

  test('loadArb returns entries in source order with metadata', () {
    final arbPath =
        '$packageRoot/test/fixtures/sample_app/lib/l10n/app_en.arb';
    final entries = loadArbFile(arbPath);
    expect(entries.map((e) => e.key).toList(),
        ['appTitle', 'loginButton', 'logoutConfirm'],);
    expect(entries.first.arbMetadata['description'], 'App title');
  });
}
