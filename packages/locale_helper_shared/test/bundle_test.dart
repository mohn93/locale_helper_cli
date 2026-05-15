// packages/locale_helper_shared/test/bundle_test.dart
import 'package:locale_helper_shared/locale_helper_shared.dart';
import 'package:test/test.dart';

void main() {
  test('Bundle round-trips through JSON', () {
    final bundle = Bundle(
      projectId: 'p1',
      sourceLocale: 'en',
      locales: const ['en'],
      strings: [
        StringEntry(
          key: 'hello',
          sourceLocale: 'en',
          values: const {'en': 'Hello'},
        ),
      ],
      createdAt: DateTime.utc(2026, 5, 12, 9, 0, 0),
    );
    final decoded = Bundle.fromJson(bundle.toJson());
    expect(decoded.projectId, 'p1');
    expect(decoded.sourceLocale, 'en');
    expect(decoded.strings.first.key, 'hello');
    expect(decoded.createdAt, bundle.createdAt);
  });
}
