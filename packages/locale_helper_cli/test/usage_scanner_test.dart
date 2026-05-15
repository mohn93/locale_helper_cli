// packages/locale_helper_cli/test/usage_scanner_test.dart
import 'dart:io';
import 'package:locale_helper_cli/src/usage_scanner.dart';
import 'package:locale_helper_shared/locale_helper_shared.dart';
import 'package:test/test.dart';

String _cliPackageRoot() {
  final cwd = Directory.current.path;
  if (File('$cwd/pubspec.yaml').existsSync() &&
      File('$cwd/pubspec.yaml')
          .readAsStringSync()
          .contains('name: locale_helper_cli')) {
    return cwd;
  }
  final candidate = '$cwd/packages/locale_helper_cli';
  if (Directory(candidate).existsSync()) return candidate;
  throw StateError('Cannot locate locale_helper_cli root from $cwd');
}

void main() {
  test('scans sample_app for known keys', () async {
    final packageRoot = _cliPackageRoot();
    final scanner = UsageScanner(
      rootDir: '$packageRoot/test/fixtures/sample_app',
      typePatterns: const ['AppLocalizations'],
    );
    final usagesByKey = await scanner.scan(
      keys: const {'appTitle', 'loginButton', 'logoutConfirm', 'unused'},
    );
    expect(usagesByKey['appTitle']!.first.surroundingWidget, 'LoginPage');
    expect(usagesByKey['loginButton'], hasLength(1));
    expect(usagesByKey['logoutConfirm']!.first.surroundingWidget, 'LogoutDialog');
    expect(usagesByKey['unused'], isEmpty);
    expect(usagesByKey['appTitle']!.first.codeSnippet, contains('AppLocalizations.of'));
  });

  test('captures enclosingWidgetCode for matched usages', () async {
    final packageRoot = _cliPackageRoot();
    final scanner = UsageScanner(
      rootDir: '$packageRoot/test/fixtures/sample_app',
      typePatterns: const ['AppLocalizations'],
    );
    final usagesByKey = await scanner.scan(
      keys: const {'appTitle'},
    );
    final usage = usagesByKey['appTitle']!.first;
    expect(usage.enclosingWidgetCode, isNotNull);
    expect(usage.enclosingWidgetCode, contains('class LoginPage'));
  });

  test('scanner assigns Role based on AST context', () async {
    final packageRoot = _cliPackageRoot();
    final scanner = UsageScanner(
      rootDir: '$packageRoot/test/fixtures/sample_app',
      typePatterns: const ['AppLocalizations', 'context.l10n', 'strings'],
    );
    final usages = await scanner.scan(
      keys: const {'appTitle', 'email', 'loginButton', 'logoutConfirm'},
    );
    final appTitleRoles = usages['appTitle']!.map((u) => u.role).toSet();
    expect(appTitleRoles, containsAll({Role.text, Role.header}));
    expect(usages['email']!.first.role, anyOf(Role.fieldLabel, Role.fieldHint));
    expect(usages['loginButton']!.first.role, Role.button);
  });
}
