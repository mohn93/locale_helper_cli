// packages/locale_helper_shared/test/usage_test.dart
import 'package:locale_helper_shared/locale_helper_shared.dart';
import 'package:test/test.dart';

void main() {
  test('Usage round-trips through JSON', () {
    final original = Usage(
      filePath: 'lib/widgets/login.dart',
      lineStart: 42,
      lineEnd: 47,
      codeSnippet: 'Text(AppLocalizations.of(context).welcome)',
      surroundingWidget: 'LoginPage',
    );
    final decoded = Usage.fromJson(original.toJson());
    expect(decoded.filePath, original.filePath);
    expect(decoded.lineStart, original.lineStart);
    expect(decoded.lineEnd, original.lineEnd);
    expect(decoded.codeSnippet, original.codeSnippet);
    expect(decoded.surroundingWidget, original.surroundingWidget);
  });

  test('Usage tolerates missing surroundingWidget', () {
    final json = {
      'filePath': 'lib/a.dart',
      'lineStart': 1,
      'lineEnd': 2,
      'codeSnippet': 'x',
    };
    final usage = Usage.fromJson(json);
    expect(usage.surroundingWidget, isNull);
  });

  test('Usage round-trips enclosingWidgetCode', () {
    final original = Usage(
      filePath: 'lib/widgets/login.dart',
      lineStart: 1,
      lineEnd: 5,
      codeSnippet: 'Text(AppLocalizations.of(context).appTitle)',
      surroundingWidget: 'LoginPage',
      enclosingWidgetCode: 'class LoginPage extends StatelessWidget { ... }',
    );
    final decoded = Usage.fromJson(original.toJson());
    expect(decoded.enclosingWidgetCode, original.enclosingWidgetCode);
  });

  test('Usage tolerates missing enclosingWidgetCode', () {
    final json = {
      'filePath': 'lib/a.dart',
      'lineStart': 1,
      'lineEnd': 2,
      'codeSnippet': 'x',
    };
    final usage = Usage.fromJson(json);
    expect(usage.enclosingWidgetCode, isNull);
  });

  test('Usage role round-trips through JSON', () {
    final original = Usage(
      filePath: 'lib/widgets/login.dart',
      lineStart: 1,
      lineEnd: 3,
      codeSnippet: 'ElevatedButton(...)',
      role: Role.button,
    );
    final json = original.toJson();
    expect(json['role'], 'button');
    final decoded = Usage.fromJson(json);
    expect(decoded.role, Role.button);
  });

  test('Usage omits role from JSON when Role.other', () {
    final usage = Usage(
      filePath: 'lib/a.dart',
      lineStart: 1,
      lineEnd: 1,
      codeSnippet: 'x',
    );
    expect(usage.role, Role.other);
    expect(usage.toJson().containsKey('role'), isFalse);
  });

  test('Usage defaults role to Role.other when missing from JSON', () {
    final json = {
      'filePath': 'lib/a.dart',
      'lineStart': 1,
      'lineEnd': 2,
      'codeSnippet': 'x',
    };
    final usage = Usage.fromJson(json);
    expect(usage.role, Role.other);
  });
}
