// packages/locale_helper_shared/test/string_entry_test.dart
import 'package:locale_helper_shared/locale_helper_shared.dart';
import 'package:test/test.dart';

void main() {
  test('StringEntry round-trips with role + new optional fields', () {
    final entry = StringEntry(
      key: 'welcome',
      sourceLocale: 'en',
      values: const {'en': 'Welcome'},
      arbMetadata: {'description': 'Login greeting'},
      usages: [
        Usage(filePath: 'lib/a.dart', lineStart: 1, lineEnd: 2, codeSnippet: 'x'),
      ],
      aiDescription: 'Greeting on login page.',
      role: Role.header,
      myReviewState: const ReviewStateDto(reviewed: true, changedSinceReview: false),
      commentCount: 3,
    );
    final decoded = StringEntry.fromJson(entry.toJson(), sourceLocale: 'en');
    expect(decoded.role, Role.header);
    expect(decoded.myReviewState?.reviewed, isTrue);
    expect(decoded.commentCount, 3);
  });

  test('StringEntry tolerates omitted optional fields', () {
    final entry = StringEntry.fromJson(
      {
        'key': 'x',
        'values': {'en': 'X'},
        'usages': <Map<String, dynamic>>[],
      },
      sourceLocale: 'en',
    );
    expect(entry.role, Role.other);
    expect(entry.myReviewState, isNull);
    expect(entry.commentCount, isNull);
  });

  test('copyWith preserves and updates role + myReviewState', () {
    final entry = StringEntry(
      key: 'k',
      sourceLocale: 'en',
      values: const {'en': 'v'},
    );
    final updated = entry.copyWith(
      role: Role.button,
      myReviewState: const ReviewStateDto(reviewed: false, changedSinceReview: true),
      commentCount: 1,
    );
    expect(updated.role, Role.button);
    expect(updated.myReviewState?.changedSinceReview, isTrue);
    expect(updated.commentCount, 1);
    // original unchanged
    expect(entry.role, Role.other);
  });

  test('StringEntry has icuKind + placeholders fields with sensible defaults',
      () {
    final e = StringEntry(
      key: 'greeting',
      sourceLocale: 'en',
      values: const {'en': 'Hello'},
    );
    expect(e.icuKind, IcuKind.plain);
    expect(e.placeholders, isEmpty);
  });

  test('StringEntry round-trips icuKind + placeholders via JSON', () {
    final e = StringEntry(
      key: 'itemCount',
      sourceLocale: 'en',
      values: const {'en': '{count, plural, one {item} other {items}}'},
      icuKind: IcuKind.plural,
      placeholders: const {
        'count': PlaceholderMeta(name: 'count', type: 'int'),
      },
    );
    final decoded =
        StringEntry.fromJson(e.toJson(), sourceLocale: 'en');
    expect(decoded.icuKind, IcuKind.plural);
    expect(decoded.placeholders.keys, ['count']);
    expect(decoded.placeholders['count']!.type, 'int');
  });
}
